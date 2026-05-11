import 'package:flutter/material.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/size_config.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color? color;
  final Color? textColor;
  final double widthFactor;
  final double heightFactor;
  final double borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    required this.onTap,
    this.color,
    this.textColor,
    this.widthFactor = 80,
    this.heightFactor = 5,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: SizeConfig.widthMultiplier! * widthFactor,
        height: SizeConfig.heightMultiplier! * heightFactor,
        decoration: BoxDecoration(
          color: color ?? primaryColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor ?? Colors.white,
              letterSpacing: 1,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
