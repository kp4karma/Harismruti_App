import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:harismruti/bootstrap.dart';
import 'package:harismruti/services/shorebird_update_service.dart';
import 'package:harismruti/services/analytics_service.dart';
import 'package:harismruti/services/deep_link_service.dart';
import 'package:harismruti/ui/controller/global_binding.dart';
import 'package:harismruti/ui/controller/theme_controller.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/app_routes.dart';
import 'package:harismruti/utils/size_config.dart';
import 'package:harismruti/widget/internet_status_widget.dart';

void main() async {
  await bootstrap();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ThemeController _themeController;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  final _shorebirdUpdates = ShorebirdUpdateService();
  late final _lifecycleObserver = _AppLifecycleObserver(
    onResumed: _checkForShorebirdUpdate,
  );

  @override
  void initState() {
    super.initState();
    _themeController = Get.put(ThemeController(), permanent: true);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(bootstrapDeferredServices());
      unawaited(DeepLinkService.instance.start());
      _checkForShorebirdUpdate();
    });
  }

  void _checkForShorebirdUpdate() {
    _shorebirdUpdates.checkForUpdate(_messengerKey);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // NotificationService.listenForInitialAndOpenedApp();
    return ScreenUtilInit(
      designSize: Size(430, 932),
      minTextAdapt: true,
      splitScreenMode: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final orientation = constraints.maxWidth > constraints.maxHeight
              ? Orientation.landscape
              : Orientation.portrait;
          SizeConfig().init(constraints, orientation);

          return Obx(
            () => GetMaterialApp(
              scaffoldMessengerKey: _messengerKey,
              debugShowCheckedModeBanner: false,
              initialBinding: GlobalBindings(),
              title: 'HariPrabodham Smruti',

              initialRoute: AppRoutes.splash,
              getPages: AppRoutes.routes,
              navigatorObservers: [AnalyticsRouteObserver()],
              theme: ThemeData(
                scaffoldBackgroundColor: Colors.transparent,
                useMaterial3: true,
                fontFamily: 'Poppins',
                colorSchemeSeed: primaryColor,
                brightness: Brightness.light,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  elevation: 0,
                ),
              ),
              themeMode: _themeController.themeMode,
              builder: EasyLoading.init(
                builder: (context, child) {
                  return Stack(children: [child!, InternetStatusWidget()]);
                },
              ),

              darkTheme: ThemeData(
                scaffoldBackgroundColor: Colors.transparent,
                useMaterial3: true,
                fontFamily: 'Poppins',
                brightness: Brightness.dark,
                colorSchemeSeed: primaryColor,
                appBarTheme: const AppBarTheme(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  scrolledUnderElevation: 0,
                  elevation: 0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  _AppLifecycleObserver({required this.onResumed});

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
