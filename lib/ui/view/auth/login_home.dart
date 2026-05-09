import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/ui/view/Auth/login.dart';
import 'package:harismruti/ui/view/Auth/register.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_string.dart';
import 'package:harismruti/utils/size_config.dart';
import 'package:harismruti/widget/appbar/custom_appbar.dart';
import 'package:harismruti/widget/buttons/custom_button.dart';
import 'package:harismruti/widget/carousel/auto_scroll_carousel.dart';

class LoginHomeScreen extends StatefulWidget {
  const LoginHomeScreen({Key? key}) : super(key: key);
  @override
  State<LoginHomeScreen> createState() => _LoginHomeScreenState();
}

class _LoginHomeScreenState extends State<LoginHomeScreen> {


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: CustomAppbar(isCenterTitle: true),
      body: Column(
        children: [
          Expanded(child: AutoScrollCarousel(imageUrls: imageUrls)),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            margin: EdgeInsets.zero,
            shadowColor: Colors.transparent,
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: SizeConfig.heightMultiplier! * 4),
                      CustomButton(text: "Sign In", onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (context) => LoginScreen(),
                          ),
                        );
                      }),
                      SizedBox(height: SizeConfig.heightMultiplier! * 2),
                      CustomButton(
                        text: "Register",
                        onTap: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => RegisterScreen(),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: SizeConfig.heightMultiplier! * 2),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
