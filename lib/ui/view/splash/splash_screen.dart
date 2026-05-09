import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/helper/navigation_helper.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/internet_status_widget.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  AnimationController? scaleController;
  Animation<double>? scaleAnimation;

  Future<void> _checkInternetAndNavigate() async {
    List<ConnectivityResult> connectivity = await Connectivity().checkConnectivity();
    bool hasInternet = connectivity.contains(ConnectivityResult.wifi) || connectivity.contains(ConnectivityResult.mobile) || connectivity.contains(ConnectivityResult.ethernet);

    if (StorageHelper.isLogin()) {

    } else {
      NavigationHelper.navigateAndReplace(AppRoutes.login);
    }

    if (!hasInternet) {
      Future.delayed(Duration(milliseconds: 500), () {
        InternetStatusWidget.showNoInternetDialog(); // Show internet dialog
      });
    }
  }

  @override
  void initState() {
    super.initState();

    scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _checkInternetAndNavigate();
        }
      });

    scaleAnimation = Tween<double>(begin: 1.0, end: 30.0).animate(scaleController!);

    scaleController!.forward();
  }

  @override
  void dispose() {
    scaleController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body:
        Center(child: Text("Coming Soon"),)
    );
  }
}
