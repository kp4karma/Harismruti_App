import 'package:flutter/material.dart';
import 'package:harismruti/utils/app_color.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isEnabled;
  final Color? color;
  final Color? textColor;
  final double widthFactor;
  final double heightFactor;
  final double borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isEnabled = true,
    this.color,
    this.textColor,
    this.widthFactor = 80,
    this.heightFactor = 5,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Percentage of our own parent's width, not the raw device width --
        // this is what keeps the button from becoming a huge 800px+ pill
        // when the parent (e.g. a form card) is capped on a tablet.
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        return GestureDetector(
          onTap: isEnabled ? onTap : null,
          child: Container(
            width: maxWidth * (widthFactor / 100),
            height: screenHeight * (heightFactor / 100),
            decoration: BoxDecoration(
              color: isEnabled
                  ? color ?? primaryColor
                  : Colors.black.withAlpha(45),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isEnabled
                      ? textColor ?? Colors.white
                      : Colors.black.withAlpha(105),
                  letterSpacing: 1,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
