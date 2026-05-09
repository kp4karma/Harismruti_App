import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SubHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final bool showIcon;

  const SubHeader({
    super.key,
    required this.title,
    this.onTap,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // Title
              Expanded(
                child: Text(
                  title,
                  style:  TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF322318),
                  ),
                ),
              ),
              // Icon button
              if (showIcon)
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(6.0),
                      child: Icon(
                        CupertinoIcons.right_chevron,
                        color: Color(0xFF322318),
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8), // or call getVerticalSizeBox()
      ],
    );
  }
}
