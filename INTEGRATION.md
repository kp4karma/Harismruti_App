# Harismruti Mobile ↔ PictoGallery Backend — Integration Plan

> **Decision (confirmed)**: extend the existing FastAPI backend at `/Users/apple/Projects/PictoGallery/backend` with a new mobile-only router at `/api/mobile/v1/*`. Reuses the existing face-detection / embedding / matching pipeline; does not duplicate data.
>
> **Auth (open)**: the mobile app will authenticate against a **third-party identity provider** (details to come). This document treats auth as a *token-exchange*: the mobile app obtains an identity token from the third party, the backend verifies it and mints our own short-lived JWT. The verification step is pluggable — it changes only when the provider is decided.

---

## 1. Why we’re extending, not duplicating

| Concern | Existing backend | Action |
|---|---|---|
| Photos, EXIF, thumbnails | `Photo`, `/api/photos/*` | **Reuse** |
| Face detection + 512-dim embeddings (InsightFace) | `Face`, `face_detector.py`, `face_embedding_dim` | **Reuse** |
| Person groups + clustering (HDBSCAN) | `PersonGroup`, `/api/groups/*` | **Reuse** |
| Per-user match storage | `ExternalUser`, `ExternalUserProfilePic`, `ExternalMatchRequest`, `ExternalUserFaceMatch`, `ExternalUserFaceRejection` | **Reuse** — every mobile user maps to one `ExternalUser` row |
| Web admin auth (`/api/auth/login`) | username + password + HttpOnly cookie | **Leave alone** — not used by mobile |
| Mobile auth, registration, OTP, push tokens, favorites, location, albums | none | **Add** |

Net new code is small: a thin auth adapter, a few section endpoints, three small tables, optional EXIF-GPS column.

---

## 2. Top-level architecture

```
┌──────────────────────┐     ┌─────────────────────────────────────────┐
│  Harismruti (Flutter)│     │ Third-party Identity Provider           │
│  - splash/login/OTP  │ ──► │  (TBD — details from user)              │
│  - home/sections     │ ◄── │   issues identity_token to mobile       │
│  - profile           │     └─────────────────────────────────────────┘
│                      │              │
│                      │  identity_token (one-shot)
│                      ▼              │
│   POST /api/mobile/v1/auth/exchange │ verify identity_token (server→server)
│   ◄── access_token + refresh_token  │
│                                     ▼
│  Authorization: Bearer ‹access_token›
│        │
└────────┼──────────────────────────────────────────────────────────────┐
         ▼                                                               │
┌─────────────────────────────────────────────────────────────────────┐ │
│ FastAPI: /api/mobile/v1/*  (NEW router; same app)                   │ │
│ ├─ auth        — token exchange, refresh, logout, /me               │ │
│ ├─ profile     — GET/PATCH profile, POST selfie (multipart)         │ │
│ ├─ smruti      — /recent /of /with /location /album /collection     │ │
│ │                /people /wallpaper                                 │ │
│ ├─ interactions — favorite, hide-face (reject), share-link          │ │
│ └─ push        — register/unregister FCM token                      │ │
└──────────────────────────────────┬──────────────────────────────────┘ │
                                   ▼                                    │
       Reuses existing services/models/Postgres+pgvector ◄──────────────┘
```

**Important**: web admin endpoints (`/api/folders`, `/api/photos`, `/api/groups`, …) are **not exposed to mobile**. The mobile JWT carries `aud=mobile` and is rejected by the existing `get_current_user` dependency, which checks `aud=web` (or no `aud`, for backwards compat).

---

## 3. Data model — additions only

Three new tables + one optional column. Migration via Alembic.

```sql
-- 3.1 — link a mobile user to an ExternalUser row.
-- One-to-one. mobile_user_id is what the third-party identity provider returns.
CREATE TABLE mobile_users (
    id                       SERIAL PRIMARY KEY,
    external_user_id         INT NOT NULL UNIQUE
                              REFERENCES external_users(id) ON DELETE CASCADE,
    provider                 TEXT NOT NULL,          -- 'thirdparty-x' (TBD)
    provider_subject         TEXT NOT NULL,          -- the 'sub' from id-token
    last_login_at            TIMESTAMPTZ,
    created_at               TIMESTAMPTZ DEFAULT now(),
    UNIQUE (provider, provider_subject)
);

-- 3.2 — favorites
CREATE TABLE mobile_favorite_photos (
    id                       SERIAL PRIMARY KEY,
    mobile_user_id           INT NOT NULL REFERENCES mobile_users(id) ON DELETE CASCADE,
    photo_id                 INT NOT NULL REFERENCES photos(id) ON DELETE CASCADE,
    created_at               TIMESTAMPTZ DEFAULT now(),
    UNIQUE (mobile_user_id, photo_id)
);

-- 3.3 — push tokens
CREATE TABLE mobile_push_tokens (
    id                       SERIAL PRIMARY KEY,
    mobile_user_id           INT NOT NULL REFERENCES mobile_users(id) ON DELETE CASCADE,
    fcm_token                TEXT NOT NULL,
    platform                 TEXT NOT NULL CHECK (platform IN ('ios','android')),
    app_version              TEXT,
    last_seen_at             TIMESTAMPTZ DEFAULT now(),
    UNIQUE (fcm_token)
);

-- 3.4 — optional, for the Location section (EXIF GPS).
-- Only add if Location is in scope. Backfill once via a one-off script.
ALTER TABLE photos
    ADD COLUMN gps_lat DOUBLE PRECISION,
    ADD COLUMN gps_lng DOUBLE PRECISION,
    ADD COLUMN place_name TEXT;          -- reverse-geocoded, optional
CREATE INDEX idx_photos_gps ON photos (gps_lat, gps_lng) WHERE gps_lat IS NOT NULL;
```

Section toggle / order is **already** stored client-side in `GetStorage` under `smrutiSectionConfig`. No backend change needed unless we want to sync across devices later.

---

## 4. Auth — token exchange flow

The provider is TBD; this design makes the verification step the only place that changes.

### 4.1 Sequence

```
Mobile                     Third-party IdP                Backend
  │                              │                          │
  │  user signs in (OTP / SDK)   │                          │
  ├─────────────────────────────►│                          │
  │  identity_token              │                          │
  │◄─────────────────────────────┤                          │
  │                                                         │
  │  POST /api/mobile/v1/auth/exchange                      │
  │   { identity_token, device_info }                       │
  ├────────────────────────────────────────────────────────►│
  │                                                         │ verify_identity_token()
  │                                                         │   — calls provider
  │                                                         │   — returns subject, mobile_no, name
  │                                                         │ upsert ExternalUser + mobile_users
  │                                                         │ mint JWT (access + refresh)
  │  { access_token, refresh_token, expires_in, user }      │
  │◄────────────────────────────────────────────────────────┤
  │                                                         │
  │  Authorization: Bearer ‹access_token›   for every call  │
```

### 4.2 Token specifics

- **Access token**: JWT, `aud=mobile`, 15 min TTL, signed with a *separate* HS256 key (`MOBILE_JWT_SECRET`) so admin tokens and mobile tokens can never be confused.
- **Refresh token**: opaque random 32 bytes, stored hashed (`sha256`) in a new `mobile_refresh_tokens` table with `revoked_at` and `last_used_at`. 30-day sliding window. Rotated on every use.
- Mobile-side storage:
  - access token in memory, mirrored into `StorageHelper(StorageKeys.accessToken)` (already wired in `lib/utils/storage_helper.dart`)
  - refresh token in `StorageKeys.refreshToken`
- The existing `ApiClient` interceptor already handles 403→refresh and 440→force-logout — we reuse it without modification.

### 4.3 Adapter interface (provider-pluggable)

```python
# app/services/mobile_auth.py
class MobileIdentity(BaseModel):
    provider: str
    subject: str          # provider 'sub' — stable across logins
    mobile_no: str | None
    name: str | None
    email: str | None
    raw: dict             # original claims, for audit

class IdentityVerifier(Protocol):
    async def verify(self, identity_token: str) -> MobileIdentity: ...

# Plug the actual provider class once details land:
# class TwilioVerifier(IdentityVerifier): ...
# class FirebasePhoneAuthVerifier(IdentityVerifier): ...
# class CustomThirdPartyVerifier(IdentityVerifier): ...
```

The router only knows about `IdentityVerifier`. Swapping providers is a one-class change.

---

## 5. API surface — `/api/mobile/v1/*`

All endpoints (except `/auth/exchange` and `/health`) require `Authorization: Bearer ‹access_token›` with `aud=mobile`.

### 5.1 Auth

| Method | Path | Body | Response | Notes |
|---|---|---|---|---|
| POST | `/auth/exchange` | `{ identity_token: string, device: { platform, app_version, fcm_token? } }` | `{ access_token, refresh_token, expires_in, user: { id, name, mobile_no, profile_pic_url? } }` | Verifies via `IdentityVerifier`, upserts `ExternalUser` + `mobile_users`, registers `fcm_token` if present. |
| POST | `/auth/refresh` | `{ refresh_token }` | `{ access_token, refresh_token, expires_in }` | Rotates refresh token; revokes the old one. |
| POST | `/auth/logout` | — | `{ ok: true }` | Revokes current refresh token; optional `device_id` to scope. |
| GET | `/auth/me` | — | `{ id, name, mobile_no, profile_pic_url, has_seed_selfie, sections_pending }` | Used by splash to decide where to navigate. |

### 5.2 Profile + selfie seed

| Method | Path | Body | Response | Notes |
|---|---|---|---|---|
| GET | `/profile` | — | `{ id, name, mobile_no, email, profile_pic_url, created_at }` | |
| PATCH | `/profile` | `{ name?, email? }` | profile | mobile_no is immutable post-registration. |
| POST | `/profile/selfie` | multipart `file` (jpg/png ≤ 5 MB) | `{ profile_pic_id, face_detected, request_id, status }` | Saves to disk, runs face detection (reuses `face_detector.detect_faces`), stores embedding into `external_user_profile_pics`, kicks `external_match_jobs.notify_new_request`. Returns the `request_id` so the client can poll progress. |
| GET | `/profile/match-status` | — | `{ status, percent, result_count }` | Wraps the most recent `ExternalMatchRequest` for this user — same shape as `external.get_match_request` already returns. |
| DELETE | `/profile/selfie/{pic_id}` | — | `204` | User can delete a bad selfie; matches discovered through it stay (they’re already in `external_user_face_matches`). |

> The `external` router’s `_download_profile_pic` path is bypassed (mobile uploads multipart). Everything downstream (`_detect_face_embedding`, request persistence, worker pool) is reused.

### 5.3 Smruti sections — listing + pagination

All listing endpoints share the same envelope:
```json
{ "page": 1, "per_page": 20, "total": 137, "has_more": true, "items": [ ... ] }
```
…and the same item shape:
```json
{
  "photo_id": 123,
  "thumbnail_url": "/api/photos/123/thumbnail",
  "full_url": "/api/photos/123/full",
  "taken_at": "2025-07-13T17:42:00Z",
  "place_name": "Surat",
  "is_favorite": false,
  "highlight_face_id": 891,             // the user's face inside this photo
  "co_present_groups": [12,18]          // person_group ids of others in the photo
}
```

| Method | Path | Reuses | Notes |
|---|---|---|---|
| GET | `/smruti/recent?page=&per_page=` | `ExternalUserFaceMatch` ⨝ `Face` ⨝ `Photo` ordered by `Photo.taken_at DESC` | Default home feed. |
| GET | `/smruti/of?page=&per_page=` | same as above | Same data set, but ordered by similarity DESC — the “best matches”. |
| GET | `/smruti/with?page=&per_page=&group_id=` | self-join on `Face` by `photo_id` to find people-co-occurrence | Without `group_id`: returns *people* (groups) the user appears with most often. With `group_id`: returns *photos* that contain both the user and that group. |
| GET | `/smruti/people?page=&per_page=` | `PersonGroup` joined to user’s matched photos | Lists groups that share at least one photo with the user, ranked by shared-photo count. |
| GET | `/smruti/album?page=&per_page=&folder_id=` | `Folder` (existing). Without `folder_id`: list albums the user appears in. With: photos in that album where the user appears. | Existing folders **are** the albums. |
| GET | `/smruti/location?page=&per_page=&place=` | `Photo.gps_lat / gps_lng / place_name` (new) | Requires the migration in §3.4 + EXIF backfill. Stub returns 501 until landed. |
| GET | `/smruti/collection?page=&per_page=&collection_id=` | `PersonGroup` repurposed as “collection” (groups can have a name + cover) | If you want a separate model later, swap the source — the API contract stays the same. |
| GET | `/smruti/wallpaper?page=&per_page=` | `PhotoPersonTag` with a sentinel tag, or a new `Photo.is_wallpaper` boolean | Pick one based on UX; both are tiny. |
| GET | `/smruti/photos/{photo_id}` | full `Photo` + faces + co-occurrence + favorite flag | Detail view. |

### 5.4 Interactions

| Method | Path | Body | Notes |
|---|---|---|---|
| POST | `/interactions/photo/{id}/favorite` | — | Insert into `mobile_favorite_photos` (idempotent). |
| DELETE | `/interactions/photo/{id}/favorite` | — | Remove. |
| GET | `/interactions/favorites?page=&per_page=` | — | Lists favorited photos. |
| POST | `/interactions/face/{face_id}/reject` | — | Wraps existing `external.reject_face` — “this isn’t me”. |
| POST | `/interactions/face/{face_id}/restore` | — | Wraps `external.restore_face`. |
| POST | `/interactions/photo/{id}/share` | `{ ttl_minutes?: 60 }` | Returns a signed short-lived URL backed by `/api/photos/{id}/full`. |

### 5.5 Push tokens

| Method | Path | Body | Notes |
|---|---|---|---|
| POST | `/push/token` | `{ fcm_token, platform, app_version }` | Upsert into `mobile_push_tokens`. Called on each app cold-start (the existing `NotificationService.setupFlutterNotifications` already prints the token). |
| DELETE | `/push/token` | `{ fcm_token }` | Logout / token-rotated. |

### 5.6 Health / version

| Method | Path | Notes |
|---|---|---|
| GET | `/health` | Mirrors `/api/health` but unauthenticated for mobile uptime checks. |
| GET | `/version` | `{ minimum_app_version, latest_app_version, force_update }` — the existing `ApiClient` already sends `X-App-Version: <build>-Android|iOS`, hook a soft-update gate here. |

---

## 6. Mapping to the existing UI screens

| Flutter file | Calls (after wiring) | Source |
|---|---|---|
| `splash_screen.dart` | `GET /auth/me` if token exists, else go to `login_home` | new |
| `login_home.dart` → `login.dart` → `otp_screen.dart` | third-party SDK → `POST /auth/exchange` → store tokens via `StorageHelper` → `GET /auth/me` → `HomeScreen` | new |
| `register.dart` | depends on whether the third party owns registration; if it does, this screen disappears or becomes a one-time profile-completion form (`PATCH /profile`) | TBD when provider lands |
| `home_screen.dart` (orchestrator) | parallel calls to whichever section endpoints `SmrutiSectionController.sections` has `is_show=true` | per section |
| `recent_smruti.dart` | `GET /smruti/recent?per_page=20` | existing |
| `smruti_of.dart` | `GET /smruti/of?per_page=20` | existing |
| `smruti_with.dart` | `GET /smruti/with?per_page=20` (people-only) | new query |
| `people_smruti.dart` | `GET /smruti/people?per_page=50` | existing |
| `album_smruti.dart` | `GET /smruti/album` | existing |
| `collection_smruti.dart` | `GET /smruti/collection` | existing-ish |
| `location_smruti.dart` | `GET /smruti/location` (501 until EXIF GPS landed) | new |
| `wallpaper_smruti.dart` | `GET /smruti/wallpaper` | existing-ish |
| `profile_screen.dart` | `GET /profile`, `POST /profile/selfie` (replaces local-only `ProfileController.pickAndCropImage`) | new |
| `smruti_section_setting.dart` | already client-only via GetStorage; no backend call | — |
| `notification_service.dart` | `POST /push/token` after `getToken()` | new |

---

## 7. Migrations & rollout

1. **Add Alembic migration** with the three tables in §3 (and optionally the EXIF GPS column).
2. **Add `app/api/routes/mobile/`** with stubs that return `501` for everything except `/health`.
3. **Implement `/auth/exchange` against a stub verifier** that accepts `identity_token = "DEV:<phone>:<name>"` so the mobile team can wire the full flow before the real provider is integrated.
4. **Implement `/profile/selfie` + `/auth/me` + `/smruti/recent`** — minimum viable end-to-end loop.
5. **Wire `lib/api/api_endpoints.dart`** with real domains, add the per-endpoint getters, and delete the hardcoded `imageUrls` from `app_string.dart`.
6. **Re-enable `bootstrap()`** in `main.dart` and switch `home: HomeScreen()` → `initialRoute: AppRoutes.splash`.
7. **Layer in the remaining section endpoints** in priority order. The Flutter side already hides any section toggled off, so this is a graceful drip.
8. **Plug in the real third-party verifier** when its API contract lands — only `mobile_auth.py` changes.

---

## 8. Things still open — please confirm

1. **Auth provider** — who is the third party? What does their `identity_token` look like (JWT / opaque / SDK callback)? What field maps to `mobile_no`?
2. **Smruti sections — launch scope.** The previous question wasn’t answered; please pick which of these are MVP vs later:
   - Recent ✓ (effectively free)
   - Smruti Of ✓ (effectively free)
   - People ✓ (cheap)
   - Smruti With (1 day backend)
   - Album / Collection / Wallpaper (1–2 days; depends on whether Wallpaper needs new tagging)
   - Location (≥2 days; needs EXIF backfill)
3. **Favorites & share-links** — are these in scope for v1, or can they wait?
4. **Backend hosting / domain** — what URL do we point `ApiEndpoints._testDomain` and `_liveDomain` at? Same `org.hp.harismruti` domain or a sub-path?
5. **Photo ownership boundary** — the existing backend has a single global photo library indexed by an admin; every mobile user *only* sees photos they were detected in (via `ExternalUserFaceMatch`). Confirm that’s the intended model (no per-user upload).
6. **Existing `User` (web admin) reuse?** Not needed for mobile, but good to confirm we shouldn’t hijack it.

---

## 9. Summary

- One backend, one router (`/api/mobile/v1/*`), one auth audience.
- Three small tables + one optional column.
- Eight section endpoints, six of them are thin SQL queries against models that already exist.
- Auth abstracted behind `IdentityVerifier`, ready to plug the third party in once its contract is shared.
- The mobile app’s `ApiClient` + `StorageHelper` + `NavigationHelper` already match this design — most of the integration on the Flutter side is filling in `ApiEndpoints` getters and replacing static `imageUrls` with API responses.
