import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class AnimatedWordsBackground extends StatefulWidget {
  final Widget child;
  final bool topToBottom;
  final double opacity;
  final int veilAlpha;
  final bool chipBackground;
  final Duration? animateFor;

  const AnimatedWordsBackground({
    super.key,
    required this.child,
    this.topToBottom = false,
    this.opacity = 0.62,
    this.veilAlpha = 178,
    this.chipBackground = true,
    this.animateFor,
  });

  @override
  State<AnimatedWordsBackground> createState() =>
      _AnimatedWordsBackgroundState();
}

class _AnimatedWordsBackgroundState extends State<AnimatedWordsBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showWords = true;

  static const Duration _fadeOutDuration = Duration(milliseconds: 450);

  static const List<String> _words = [
    'દાસત્વ',
    'સુહૃદભાવ',
    'આત્મીયતા',
    'નિરપેક્ષ',
    'નિર્વ્યાજ',
    'નિર્દંભ',
    'નિર્લેપ',
    'નિર્મોહી',
    'નિઃસ્વાદી',
    'સરળતા',
    'સહજતા',
    'સમર્પણ',
    'સ્વધર્મ',
    'સેવા',
    'સ્મૃતિ',
    'મહિમા',
    'દિવ્યભાવ',
    'નિર્દોષ',
    'સંબંધયોગ',
    'સરસતા',
    'અમૃત',
    'અક્ષર',
    'સાદગી',
    'સાધુતા',
    'સુરુચિ',
    'સ્થિરતા',
    'સ્વીકાર',
    'નિમિત્ત',
    'તારે લઈને હું',
    'we are one',
    'તું રાજી થા',
    'પ્રબોધમ',
    'ગુણાતીત',
    'અક્ષરધામ',
    'અનિર્દેશી',
    'આતમ',
    'શ્રીહરિ',
    'તુહી તું',
    'કરુણાનિધિ',
  ];

  static const List<_WordParticle> _particles = [
    _WordParticle(0.02, 0.00, 0.00, -0.10, 0),
    _WordParticle(0.28, 0.03, 0.06, 0.08, 1),
    _WordParticle(0.55, 0.01, 0.12, -0.07, 2),
    _WordParticle(0.82, 0.06, 0.18, 0.09, 3),
    _WordParticle(0.10, 0.16, 0.24, -0.08, 4),
    _WordParticle(0.38, 0.18, 0.30, 0.07, 5),
    _WordParticle(0.66, 0.15, 0.36, -0.10, 6),
    _WordParticle(0.90, 0.22, 0.42, 0.08, 7),
    _WordParticle(0.03, 0.31, 0.48, -0.08, 8),
    _WordParticle(0.31, 0.33, 0.54, 0.07, 9),
    _WordParticle(0.58, 0.30, 0.60, -0.09, 10),
    _WordParticle(0.82, 0.37, 0.66, 0.08, 11),
    _WordParticle(0.13, 0.47, 0.72, -0.07, 12),
    _WordParticle(0.42, 0.49, 0.78, 0.08, 13),
    _WordParticle(0.71, 0.45, 0.84, -0.10, 14),
    _WordParticle(0.94, 0.53, 0.90, 0.07, 15),
    _WordParticle(0.04, 0.63, 0.96, -0.09, 16),
    _WordParticle(0.32, 0.66, 0.04, 0.08, 17),
    _WordParticle(0.60, 0.61, 0.10, -0.07, 18),
    _WordParticle(0.84, 0.70, 0.16, 0.10, 19),
    _WordParticle(0.14, 0.79, 0.22, -0.09, 20),
    _WordParticle(0.45, 0.82, 0.28, 0.08, 21),
    _WordParticle(0.73, 0.76, 0.34, -0.07, 22),
    _WordParticle(0.95, 0.87, 0.40, 0.09, 23),
    _WordParticle(0.06, 0.96, 0.46, -0.08, 24),
    _WordParticle(0.31, 1.00, 0.52, 0.08, 25),
    _WordParticle(0.57, 0.93, 0.58, -0.09, 26),
    _WordParticle(0.82, 1.02, 0.64, 0.07, 27),
    _WordParticle(0.18, 1.12, 0.70, -0.10, 28),
    _WordParticle(0.50, 1.15, 0.76, 0.08, 29),
    _WordParticle(0.76, 1.10, 0.82, -0.07, 30),
    _WordParticle(0.02, 1.24, 0.88, 0.08, 31),
  ];

  static const List<Color> _wordColors = [
    Color(0xFF933525),
    Color(0xFFE05A47),
    Color(0xFFF6A20A),
    Color(0xFF2E8B7C),
    Color(0xFF2477A8),
    Color(0xFF7B4BB7),
    Color(0xFFC14683),
    Color(0xFF4E7D2D),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    final animateFor = widget.animateFor;
    if (animateFor != null) {
      Future.delayed(animateFor, () {
        if (!mounted) return;
        setState(() => _showWords = false);
        Future.delayed(_fadeOutDuration, () {
          if (mounted) _controller.stop();
        });
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFBF5), Color(0xFFF4F7F7), Color(0xFFFFF4EC)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedOpacity(
            opacity: _showWords ? 1 : 0,
            duration: _fadeOutDuration,
            curve: Curves.easeOut,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: _particles.map((particle) {
                        return _buildWord(
                          particle,
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.9,
                colors: [
                  Colors.white.withAlpha(24),
                  Colors.white.withAlpha(widget.veilAlpha),
                ],
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }

  Widget _buildWord(_WordParticle particle, double width, double height) {
    final progress = (_controller.value + particle.delay) % 1;
    final travel = height + 120;
    final rawTop = widget.topToBottom
        ? (particle.y * height) + (progress * travel)
        : (particle.y * height) - (progress * travel);
    final top = rawTop % travel - 58;
    final sway = math.sin((progress * math.pi * 2) + particle.wordIndex) * 16;
    final left = (particle.x * width + sway).clamp(4.0, width - 96.0);
    final pulse = 0.9 + (math.sin(progress * math.pi * 2) + 1) * 0.06;
    final word = _words[particle.wordIndex % _words.length];
    final color = _wordColors[particle.wordIndex % _wordColors.length];

    return Positioned(
      left: left,
      top: top,
      child: Transform.rotate(
        angle: particle.rotation,
        child: Transform.scale(
          scale: pulse,
          child: Opacity(
            opacity: widget.opacity,
            child: _AnimatedWordLabel(
              label: word,
              color: color,
              chipBackground: widget.chipBackground,
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedWordLabel extends StatelessWidget {
  final String label;
  final Color color;
  final bool chipBackground;

  const _AnimatedWordLabel({
    required this.label,
    required this.color,
    required this.chipBackground,
  });

  @override
  Widget build(BuildContext context) {
    if (!chipBackground) {
      return Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              color: Colors.white.withAlpha(180),
              blurRadius: 7,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withAlpha(42),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withAlpha(135)),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(26),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _WordParticle {
  final double x;
  final double y;
  final double delay;
  final double rotation;
  final int wordIndex;

  const _WordParticle(
    this.x,
    this.y,
    this.delay,
    this.rotation,
    this.wordIndex,
  );
}
