import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedGalleryBackground extends StatefulWidget {
  final Widget child;
  final bool dark;
  final double tileOpacity;

  const AnimatedGalleryBackground({
    super.key,
    required this.child,
    this.dark = false,
    this.tileOpacity = 0.34,
  });

  @override
  State<AnimatedGalleryBackground> createState() =>
      _AnimatedGalleryBackgroundState();
}

class _AnimatedGalleryBackgroundState extends State<AnimatedGalleryBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<_GalleryTileData> _tiles = [
    _GalleryTileData(0.02, 0.02, 78, 104, 0.00, -0.12, _TileTone.gold),
    _GalleryTileData(0.34, 0.00, 62, 82, 0.18, 0.10, _TileTone.rose),
    _GalleryTileData(0.66, 0.07, 88, 116, 0.36, -0.08, _TileTone.teal),
    _GalleryTileData(0.88, 0.00, 58, 76, 0.54, 0.14, _TileTone.ink),
    _GalleryTileData(0.14, 0.23, 64, 86, 0.72, 0.09, _TileTone.teal),
    _GalleryTileData(0.48, 0.26, 92, 122, 0.08, -0.11, _TileTone.gold),
    _GalleryTileData(0.78, 0.26, 70, 92, 0.26, 0.08, _TileTone.rose),
    _GalleryTileData(0.01, 0.48, 92, 120, 0.44, 0.13, _TileTone.ink),
    _GalleryTileData(0.32, 0.50, 66, 88, 0.62, -0.09, _TileTone.gold),
    _GalleryTileData(0.63, 0.46, 78, 104, 0.80, 0.10, _TileTone.teal),
    _GalleryTileData(0.86, 0.51, 84, 112, 0.12, -0.13, _TileTone.rose),
    _GalleryTileData(0.12, 0.72, 76, 102, 0.30, 0.08, _TileTone.gold),
    _GalleryTileData(0.42, 0.76, 94, 124, 0.48, -0.10, _TileTone.ink),
    _GalleryTileData(0.74, 0.72, 62, 84, 0.66, 0.12, _TileTone.teal),
    _GalleryTileData(0.94, 0.82, 72, 96, 0.84, -0.08, _TileTone.gold),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.dark
        ? const [Color(0xFF111111), Color(0xFF2A1715), Color(0xFF151A1C)]
        : const [Color(0xFFF8F2EA), Color(0xFFF4F6F6), Color(0xFFFFF9F0)];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: _tiles.map((tile) {
                      return _buildTile(
                        tile,
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.9,
                colors: widget.dark
                    ? [
                        Colors.transparent,
                        const Color(0xFF111111).withAlpha(190),
                      ]
                    : [Colors.white.withAlpha(36), Colors.white.withAlpha(138)],
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }

  Widget _buildTile(_GalleryTileData tile, double width, double height) {
    final progress = (_controller.value + tile.delay) % 1;
    final travel = height + 220;
    final top = ((tile.y * height) + progress * travel) % travel - 110;
    final sway = math.sin((progress * math.pi * 2) + (tile.x * 8)) * 22;
    final left = (tile.x * width + sway).clamp(-30.0, width - 28.0);
    final scale = 0.94 + (math.sin(progress * math.pi * 2) + 1) * 0.035;

    return Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: tile.rotation,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: widget.tileOpacity,
            child: _GalleryTile(
              width: tile.width,
              height: tile.height,
              tone: tile.tone,
              dark: widget.dark,
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  final double width;
  final double height;
  final _TileTone tone;
  final bool dark;

  const _GalleryTile({
    required this.width,
    required this.height,
    required this.tone,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _palette(tone);

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withAlpha(18) : Colors.white.withAlpha(210),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? Colors.white.withAlpha(34)
              : Colors.white.withAlpha(220),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(dark ? 76 : 22),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: CustomPaint(
          painter: _GalleryTilePainter(
            sky: palette.$1,
            accent: palette.$2,
            ground: palette.$3,
          ),
        ),
      ),
    );
  }

  (Color, Color, Color) _palette(_TileTone tone) {
    return switch (tone) {
      _TileTone.gold => (
        const Color(0xFFFFD36F),
        const Color(0xFFC95B35),
        const Color(0xFF71423A),
      ),
      _TileTone.rose => (
        const Color(0xFFEFA7A3),
        const Color(0xFF8B3A5E),
        const Color(0xFF472A46),
      ),
      _TileTone.teal => (
        const Color(0xFF8ED9D2),
        const Color(0xFF256D72),
        const Color(0xFF1E3F47),
      ),
      _TileTone.ink => (
        const Color(0xFF8894A7),
        const Color(0xFF343D59),
        const Color(0xFF171B2F),
      ),
    };
  }
}

class _GalleryTilePainter extends CustomPainter {
  final Color sky;
  final Color accent;
  final Color ground;

  const _GalleryTilePainter({
    required this.sky,
    required this.accent,
    required this.ground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [sky, ground],
      ).createShader(rect);

    canvas.drawRect(rect, paint);

    final sunPaint = Paint()..color = accent.withAlpha(210);
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.28),
      size.shortestSide * 0.14,
      sunPaint,
    );

    final ridgePaint = Paint()..color = ground.withAlpha(220);
    final ridge = Path()
      ..moveTo(0, size.height * 0.72)
      ..lineTo(size.width * 0.26, size.height * 0.46)
      ..lineTo(size.width * 0.52, size.height * 0.72)
      ..lineTo(size.width * 0.72, size.height * 0.54)
      ..lineTo(size.width, size.height * 0.76)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(ridge, ridgePaint);

    final foregroundPaint = Paint()..color = accent.withAlpha(190);
    final foreground = Path()
      ..moveTo(0, size.height * 0.88)
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.76,
        size.width * 0.62,
        size.height * 0.88,
      )
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.96,
        size.width,
        size.height * 0.86,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(foreground, foregroundPaint);
  }

  @override
  bool shouldRepaint(covariant _GalleryTilePainter oldDelegate) {
    return oldDelegate.sky != sky ||
        oldDelegate.accent != accent ||
        oldDelegate.ground != ground;
  }
}

class _GalleryTileData {
  final double x;
  final double y;
  final double width;
  final double height;
  final double delay;
  final double rotation;
  final _TileTone tone;

  const _GalleryTileData(
    this.x,
    this.y,
    this.width,
    this.height,
    this.delay,
    this.rotation,
    this.tone,
  );
}

enum _TileTone { gold, rose, teal, ink }
