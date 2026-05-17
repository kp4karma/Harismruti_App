import 'package:flutter/material.dart';
import 'package:harismruti/widget/background/animated_words_background.dart';

class CustomBackground extends StatelessWidget {
  final Widget child;

  const CustomBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedWordsBackground(
      topToBottom: true,
      opacity: 0.28,
      veilAlpha: 142,
      chipBackground: false,
      animateFor: const Duration(seconds: 3),
      child: child,
    );
  }
}
