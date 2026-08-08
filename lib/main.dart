import 'dart:async';

import 'package:flutter/cupertino.dart';
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
import 'package:harismruti/utils/app_images.dart';
import 'package:harismruti/utils/size_config.dart';
import 'package:harismruti/widget/internet_status_widget.dart';

void main() async {
  final bootstrapFuture = bootstrap();
  runApp(_StartupGate(bootstrapFuture: bootstrapFuture));
}

class _StartupGate extends StatelessWidget {
  const _StartupGate({required this.bootstrapFuture});

  final Future<void> bootstrapFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          return const MyApp();
        }

        final isDark =
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: isDark
                ? const Color(0xFF120F0E)
                : const Color(0xFFF5F5F5),
            body: Center(
              child: Image.asset(
                isDark ? AppImages.darkThemeLogo : AppImages.lightThemeLogo,
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
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
              theme: _buildTheme(Brightness.light),
              themeMode: _themeController.themeMode,
              builder: EasyLoading.init(
                builder: (context, child) {
                  return Stack(children: [child!, InternetStatusWidget()]);
                },
              ),

              darkTheme: _buildTheme(Brightness.dark),
            ),
          );
        },
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: primaryColor,
    brightness: brightness,
    surface: isDark ? const Color(0xFF181312) : const Color(0xFFFFFBF8),
  );

  return ThemeData(
    scaffoldBackgroundColor: Colors.transparent,
    useMaterial3: true,
    fontFamily: 'Poppins',
    brightness: brightness,
    colorScheme: scheme,
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scheme.surface,
      barBackgroundColor: scheme.surfaceContainer,
      textTheme: CupertinoTextThemeData(
        primaryColor: scheme.onSurface,
        textStyle: TextStyle(color: scheme.onSurface, fontFamily: 'Poppins'),
        actionTextStyle: TextStyle(color: primaryColor, fontFamily: 'Poppins'),
      ),
    ),
    canvasColor: scheme.surface,
    cardColor: scheme.surfaceContainer,
    dividerColor: scheme.outlineVariant,
    dialogTheme: DialogThemeData(backgroundColor: scheme.surfaceContainerHigh),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainer,
      modalBackgroundColor: scheme.surfaceContainer,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? Colors.white.withAlpha(18)
          : scheme.surfaceContainerHighest.withAlpha(220),
      hintStyle: TextStyle(
        color: isDark ? Colors.white.withAlpha(145) : scheme.onSurfaceVariant,
      ),
      labelStyle: TextStyle(
        color: isDark ? Colors.white.withAlpha(185) : scheme.onSurfaceVariant,
      ),
      floatingLabelStyle: TextStyle(
        color: isDark ? Colors.white : primaryColor,
        fontWeight: FontWeight.w700,
      ),
      prefixIconColor: isDark ? Colors.white.withAlpha(210) : primaryColor,
      suffixIconColor: isDark
          ? Colors.white.withAlpha(190)
          : scheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withAlpha(32) : scheme.outlineVariant,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withAlpha(38) : scheme.outlineVariant,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? Colors.white.withAlpha(180) : primaryColor,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.error),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: isDark ? Colors.white : primaryColor,
      selectionColor: primaryColor.withAlpha(70),
      selectionHandleColor: isDark ? Colors.white : primaryColor,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      iconTheme: IconThemeData(color: scheme.onSurface),
      actionsIconTheme: IconThemeData(color: scheme.onSurface),
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
    ),
  );
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
