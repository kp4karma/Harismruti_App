import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pin_code_fields/flutter_pin_code_fields.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/auth_controller.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/email_mask_helper.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/utils/size_config.dart';
import 'package:harismruti/widget/buttons/custom_button.dart';
import 'package:harismruti/widget/carousel/auth_recent_carousel.dart';

class OTPScreen extends StatefulWidget {
  const OTPScreen({super.key});

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final AuthController _authController = Get.find<AuthController>();
  String _otp = '';
  bool _hasSubmittedOtp = false;

  Future<void> _submitOtp(String otp) async {
    final cleanOtp = otp.trim();
    if (cleanOtp.length != 6 || _authController.isLoading.value) return;
    if (_hasSubmittedOtp && cleanOtp == _otp) return;

    setState(() {
      _otp = cleanOtp;
      _hasSubmittedOtp = true;
    });

    final verified = await _authController.verifyOtp(otp: cleanOtp);
    if (!verified && mounted) {
      setState(() => _hasSubmittedOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        leadingWidth: 56,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(6.0),
                child: Icon(
                  CupertinoIcons.left_chevron,
                  color: Color(0xFF322318),
                  size: 18,
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          "OTP Verification",
          style: TextStyle(letterSpacing: 1),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            alignment: Alignment.topCenter,
            children: [
              if (!isKeyboardOpen)
                SizedBox(
                  height: SizeConfig.heightMultiplier! * 30,
                  child: const AuthRecentCarousel(),
                ),
              Align(
                alignment: isKeyboardOpen
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                child: ResponsiveCenter(
                  maxWidth: kFormMaxWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      isKeyboardOpen ? 0 : 30,
                    ),
                    child: Container(
                      height: isKeyboardOpen
                          ? constraints.maxHeight
                          : SizeConfig.heightMultiplier! * 42,
                      color: isKeyboardOpen
                          ? Theme.of(context).colorScheme.surface.withAlpha(180)
                          : Colors.transparent,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 24),
                                Obx(() {
                                  final isEmail =
                                      _authController
                                              .lastValidationMethod
                                              .value ==
                                          'email' &&
                                      _authController
                                          .lastEmail
                                          .value
                                          .isNotEmpty;
                                  return Text(
                                    isEmail
                                        ? "We have sent a one time verification\ncode to your email."
                                        : "We have sent a one time verification\ncode to your number.",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 16),
                                  );
                                }),
                                const SizedBox(height: 16),
                                Obx(() {
                                  final isEmail =
                                      _authController
                                              .lastValidationMethod
                                              .value ==
                                          'email' &&
                                      _authController
                                          .lastEmail
                                          .value
                                          .isNotEmpty;
                                  return Text(
                                    isEmail
                                        ? maskEmail(
                                            _authController.lastEmail.value,
                                          )
                                        : _authController.lastMobile.value,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  );
                                }),
                                SizedBox(
                                  height: SizeConfig.heightMultiplier! * 4,
                                ),
                                AutofillGroup(
                                  child: Theme(
                                    // PinCodeFields contains a transparent,
                                    // full-width TextFormField. Prevent it from
                                    // inheriting the app input border and drawing
                                    // a second outline around all six boxes.
                                    data: Theme.of(context).copyWith(
                                      inputDecorationTheme:
                                          const InputDecorationTheme(
                                            border: InputBorder.none,
                                            enabledBorder: InputBorder.none,
                                            focusedBorder: InputBorder.none,
                                            disabledBorder: InputBorder.none,
                                            errorBorder: InputBorder.none,
                                            focusedErrorBorder:
                                                InputBorder.none,
                                          ),
                                    ),
                                    child: PinCodeFields(
                                      length: 6,
                                      fieldBorderStyle: FieldBorderStyle.square,
                                      responsive: true,
                                      fieldHeight: math.min(
                                        SizeConfig.widthMultiplier! * 12,
                                        52,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      padding: EdgeInsets.zero,
                                      borderWidth: 1.0,
                                      activeBorderColor: primaryColor,
                                      activeBackgroundColor: Colors.transparent,
                                      borderRadius: BorderRadius.circular(12.0),
                                      keyboardType: TextInputType.number,
                                      autoHideKeyboard: true,
                                      fieldBackgroundColor: Colors.transparent,
                                      borderColor: Theme.of(
                                        context,
                                      ).colorScheme.outline,
                                      textStyle: const TextStyle(
                                        fontSize: 18.0,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      onChange: (value) => setState(() {
                                        _otp = value;
                                        if (value.length < 6) {
                                          _hasSubmittedOtp = false;
                                        }
                                      }),
                                      onComplete: _submitOtp,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: SizeConfig.heightMultiplier! * 4,
                                ),
                                GestureDetector(
                                  onTap: _authController.resendOtp,
                                  child: Text(
                                    "Resend Code",
                                    style: TextStyle(
                                      color: const Color(0xFF833737),
                                      fontWeight: FontWeight.bold,
                                      decorationColor: primaryColor,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: SizeConfig.heightMultiplier! * 4,
                                ),
                                Obx(
                                  () => CustomButton(
                                    text: _authController.isLoading.value
                                        ? "Please wait..."
                                        : "Verify",
                                    isEnabled:
                                        _otp.length == 6 &&
                                        !_authController.isLoading.value,
                                    onTap: () => _submitOtp(_otp),
                                  ),
                                ),
                                SizedBox(
                                  height: SizeConfig.heightMultiplier! * 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
