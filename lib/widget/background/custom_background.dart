import 'package:flutter/material.dart';
import 'package:harismruti/utils/app_color.dart';

class CustomBackground extends StatelessWidget {
  Widget child;

  CustomBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.maxFinite,
      height: double.maxFinite,
      color: backgroundColor,
      child: child,
    );
  }
}
