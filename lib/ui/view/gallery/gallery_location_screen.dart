import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';
import 'package:latlong2/latlong.dart' hide Path;

List<GalleryCard> _filterCities(List<GalleryCard> cities, String query) {
  if (query.isEmpty) return cities;
  return cities.where((card) => _cityMatchesQuery(card, query)).toList();
}

bool _cityMatchesQuery(GalleryCard card, String query) {
  final searchableText = [
    card.title,
    card.subtitle,
    card.value,
    card.type,
    for (final photo in card.photos) ...[
      photo.title ?? '',
      photo.subtitle ?? '',
      photo.subLocation ?? '',
      photo.location ?? '',
      photo.country ?? '',
    ],
  ].join(' ').toLowerCase();
  return searchableText.contains(query);
}

String _locationCountryLabel(GalleryCard card) {
  final location = card.title.trim();
  final countries = <String>[];
  final normalizedCountries = <String>{};

  for (final photo in card.photos) {
    final country = photo.country?.trim() ?? '';
    final normalized = country.toLowerCase();
    if (country.isNotEmpty && normalizedCountries.add(normalized)) {
      countries.add(country);
    }
  }

  if (countries.isEmpty) return location;
  if (countries.any(
    (country) => country.toLowerCase() == location.toLowerCase(),
  )) {
    return location;
  }
  return '$location, ${countries.join(', ')}';
}

class GalleryLocationScreen extends StatefulWidget {
  final GalleryCard card;

  const GalleryLocationScreen({super.key, required this.card});

  @override
  State<GalleryLocationScreen> createState() => _GalleryLocationScreenState();
}

class _GalleryLocationScreenState extends State<GalleryLocationScreen> {
  static final LatLng _fallbackCenter = LatLng(20.5937, 78.9629);
  static const double _minMapZoom = 4.5;
  static const double _maxMapZoom = 17;
  static const double _maxFitZoom = 15;
  static const double _cityChipWidth = 132;
  static const double _selectedCityChipWidth = 156;
  static const double _cityChipGap = 10;

  late Future<List<GalleryPhoto>> _photosFuture;
  late GalleryCard _activeCard;
  final GalleryController _controller = Get.find<GalleryController>();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _cityScrollController = ScrollController();
  double _mapZoom = 11;
  String? _lastFitKey;

  @override
  void initState() {
    super.initState();
    _activeCard = widget.card;
    _photosFuture = _controller.loadPhotosForCard(_activeCard);
    _controller.loadAllPlaces().then((_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _centerSelectedCity(_activeCard),
    );
  }

  @override
  void didUpdateWidget(covariant GalleryLocationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id ||
        oldWidget.card.value != widget.card.value) {
      _activeCard = widget.card;
      _photosFuture = _controller.loadPhotosForCard(_activeCard);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cityScrollController.dispose();
    super.dispose();
  }

  void _handleMapZoomChanged(double zoom) {
    final currentScale = _markerScaleForZoom(_mapZoom);
    final nextScale = _markerScaleForZoom(zoom);
    if (currentScale == nextScale) {
      _mapZoom = zoom;
      return;
    }
    setState(() => _mapZoom = zoom);
  }

  static double _markerScaleForZoom(double zoom) {
    if (zoom <= 5.5) return 0.52;
    if (zoom <= 7) return 0.6;
    if (zoom <= 8.5) return 0.68;
    if (zoom <= 10.5) return 0.8;
    if (zoom <= 12.5) return 0.9;
    return 1;
  }

  void _selectCity(GalleryCard card) {
    if (card.id == _activeCard.id && card.value == _activeCard.value) {
      _centerSelectedCity(card);
      return;
    }

    setState(() {
      _activeCard = card;
      _photosFuture = _controller.loadPhotosForCard(card);
      _lastFitKey = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerSelectedCity(card);
      final point = _LocationGroupMarker.pointForCard(card);
      if (point != null) {
        _mapController.move(point, 10.5);
      }
    });
  }

  void _openCityDetail(GalleryCard card) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        settings: const RouteSettings(name: 'Gallery Detail'),
        builder: (_) => GalleryDetailScreen.fromCard(card),
      ),
    );
  }

  void _centerSelectedCity(GalleryCard card) {
    final cities = _allCities;
    final index = cities.indexWhere(
      (city) => city.id == card.id && city.value == card.value,
    );
    if (index == -1 || !_cityScrollController.hasClients) return;

    final scale = tabletScale(context);
    final viewport = _cityScrollController.position.viewportDimension;
    final target =
        index * (_cityChipWidth * scale + _cityChipGap) -
        (viewport - _selectedCityChipWidth * scale) / 2;
    _cityScrollController.animateTo(
      target.clamp(0.0, _cityScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _fitCityMarkers(
    List<_PhotoCluster> clusters,
    List<_LocationGroupMarker> locationMarkers,
  ) {
    final validClusters = clusters
        .where(
          (cluster) =>
              cluster.point.latitude.isFinite &&
              cluster.point.longitude.isFinite,
        )
        .toList();
    if (validClusters.isEmpty && locationMarkers.isNotEmpty) {
      final activePoint = _LocationGroupMarker.pointForCard(_activeCard);
      if (activePoint != null) {
        _mapController.move(activePoint, 10.5);
        return;
      }
      if (locationMarkers.length == 1) {
        _mapController.move(locationMarkers.first.point, 10.5);
        return;
      }
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(
            locationMarkers.map((marker) => marker.point).toList(),
          ),
          padding: const EdgeInsets.fromLTRB(48, 110, 48, 230),
          minZoom: _minMapZoom,
          maxZoom: _maxFitZoom,
        ),
      );
      return;
    }
    if (validClusters.isEmpty) {
      _mapController.move(_fallbackCenter, _minMapZoom);
      return;
    }
    if (validClusters.length == 1) {
      _mapController.move(validClusters.first.point, 13);
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(
          validClusters.map((cluster) => cluster.point).toList(),
        ),
        padding: const EdgeInsets.fromLTRB(48, 110, 48, 230),
        minZoom: _minMapZoom,
        maxZoom: _maxFitZoom,
      ),
    );
  }

  List<GalleryCard> get _allCities =>
      _controller.placeCards.toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // Keyboard insets are handled inside _LocationSheet instead, so the
      // map behind it doesn't relayout/resize every time the keyboard
      // opens or closes.
      resizeToAvoidBottomInset: false,
      body: FutureBuilder<List<GalleryPhoto>>(
        future: _photosFuture,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;
          final photos = snapshot.data ?? _activeCard.photos;
          final total = _activeCard.count ?? photos.length;
          final clusters = _PhotoCluster.fromPhotos(photos);
          final locationMarkers = _LocationGroupMarker.fromCards(
            _controller.placeCards,
          );
          final candidateCenter = clusters.isEmpty
              ? (_LocationGroupMarker.pointForCard(_activeCard) ??
                    (locationMarkers.isEmpty
                        ? _fallbackCenter
                        : locationMarkers.first.point))
              : clusters.first.point;
          final center =
              _PhotoCluster._isValidCoordinate(
                candidateCenter.latitude,
                candidateCenter.longitude,
              )
              ? candidateCenter
              : _fallbackCenter;
          final cities = _allCities;

          final fitKey = clusters
              .map(
                (cluster) =>
                    '${cluster.point.latitude},${cluster.point.longitude}',
              )
              .join('|');
          if (snapshot.connectionState == ConnectionState.done &&
              fitKey != _lastFitKey) {
            _lastFitKey = fitKey;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) =>
                  mounted ? _fitCityMarkers(clusters, locationMarkers) : null,
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: _PhotoCoordinateMap(
                  mapController: _mapController,
                  center: center,
                  clusters: clusters,
                  locationMarkers: locationMarkers,
                  activeCard: _activeCard,
                  photos: photos,
                  locationLabel: _activeCard.title,
                  headers: _controller.imageHeaders,
                  loading: loading,
                  hasCityCoordinate:
                      _LocationGroupMarker.pointForCard(_activeCard) != null,
                  markerScale:
                      _markerScaleForZoom(_mapZoom) * tabletScale(context),
                  onZoomChanged: _handleMapZoomChanged,
                  onLocationTap: _openCityDetail,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _LocationTopPanel(
                  title: _activeCard.title,
                  count: total,
                  mappedCount: clusters.fold<int>(
                    0,
                    (sum, cluster) => sum + cluster.photos.length,
                  ),
                  controller: _searchController,
                  cities: cities,
                  activeCard: _activeCard,
                  cityScrollController: _cityScrollController,
                  onBack: () => Navigator.pop(context),
                  onCityTap: _selectCity,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: _LocationSheet(
                  controller: _searchController,
                  cities: cities,
                  activeCard: _activeCard,
                  cityScrollController: _cityScrollController,
                  onCityTap: _selectCity,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PhotoCoordinateMap extends StatelessWidget {
  final MapController mapController;
  final LatLng center;
  final List<_PhotoCluster> clusters;
  final List<_LocationGroupMarker> locationMarkers;
  final GalleryCard activeCard;
  final List<GalleryPhoto> photos;
  final String locationLabel;
  final Map<String, String>? headers;
  final bool loading;
  final bool hasCityCoordinate;
  final double markerScale;
  final ValueChanged<double> onZoomChanged;
  final ValueChanged<GalleryCard> onLocationTap;

  const _PhotoCoordinateMap({
    required this.mapController,
    required this.center,
    required this.clusters,
    required this.locationMarkers,
    required this.activeCard,
    required this.photos,
    required this.locationLabel,
    required this.headers,
    required this.loading,
    required this.hasCityCoordinate,
    required this.markerScale,
    required this.onZoomChanged,
    required this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedLocationMarkers = _resolveSelectedMarker(
      locationMarkers,
      activeCard,
      loading ? const [] : clusters,
    );
    final visibleLocationMarkers = _collapseCoincidentMarkers(
      resolvedLocationMarkers,
      activeCard,
    );
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _MapFallbackPainter()),
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: clusters.length <= 1 ? 13 : 11,
              minZoom: _GalleryLocationScreenState._minMapZoom,
              maxZoom: _GalleryLocationScreenState._maxMapZoom,
              onPositionChanged: (camera, _) => onZoomChanged(camera.zoom),
              interactionOptions: const InteractionOptions(
                flags:
                    InteractiveFlag.drag |
                    InteractiveFlag.flingAnimation |
                    InteractiveFlag.pinchMove |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                fallbackUrl: 'https://a.tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.harismruti.app',
                minZoom: _GalleryLocationScreenState._minMapZoom,
                maxZoom: _GalleryLocationScreenState._maxMapZoom,
                tileBuilder: (context, tileWidget, tile) => tileWidget,
              ),
              MarkerLayer(
                markers: [
                  for (final marker in visibleLocationMarkers)
                    Marker(
                      point: marker.point,
                      width:
                          (marker.isFor(activeCard) ? 118 : 104) * markerScale,
                      height:
                          (marker.isFor(activeCard) ? 116 : 104) * markerScale,
                      child: _LocationGroupMapMarker(
                        marker: marker,
                        selected: marker.isFor(activeCard),
                        headers: headers,
                        markerScale: markerScale,
                        onTap: () => onLocationTap(marker.card),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (loading)
            const Center(
              child: GalleryShimmerBox(
                width: 180,
                height: 180,
                borderRadius: 28,
              ),
            )
          else if (clusters.isEmpty && !hasCityCoordinate)
            Center(
              child: _MapLocationUnavailableHint(locationLabel: locationLabel),
            ),
        ],
      ),
    );
  }

  List<_LocationGroupMarker> _resolveSelectedMarker(
    List<_LocationGroupMarker> markers,
    GalleryCard selectedCard,
    List<_PhotoCluster> selectedClusters,
  ) {
    if (_PhotoCluster._isValidCoordinate(
      selectedCard.latitude,
      selectedCard.longitude,
    )) {
      return markers;
    }
    if (selectedClusters.isEmpty) return markers;

    // City-list cards contain only a few preview photos. A preview can have
    // missing or mismatched GPS even though the selected city's full response
    // has valid coordinates. Use the dominant loaded cluster for the selected
    // pin so it stays aligned with the map camera and the city's real photos.
    return [
      for (final marker in markers)
        if (!marker.isFor(selectedCard)) marker,
      _LocationGroupMarker(
        card: selectedCard,
        point: selectedClusters.first.point,
      ),
    ];
  }

  List<_LocationGroupMarker> _collapseCoincidentMarkers(
    List<_LocationGroupMarker> markers,
    GalleryCard selectedCard,
  ) {
    final byCoordinate = <String, _LocationGroupMarker>{};
    for (final marker in markers) {
      // Five decimal places is roughly one metre, so values describing the
      // same pin collapse without merging nearby, genuinely distinct places.
      final key =
          '${marker.point.latitude.toStringAsFixed(5)},'
          '${marker.point.longitude.toStringAsFixed(5)}';
      final existing = byCoordinate[key];
      if (existing == null || marker.isFor(selectedCard)) {
        byCoordinate[key] = marker;
      }
    }
    return byCoordinate.values.toList(growable: false);
  }
}

class _LocationGroupMapMarker extends StatelessWidget {
  final _LocationGroupMarker marker;
  final bool selected;
  final Map<String, String>? headers;
  final double markerScale;
  final VoidCallback onTap;

  const _LocationGroupMapMarker({
    required this.marker,
    required this.selected,
    required this.headers,
    required this.markerScale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(selected ? 20 : 18);
    final labelColor = primaryColor;
    final selectedScale = selected && markerScale >= 0.9 ? 1.08 : 1.02;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? selectedScale : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: (selected ? 108 : 94) * markerScale,
              padding: EdgeInsets.fromLTRB(
                6 * markerScale,
                6 * markerScale,
                6 * markerScale,
                7 * markerScale,
              ),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh.withAlpha(235),
                borderRadius: radius,
                border: Border.all(
                  color: selected ? primaryColor : primaryColor.withAlpha(95),
                  width: selected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(selected ? 46 : 24),
                    blurRadius: selected ? 22 : 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: (selected ? 42 : 36) * markerScale,
                      height: (selected ? 42 : 36) * markerScale,
                      child: marker.card.coverUrl.isEmpty
                          ? ColoredBox(
                              color: const Color(0xFFFFFFFF),
                              child: Icon(
                                CupertinoIcons.photo,
                                color: primaryColor,
                                size: (selected ? 18 : 16) * markerScale,
                              ),
                            )
                          : NetworkImageWithLoader(
                              imageUrl: marker.card.coverUrl,
                              title: marker.card.title,
                              headers: headers,
                            ),
                    ),
                  ),
                  SizedBox(height: 5 * markerScale),
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        marker.card.title,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: (selected ? 12 : 11) * markerScale,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            CustomPaint(
              size: Size(
                (selected ? 18 : 14) * markerScale,
                (selected ? 10 : 8) * markerScale,
              ),
              painter: _MarkerTipPainter(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh.withAlpha(235),
                shadowColor: Colors.black.withAlpha(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerTipPainter extends CustomPainter {
  final Color color;
  final Color shadowColor;

  const _MarkerTipPainter({required this.color, required this.shadowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawShadow(path, shadowColor, 4, true);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MarkerTipPainter oldDelegate) {
    return color != oldDelegate.color || shadowColor != oldDelegate.shadowColor;
  }
}

class _LocationTopPanel extends StatelessWidget {
  final String title;
  final int count;
  final int mappedCount;
  final TextEditingController controller;
  final List<GalleryCard> cities;
  final GalleryCard activeCard;
  final ScrollController cityScrollController;
  final VoidCallback onBack;
  final ValueChanged<GalleryCard> onCityTap;

  const _LocationTopPanel({
    required this.title,
    required this.count,
    required this.mappedCount,
    required this.controller,
    required this.cities,
    required this.activeCard,
    required this.cityScrollController,
    required this.onBack,
    required this.onCityTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainer.withAlpha(210),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(24),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RoundMapButton(
                    icon: CupertinoIcons.chevron_left,
                    onTap: onBack,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _LocationTitlePill(
                      title: title,
                      count: count,
                      mappedCount: mappedCount,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationSheet extends StatefulWidget {
  final TextEditingController controller;
  final List<GalleryCard> cities;
  final GalleryCard activeCard;
  final ScrollController cityScrollController;
  final ValueChanged<GalleryCard> onCityTap;

  const _LocationSheet({
    required this.controller,
    required this.cities,
    required this.activeCard,
    required this.cityScrollController,
    required this.onCityTap,
  });

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  static const double _collapsedHeight = 210;
  static const double _expandedFraction = 0.70;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchFocusNode = FocusNode()..addListener(_handleSearchFocus);
    widget.controller.addListener(_handleSearchText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleSearchText);
    _searchFocusNode
      ..removeListener(_handleSearchFocus)
      ..dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _handleSearchFocus() {
    if (_searchFocusNode.hasFocus) {
      _expandSheet();
    }
  }

  void _handleSearchText() {
    if (widget.controller.text.trim().isNotEmpty) {
      _expandSheet();
    }
  }

  void _expandSheet() {
    if (!_sheetController.isAttached) return;
    _sheetController.animateTo(
      _expandedFraction,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggle(double collapsedFraction) {
    if (!_sheetController.isAttached) return;
    final target =
        _sheetController.size > (collapsedFraction + _expandedFraction) / 2
        ? collapsedFraction
        : _expandedFraction;
    _sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _dragSheet(
    DragUpdateDetails details,
    double visibleHeight,
    double collapsedFraction,
  ) {
    if (!_sheetController.isAttached || visibleHeight <= 0) return;
    final nextSize =
        (_sheetController.size - details.primaryDelta! / visibleHeight).clamp(
          collapsedFraction,
          _expandedFraction,
        );
    _sheetController.jumpTo(nextSize);
  }

  void _finishSheetDrag(DragEndDetails details, double collapsedFraction) {
    if (!_sheetController.isAttached) return;
    final velocity = details.primaryVelocity ?? 0;
    final midpoint = (collapsedFraction + _expandedFraction) / 2;
    final expand =
        velocity < -250 ||
        (velocity.abs() <= 250 && _sheetController.size >= midpoint);
    _sheetController.animateTo(
      expand ? _expandedFraction : collapsedFraction,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final visibleHeight = mediaQuery.size.height - keyboardInset;
    final collapsedFraction =
        (_collapsedHeight * tabletScale(context) / visibleHeight).clamp(
          0.0,
          _expandedFraction,
        );
    // Kept as a separate, non-animated outer layer so the keyboard inset
    // (which changes independently of the expand/collapse gesture) never
    // drives the same AnimatedPadding that BackdropFilter's clip/blur
    // geometry depends on — combining the two caused the sheet to render
    // blank right as the keyboard opened.
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: collapsedFraction,
        minChildSize: collapsedFraction,
        maxChildSize: _expandedFraction,
        snap: true,
        snapSizes: [collapsedFraction, _expandedFraction],
        snapAnimationDuration: const Duration(milliseconds: 260),
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer.withAlpha(160),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(42),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _toggle(collapsedFraction),
                        onVerticalDragUpdate: (details) => _dragSheet(
                          details,
                          visibleHeight,
                          collapsedFraction,
                        ),
                        onVerticalDragEnd: (details) =>
                            _finishSheetDrag(details, collapsedFraction),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                      _CitySearchField(
                        controller: widget.controller,
                        focusNode: _searchFocusNode,
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: widget.controller,
                          builder: (context, _) {
                            final query = widget.controller.text
                                .trim()
                                .toLowerCase();
                            final filteredCities = _filterCities(
                              widget.cities,
                              query,
                            );
                            return _CityListView(
                              scrollController: scrollController,
                              cities: filteredCities,
                              activeCard: widget.activeCard,
                              onCityTap: (city) {
                                widget.onCityTap(city);
                                _searchFocusNode.unfocus();
                                _sheetController.animateTo(
                                  collapsedFraction,
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CityListView extends StatelessWidget {
  final ScrollController scrollController;
  final List<GalleryCard> cities;
  final GalleryCard activeCard;
  final ValueChanged<GalleryCard> onCityTap;

  const _CityListView({
    required this.scrollController,
    required this.cities,
    required this.activeCard,
    required this.onCityTap,
  });

  @override
  Widget build(BuildContext context) {
    if (cities.isEmpty) {
      return Center(
        child: Text(
          'No place found',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return ListView.separated(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 4),
      itemCount: cities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final city = cities[index];
        final selected =
            city.id == activeCard.id && city.value == activeCard.value;
        return _CityListTile(
          card: city,
          selected: selected,
          onTap: () => onCityTap(city),
        );
      },
    );
  }
}

class _CityListTile extends StatelessWidget {
  final GalleryCard card;
  final bool selected;
  final VoidCallback onTap;

  const _CityListTile({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? primaryColor.withAlpha(24)
          : Theme.of(context).colorScheme.surfaceContainer.withAlpha(135),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? primaryColor.withAlpha(140)
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 52 * tabletScale(context),
                  height: 52 * tabletScale(context),
                  child: card.coverUrl.isEmpty
                      ? ColoredBox(
                          color: const Color(0xFFFFFFFF),
                          child: Icon(
                            CupertinoIcons.photo,
                            color: primaryColor,
                          ),
                        )
                      : NetworkImageWithLoader(
                          imageUrl: card.coverUrl,
                          title: card.title,
                          headers: Get.find<GalleryController>().imageHeaders,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _locationCountryLabel(card),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${card.count ?? card.photos.length} Photos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapFallbackPainter extends CustomPainter {
  const _MapFallbackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xFFEAF1E6);
    final water = Paint()
      ..color = const Color(0xFFCFE7E4)
      ..style = PaintingStyle.fill;
    final road = Paint()
      ..color = Colors.white.withAlpha(180)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final mainRoad = Paint()
      ..color = const Color(0xFFF4C777).withAlpha(155)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawRect(Offset.zero & size, base);

    final river = Path()
      ..moveTo(0, size.height * 0.1)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.25,
        size.width * 0.08,
        size.height * 0.44,
        size.width * 0.22,
        size.height * 0.62,
      )
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.78,
        size.width * 0.08,
        size.height * 0.9,
        size.width * 0.22,
        size.height,
      )
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(river, water);

    for (var i = -1; i < 8; i++) {
      final y = i * size.height / 6;
      canvas.drawLine(Offset(-30, y), Offset(size.width + 30, y + 70), road);
    }
    for (var i = 0; i < 6; i++) {
      final x = i * size.width / 5;
      canvas.drawLine(Offset(x, -20), Offset(x - 80, size.height + 30), road);
    }
    canvas.drawLine(
      Offset(size.width * 0.18, -10),
      Offset(size.width * 0.76, size.height + 20),
      mainRoad,
    );
  }

  @override
  bool shouldRepaint(covariant _MapFallbackPainter oldDelegate) => false;
}

class _CitySearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;

  const _CitySearchField({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48 * tabletScale(context),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search city or country',
          prefixIcon: Icon(CupertinoIcons.search, color: primaryColor),
          filled: true,
          fillColor: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withAlpha(18)
              : Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withAlpha(145),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryColor.withAlpha(130)),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationTitlePill extends StatelessWidget {
  final String title;
  final int count;
  final int mappedCount;

  const _LocationTitlePill({
    required this.title,
    required this.count,
    required this.mappedCount,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainer.withAlpha(175),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.map_pin_ellipse, color: primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '$mappedCount mapped | $count photos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundMapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundMapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHigh.withAlpha(200),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 46 * tabletScale(context),
              height: 46 * tabletScale(context),
              child: Icon(
                icon,
                color: primaryColor,
                size: 22 * tabletScale(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapLocationUnavailableHint extends StatelessWidget {
  final String locationLabel;

  const _MapLocationUnavailableHint({required this.locationLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHigh.withAlpha(240),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.location, color: primaryColor, size: 19),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Map preview for $locationLabel is coming soon',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationGroupMarker {
  final GalleryCard card;
  final LatLng point;

  const _LocationGroupMarker({required this.card, required this.point});

  bool isFor(GalleryCard other) {
    return card.id == other.id && card.value == other.value;
  }

  static List<_LocationGroupMarker> fromCards(List<GalleryCard> cards) {
    return cards
        .map((card) {
          final point = pointForCard(card);
          if (point == null) return null;
          return _LocationGroupMarker(card: card, point: point);
        })
        .whereType<_LocationGroupMarker>()
        .toList();
  }

  static LatLng? pointForCard(GalleryCard card) {
    if (_PhotoCluster._isValidCoordinate(card.latitude, card.longitude)) {
      return LatLng(card.latitude!, card.longitude!);
    }
    for (final photo in card.photos) {
      final lat = photo.latitude;
      final lng = photo.longitude;
      if (_PhotoCluster._isValidCoordinate(lat, lng)) {
        return LatLng(lat!, lng!);
      }
    }
    return null;
  }
}

class _PhotoCluster {
  // EPSG:3857 becomes infinite at the geographic poles. flutter_map uses
  // this projection for its tile layer, so latitude must stay inside the
  // Web Mercator bounds even though LatLng itself accepts values up to ±90.
  static const double _webMercatorMaxLatitude = 85.05112878;

  final LatLng point;
  final List<GalleryPhoto> photos;

  const _PhotoCluster({required this.point, required this.photos});

  GalleryPhoto get cover => photos.first;

  static List<_PhotoCluster> fromPhotos(List<GalleryPhoto> photos) {
    final grouped = <String, List<GalleryPhoto>>{};
    final points = <String, LatLng>{};

    for (final photo in photos) {
      final lat = photo.latitude;
      final lng = photo.longitude;
      if (!_isValidCoordinate(lat, lng)) {
        continue;
      }
      final validLat = lat!;
      final validLng = lng!;

      final key =
          '${validLat.toStringAsFixed(5)},${validLng.toStringAsFixed(5)}';
      grouped.putIfAbsent(key, () => <GalleryPhoto>[]).add(photo);
      points.putIfAbsent(key, () => LatLng(validLat, validLng));
    }

    final clusters = grouped.entries
        .map(
          (entry) =>
              _PhotoCluster(point: points[entry.key]!, photos: entry.value),
        )
        .toList();
    clusters.sort((a, b) => b.photos.length.compareTo(a.photos.length));
    return clusters.take(80).toList();
  }

  static bool _isValidCoordinate(double? lat, double? lng) {
    return lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        // Some photo metadata uses 0,0 as a placeholder for missing GPS.
        // Rendering it puts unrelated city pins in the Gulf of Guinea
        // ("Null Island") and can replace a valid preview pin after loading.
        !(lat.abs() < 0.000001 && lng.abs() < 0.000001) &&
        lat.abs() <= _webMercatorMaxLatitude &&
        lng.abs() <= 180;
  }
}
