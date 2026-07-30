import 'package:flutter/material.dart';
import 'package:harismruti/utils/app_color.dart';

class GallerySectionLoader extends StatelessWidget {
  final double height;

  const GallerySectionLoader({super.key, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) => const GalleryShimmerBox(
          width: 170,
          height: double.infinity,
          borderRadius: 18,
        ),
      ),
    );
  }
}

class GalleryShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const GalleryShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 14,
  });

  @override
  State<GalleryShimmerBox> createState() => _GalleryShimmerBoxState();
}

class _GalleryShimmerBoxState extends State<GalleryShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (_controller.value * 2), -0.7),
              end: Alignment(0.2 + (_controller.value * 2), 0.7),
              colors: [
                scheme.surfaceContainerHigh,
                scheme.surfaceContainerHighest,
                scheme.surfaceContainerHigh,
              ],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

class GalleryEmptyState extends StatelessWidget {
  final double height;
  final String message;

  const GalleryEmptyState({
    super.key,
    this.height = 160,
    this.message = 'No smruti found',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: primaryColor.withAlpha(170),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
