import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/view/auth/login.dart';
import 'package:harismruti/ui/view/auth/login_home.dart';
import 'package:harismruti/ui/view/auth/register.dart';
import 'package:harismruti/ui/view/home/home_screen.dart';
import 'package:harismruti/ui/view/splash/splash_screen.dart';

class AppRoutes {
  static const String splash = "/splash";
  static const String login = "/login";
  static const String loginMobile = "$login/mobile";
  static const String register = "/register";
  static const String home = "/home";

  static List<GetPage> routes = [
    GetPage(name: splash, page: () => const SplashScreen()),
    GetPage(
      name: login,
      page: () => const LoginHomeScreen(),
      transition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 420),
    ),
    GetPage(
      name: loginMobile,
      page: () => const LoginScreen(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: register,
      page: () => const RegisterScreen(),
      transition: Transition.cupertino,
    ),
    GetPage(
      name: home,
      page: () => HomeScreen(),
      transition: Transition.fadeIn,
      curve: Curves.easeOutCubic,
      transitionDuration: const Duration(milliseconds: 520),
    ),
  ];
}
