import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:harismruti/api/models/gallery_models.dart';
import 'package:harismruti/ui/controller/gallery_controller.dart';
import 'package:harismruti/ui/view/gallery/gallery_detail_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/widget/gallery/gallery_states.dart';
import 'package:harismruti/widget/network_Image_with_loader.dart';
import 'package:latlong2/latlong.dart' hide Path;

class GalleryLocationScreen extends StatefulWidget {
  final GalleryCard card;

  const GalleryLocationScreen({super.key, required this.card});

  @override
  State<GalleryLocationScreen> createState() => _GalleryLocationScreenState();
}

class _GalleryLocationScreenState extends State<GalleryLocationScreen> {
  static final LatLng _fallbackCenter = LatLng(20.5937, 78.9629);

  late Future<List<GalleryPhoto>> _photosFuture;
  final GalleryController _controller = Get.find<GalleryController>();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _cityScrollController = ScrollController();
  Timer? _autoScrollTimer;
  String _query = '';
  String? _lastFitKey;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _photosFuture = _controller.loadPhotosForCard(widget.card);
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCityAutoScroll());
  }

  @override
  void didUpdateWidget(covariant GalleryLocationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.id != widget.card.id ||
        oldWidget.card.value != widget.card.value) {
      _photosFuture = _controller.loadPhotosForCard(widget.card);
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    _cityScrollController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    final value = _searchController.text.trim().toLowerCase();
    if (value == _query) return;
    setState(() => _query = value);
  }

  void _startCityAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!_cityScrollController.hasClients) return;
      final position = _cityScrollController.position;
      if (position.maxScrollExtent <= 0) return;
      final next = position.pixels + 0.35;
      _cityScrollController.jumpTo(next >= position.maxScrollExtent ? 0 : next);
    });
  }

  void _openCity(GalleryCard card) {
    if (card.id == widget.card.id && card.value == widget.card.value) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => GalleryLocationScreen(card: card),
        transitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  void _openPhotos(List<GalleryPhoto> photos, int total) {
    if (photos.isEmpty) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => GalleryDetailScreen(
          title: widget.card.title,
          subtitle: '$total Photos',
          coverUrl: photos.first.thumbnailUrl,
          loader: () async => photos,
        ),
      ),
    );
  }

  Future<void> _moveToCurrentLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage('Location service is off');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Location permission denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _mapController.move(LatLng(position.latitude, position.longitude), 14);
    } catch (_) {
      _showMessage('Unable to get current location');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _fitCityMarkers(List<_PhotoCluster> clusters) {
    final validClusters = clusters
        .where(
          (cluster) =>
              cluster.point.latitude.isFinite &&
              cluster.point.longitude.isFinite,
        )
        .toList();
    if (validClusters.isEmpty) {
      _mapController.move(_fallbackCenter, 4.5);
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
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  List<GalleryCard> get _matchingCities {
    final locations = _controller.locations.toList(growable: false);
    if (_query.isEmpty) return locations;
    return locations
        .where((card) => card.title.toLowerCase().contains(_query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3EA),
      body: FutureBuilder<List<GalleryPhoto>>(
        future: _photosFuture,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState != ConnectionState.done;
          final photos = snapshot.data ?? widget.card.photos;
          final total = widget.card.count ?? photos.length;
          final clusters = _PhotoCluster.fromPhotos(photos);
          final center = clusters.isEmpty
              ? _fallbackCenter
              : clusters.first.point;
          final cities = _matchingCities;

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
              (_) => mounted ? _fitCityMarkers(clusters) : null,
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: _PhotoCoordinateMap(
                  mapController: _mapController,
                  center: center,
                  clusters: clusters,
                  photos: photos,
                  total: total,
                  locationLabel: widget.card.title,
                  headers: _controller.imageHeaders,
                  loading: loading,
                  onOpenPhotos: () => _openPhotos(photos, total),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _LocationTopPanel(
                  title: widget.card.title,
                  count: total,
                  mappedCount: clusters.fold<int>(
                    0,
                    (sum, cluster) => sum + cluster.photos.length,
                  ),
                  controller: _searchController,
                  cities: cities,
                  activeCard: widget.card,
                  cityScrollController: _cityScrollController,
                  locating: _locating,
                  onBack: () => Navigator.pop(context),
                  onCityTap: _openCity,
                  onCurrentLocationTap: _moveToCurrentLocation,
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 14,
                child: _LocationPlacesPanel(
                  controller: _searchController,
                  cities: cities,
                  activeCard: widget.card,
                  cityScrollController: _cityScrollController,
                  onCityTap: _openCity,
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
  final List<GalleryPhoto> photos;
  final int total;
  final String locationLabel;
  final Map<String, String>? headers;
  final bool loading;
  final VoidCallback onOpenPhotos;

  const _PhotoCoordinateMap({
    required this.mapController,
    required this.center,
    required this.clusters,
    required this.photos,
    required this.total,
    required this.locationLabel,
    required this.headers,
    required this.loading,
    required this.onOpenPhotos,
  });

  @override
  Widget build(BuildContext context) {
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
                maxZoom: 19,
                tileBuilder: (context, tileWidget, tile) => tileWidget,
              ),
              MarkerLayer(
                markers: [
                  for (final cluster in clusters)
                    Marker(
                      point: cluster.point,
                      width: 86,
                      height: 92,
                      child: _PhotoMapMarker(
                        cluster: cluster,
                        locationLabel: locationLabel,
                        headers: headers,
                        onTap: onOpenPhotos,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (loading && photos.isEmpty)
            const Center(
              child: GalleryShimmerBox(
                width: 180,
                height: 180,
                borderRadius: 28,
              ),
            )
          else if (clusters.isEmpty)
            Center(child: _NoCoordinateNotice(total: total)),
          Positioned(
            right: 18,
            bottom: 300,
            child: _RoundMapButton(
              icon: CupertinoIcons.layers_alt,
              onTap: onOpenPhotos,
              highlighted: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoMapMarker extends StatelessWidget {
  final _PhotoCluster cluster;
  final String locationLabel;
  final Map<String, String>? headers;
  final VoidCallback onTap;

  const _PhotoMapMarker({
    required this.cluster,
    required this.locationLabel,
    required this.headers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 78,
                  padding: const EdgeInsets.fromLTRB(5, 5, 5, 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(132),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withAlpha(230)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(28),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withAlpha(70),
                        blurRadius: 10,
                        offset: const Offset(-3, -3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MarkerImage(cluster: cluster, headers: headers),
                      const SizedBox(height: 4),
                      Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF1E1E1E),
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            CustomPaint(
              size: const Size(18, 10),
              painter: _MarkerTipPainter(
                color: Colors.white.withAlpha(132),
                shadowColor: Colors.black.withAlpha(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerImage extends StatelessWidget {
  final _PhotoCluster cluster;
  final Map<String, String>? headers;

  const _MarkerImage({required this.cluster, required this.headers});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(
            child: NetworkImageWithLoader(
              imageUrl: cluster.cover.thumbnailUrl,
              title: cluster.cover.title ?? 'Location',
              headers: headers,
            ),
          ),
          if (cluster.photos.length > 1)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                height: 19,
                constraints: const BoxConstraints(minWidth: 19),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  cluster.photos.length > 99
                      ? '99+'
                      : cluster.photos.length.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
        ],
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
  final bool locating;
  final VoidCallback onBack;
  final ValueChanged<GalleryCard> onCityTap;
  final VoidCallback onCurrentLocationTap;

  const _LocationTopPanel({
    required this.title,
    required this.count,
    required this.mappedCount,
    required this.controller,
    required this.cities,
    required this.activeCard,
    required this.cityScrollController,
    required this.locating,
    required this.onBack,
    required this.onCityTap,
    required this.onCurrentLocationTap,
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
                color: Colors.white.withAlpha(178),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withAlpha(210)),
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
                  const SizedBox(width: 8),
                  _CurrentLocationButton(
                    locating: locating,
                    onTap: onCurrentLocationTap,
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

class _LocationPlacesPanel extends StatelessWidget {
  final TextEditingController controller;
  final List<GalleryCard> cities;
  final GalleryCard activeCard;
  final ScrollController cityScrollController;
  final ValueChanged<GalleryCard> onCityTap;

  const _LocationPlacesPanel({
    required this.controller,
    required this.cities,
    required this.activeCard,
    required this.cityScrollController,
    required this.onCityTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(188),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withAlpha(220)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(42),
                blurRadius: 34,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              _CitySearchField(controller: controller),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: cities.isEmpty
                    ? Center(
                        child: Text(
                          'No place found',
                          style: TextStyle(
                            color: Colors.black.withAlpha(130),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: cityScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: cities.length <= 1
                            ? cities.length
                            : cities.length * 1000,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final city = cities[index % cities.length];
                          final selected =
                              city.id == activeCard.id &&
                              city.value == activeCard.value;
                          return _CityPhotoChip(
                            card: city,
                            selected: selected,
                            onTap: () => onCityTap(city),
                          );
                        },
                      ),
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

  const _CitySearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search city',
          prefixIcon: Icon(CupertinoIcons.search, color: primaryColor),
          filled: true,
          fillColor: Colors.white.withAlpha(170),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withAlpha(190)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: primaryColor.withAlpha(130)),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.white.withAlpha(190)),
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationButton extends StatelessWidget {
  final bool locating;
  final VoidCallback onTap;

  const _CurrentLocationButton({required this.locating, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: primaryColor.withAlpha(205),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: locating
                  ? const CupertinoActivityIndicator(color: Colors.white)
                  : const Icon(
                      CupertinoIcons.location_fill,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CityPhotoChip extends StatelessWidget {
  final GalleryCard card;
  final bool selected;
  final VoidCallback onTap;

  const _CityPhotoChip({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 132,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? primaryColor : Colors.white,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(selected ? 34 : 18),
              blurRadius: selected ? 16 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetworkImageWithLoader(
              imageUrl: card.coverUrl,
              title: card.title,
              headers: Get.find<GalleryController>().imageHeaders,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withAlpha(155)],
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${card.count ?? card.photos.length} Photos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withAlpha(220),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            color: Colors.white.withAlpha(116),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withAlpha(180)),
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
  final bool highlighted;

  const _RoundMapButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Material(
          color: highlighted
              ? primaryColor.withAlpha(215)
              : Colors.white.withAlpha(145),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                icon,
                color: highlighted ? Colors.white : primaryColor,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoCoordinateNotice extends StatelessWidget {
  final int total;

  const _NoCoordinateNotice({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        '$total photos found, but latitude and longitude are not available.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PhotoCluster {
  final LatLng point;
  final List<GalleryPhoto> photos;

  const _PhotoCluster({required this.point, required this.photos});

  GalleryPhoto get cover => photos.first;

  static List<_PhotoCluster> fromPhotos(List<GalleryPhoto> photos) {
    final grouped = <String, List<GalleryPhoto>>{};
    final points = <String, LatLng>{};
    final missingCoordinatePhotos = <GalleryPhoto>[];

    for (final photo in photos) {
      final lat = photo.latitude;
      final lng = photo.longitude;
      if (!_isValidCoordinate(lat, lng)) {
        missingCoordinatePhotos.add(photo);
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
    final visibleClusters = clusters
        .take(math.min(clusters.length, 80))
        .toList();

    if (missingCoordinatePhotos.isEmpty) return visibleClusters;
    final base = visibleClusters.isEmpty
        ? _GalleryLocationScreenState._fallbackCenter
        : visibleClusters.first.point;
    final randomCount = math.min(missingCoordinatePhotos.length, 10);
    for (var index = 0; index < randomCount; index++) {
      visibleClusters.add(
        _PhotoCluster(
          point: _offsetPoint(base, index),
          photos: [missingCoordinatePhotos[index]],
        ),
      );
    }
    return visibleClusters;
  }

  static bool _isValidCoordinate(double? lat, double? lng) {
    return lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180;
  }

  static LatLng _offsetPoint(LatLng base, int index) {
    const offsets = [
      Offset(0.012, 0.000),
      Offset(-0.010, 0.008),
      Offset(0.007, -0.011),
      Offset(-0.006, -0.010),
      Offset(0.014, 0.010),
      Offset(-0.014, 0.001),
      Offset(0.004, 0.016),
      Offset(0.017, -0.005),
      Offset(-0.016, -0.013),
      Offset(0.000, -0.017),
    ];
    final offset = offsets[index % offsets.length];
    return LatLng(
      (base.latitude + offset.dx).clamp(-85.0, 85.0),
      (base.longitude + offset.dy).clamp(-180.0, 180.0),
    );
  }
}
