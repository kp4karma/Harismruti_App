import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/ui/view/auth/login.dart';
import 'package:harismruti/ui/view/auth/register.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/utils/size_config.dart';
import 'package:harismruti/widget/appbar/custom_appbar.dart';
import 'package:harismruti/widget/buttons/custom_button.dart';
import 'package:harismruti/widget/carousel/auth_recent_carousel.dart';

class LoginHomeScreen extends StatefulWidget {
  const LoginHomeScreen({super.key});
  @override
  State<LoginHomeScreen> createState() => _LoginHomeScreenState();
}

class _LoginHomeScreenState extends State<LoginHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: CustomAppbar(isCenterTitle: true),
      body: Column(
        children: [
          const Expanded(child: AuthRecentCarousel()),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            margin: EdgeInsets.zero,
            shadowColor: Colors.transparent,
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: SafeArea(
              top: false,
              child: ResponsiveCenter(
                maxWidth: kFormMaxWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: SizeConfig.heightMultiplier! * 4),
                        CustomButton(
                          text: "Sign In",
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                settings: const RouteSettings(name: 'Login'),
                                builder: (context) => LoginScreen(),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: SizeConfig.heightMultiplier! * 2),
                        CustomButton(
                          text: "Register",
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                settings: const RouteSettings(name: 'Register'),
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
          ),
        ],
      ),
    );
  }
}
