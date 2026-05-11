import 'package:flutter/cupertino.dart';
import 'package:harismruti/utils/app_color.dart';

class Spinner extends StatelessWidget {
  const Spinner({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CupertinoActivityIndicator(radius: 18, color: primaryColor),
    );
  }
}
