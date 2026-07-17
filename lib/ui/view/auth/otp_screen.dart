import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pin_code_fields/flutter_pin_code_fields.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/auth_controller.dart';
import 'package:harismruti/utils/app_color.dart';
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
              decoration: const BoxDecoration(
                color: Colors.white,
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
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            SizedBox(
              height: SizeConfig.heightMultiplier! * 30,
              child: const AuthRecentCarousel(),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(isKeyboardOpen ? 0 : 30),
                child: Container(
                  height: SizeConfig.heightMultiplier! * 60,
                  color: isKeyboardOpen ? Colors.white60 : Colors.transparent,
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
                            const Text(
                              "We have sent a one time verification\ncode to your number.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            Obx(
                              () => Text(
                                _authController.lastMobile.value,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            SizedBox(height: SizeConfig.heightMultiplier! * 4),
                            AutofillGroup(
                              child: PinCodeFields(
                                length: 6,
                                fieldBorderStyle: FieldBorderStyle.square,
                                responsive: true,
                                fieldHeight: SizeConfig.widthMultiplier! * 12,
                                borderWidth: 1.0,
                                activeBorderColor: primaryColor,
                                activeBackgroundColor: Colors.transparent,
                                borderRadius: BorderRadius.circular(12.0),
                                keyboardType: TextInputType.number,
                                autoHideKeyboard: true,
                                fieldBackgroundColor: Colors.transparent,
                                borderColor: Colors.grey,
                                textStyle: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                                onComplete: _submitOtp,
                              ),
                            ),
                            SizedBox(height: SizeConfig.heightMultiplier! * 4),
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
                            SizedBox(height: SizeConfig.heightMultiplier! * 4),
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
                            SizedBox(height: SizeConfig.heightMultiplier! * 4),
                          ],
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
    );
  }
}
