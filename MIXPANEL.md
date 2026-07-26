# Mixpanel analytics

## Build configuration

The production project token is configured as the app default. To send a
development or staging build to another Mixpanel project, override it at build
time with the token from **Mixpanel → Project settings → Access keys**:

```powershell
C:\flutter\bin\flutter.bat run --dart-define=MIXPANEL_TOKEN=OTHER_PROJECT_TOKEN
```

Add the same override to Android, iOS, and Shorebird release commands when a
non-production project is required. The project URL/project ID is not the
ingestion token.

## Event dictionary

| Event | Important properties | Purpose |
| --- | --- | --- |
| `App Opened` | `logged_in` | Active use and guest/member mix |
| `<Screen Name> Screen Viewed` | `screen_name` | Navigation and feature adoption |
| `Login OTP Requested` | `validation_method` | Authentication funnel entry |
| `Login Completed` | `validation_method` | Authentication conversion |
| `Registration Submitted` | `validation_method`, `city_provided` | Registration funnel |
| `Gallery Persona Selected` | `persona` | Content preference |
| `Photo Favorited` / `Photo Unfavorited` | `photo_id`, `persona` | Content engagement |
| `Photo Tagged` | `photo_id` | Organization-feature adoption |
| `Diary Entry Created` / `Diary Entry Updated` | counts, location/image flags, `note_length` | Diary activation and depth |
| `Diary Entry Deleted` | — | Diary churn |
| `Selfie Submitted` | `request_created` | My Smruti onboarding |

Every event also receives `app_name`, `app_version`, `build_number`, and
`environment`. Authentication events deliberately exclude phone numbers,
email addresses, names, OTPs, diary text, tags, and precise location.

## Recommended boards and reports

Create one board named **HariSmruti Product Health** with:

1. **Weekly active users** — Insights, unique users of `App Opened`, weekly.
2. **New-user activation funnel** — `Registration Submitted` → `Login OTP
   Requested` → `Login Completed` → `Photo Favorited` or `Diary Entry Created`;
   conversion window 7 days.
3. **Login conversion** — `Login OTP Requested` → `Login Completed`, broken
   down by `validation_method`, conversion window 30 minutes.
4. **Feature adoption** — Insights, unique users, stacked by event:
   `Photo Favorited`, `Photo Tagged`, `Diary Entry Created`, `Selfie Submitted`.
5. **Diary engagement** — total `Diary Entry Created` and `Diary Entry Updated`,
   with separate breakdowns for `has_location` and `image_count`.
6. **Content preference** — `Gallery Persona Selected`, broken down by
   `persona`.
7. **Retention** — first `Login Completed`, returning on `App Opened`, weekly
   retention for 8 weeks.
8. **Version health** — `App Opened` unique users broken down by `app_version`
   and filtered to `environment = production`.

Wait until real events arrive before interpreting funnels or retention. Use
Lexicon descriptions to document each event and hide any accidental test
events from production boards.
