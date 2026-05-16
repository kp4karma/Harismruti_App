import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:harismruti/bootstrap.dart';
import 'package:harismruti/ui/controller/global_binding.dart';
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
  @override
  Widget build(BuildContext context) {
    // NotificationService.listenForInitialAndOpenedApp();
    return ScreenUtilInit(
      designSize: Size(430, 932),
      minTextAdapt: true,
      splitScreenMode: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          SizeConfig().init(constraints, Orientation.portrait);

          return GetMaterialApp(
            debugShowCheckedModeBanner: false,
            initialBinding: GlobalBindings(),
            title: 'Hari Smurti',

            initialRoute: AppRoutes.splash,
            getPages: AppRoutes.routes,
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
            builder: EasyLoading.init(
              builder: (context, child) {
                return Stack(children: [child!, InternetStatusWidget()]);
              },
            ),

            darkTheme: ThemeData(
              useMaterial3: true,
              fontFamily: 'Poppins',
              brightness: Brightness.light,
              colorSchemeSeed: primaryColor,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
            ),
          );
        },
      ),
    );
  }
}
