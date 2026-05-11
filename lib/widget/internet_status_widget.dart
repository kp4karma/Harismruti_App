import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import 'package:flutter/scheduler.dart';

class InternetStatusWidget extends StatefulWidget {
  const InternetStatusWidget({super.key});

  @override
  InternetStatusWidgetState createState() => InternetStatusWidgetState();

  static void showNoInternetDialog() {
    if (!(Get.isDialogOpen ?? false)) {
      Get.dialog(
        const PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text("🚫 No Internet"),
            content: Text("Please check your network connection."),
            actions: [],
          ),
        ),
        barrierDismissible: false,
      );
    }
  }

  static void closeNoInternetDialog() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }
}

class InternetStatusWidgetState extends State<InternetStatusWidget> {
  late Stream<List<ConnectivityResult>> _internetStream;
  bool _isDialogOpen = false; // Track dialog state

  @override
  void initState() {
    super.initState();
    _internetStream = Connectivity().onConnectivityChanged;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: _internetStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          bool hasInternet =
              snapshot.data!.contains(ConnectivityResult.wifi) ||
              snapshot.data!.contains(ConnectivityResult.mobile) ||
              snapshot.data!.contains(ConnectivityResult.ethernet);

          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!hasInternet && !_isDialogOpen) {
              InternetStatusWidget.showNoInternetDialog();
              _isDialogOpen = true;
            } else if (hasInternet && _isDialogOpen) {
              InternetStatusWidget.closeNoInternetDialog();
              _isDialogOpen = false;
            }
          });
        }
        return const SizedBox.shrink();
      },
    );
  }
}
