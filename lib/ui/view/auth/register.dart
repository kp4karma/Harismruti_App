import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/auth_controller.dart';
import 'package:harismruti/ui/view/auth/otp_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/utils/size_config.dart';
import 'package:harismruti/widget/auth/country_dial_code_picker.dart';
import 'package:harismruti/widget/buttons/custom_button.dart';
import 'package:harismruti/widget/carousel/auth_recent_carousel.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  String _countryCode = '+91';
  final String _validationMethod = 'whatsapp';

  bool get _canSubmit {
    return _nameController.text.trim().isNotEmpty &&
        _isValidEmail(_emailController.text) &&
        _mobileController.text.trim().isNotEmpty &&
        !_authController.isLoading.value;
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(email.trim());
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_refreshForm);
    _emailController.addListener(_refreshForm);
    _mobileController.addListener(_refreshForm);
  }

  void _refreshForm() => setState(() {});

  @override
  void dispose() {
    _nameController.removeListener(_refreshForm);
    _emailController.removeListener(_refreshForm);
    _mobileController.removeListener(_refreshForm);
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        leadingWidth: SizeConfig.widthMultiplier! * 16,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
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
              ],
            ),
          ),
        ),
        title: const Text("Register", style: TextStyle(letterSpacing: 1)),
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
              child: ResponsiveCenter(
                maxWidth: kFormMaxWidth,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isKeyboardOpen ? 0 : 30),
                  child: Container(
                    color: isKeyboardOpen ? Colors.white60 : Colors.transparent,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        height: SizeConfig.heightMultiplier! * 60,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _cityController,
                                decoration: const InputDecoration(
                                  labelText: 'Location (Optional)',
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  CountryDialCodePicker(
                                    countryCode: _countryCode,
                                    onChanged: (dialCode) =>
                                        setState(() => _countryCode = dialCode),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _mobileController,
                                      keyboardType: TextInputType.phone,
                                      decoration: const InputDecoration(
                                        hintText: '98540 02451',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withAlpha(22),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: primaryColor.withAlpha(42),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      CupertinoIcons.chat_bubble_2_fill,
                                      color: primaryColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    const Expanded(
                                      child: Text(
                                        'OTP will be sent on WhatsApp',
                                        style: TextStyle(
                                          color: Color(0xFF322318),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      CupertinoIcons.checkmark_circle_fill,
                                      color: primaryColor,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: SizeConfig.heightMultiplier! * 4,
                              ),
                              Obx(
                                () => CustomButton(
                                  text: _authController.isLoading.value
                                      ? "Please wait..."
                                      : "Register",
                                  isEnabled: _canSubmit,
                                  onTap: () async {
                                    final registered = await _authController
                                        .register(
                                          fullName: _nameController.text,
                                          mobile:
                                              '$_countryCode${_mobileController.text}',
                                          city: _cityController.text,
                                          validationMethod: _validationMethod,
                                          email: _emailController.text,
                                        );
                                    if (!context.mounted || !registered) return;
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        settings: const RouteSettings(
                                          name: 'OTP Verification',
                                        ),
                                        builder: (context) => const OTPScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              SizedBox(
                                height: SizeConfig.heightMultiplier! * 4,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Already have an account? "),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Text(
                                      "Sign In",
                                      style: TextStyle(
                                        color: const Color(0xFF833737),
                                        fontWeight: FontWeight.bold,
                                        decorationColor: primaryColor,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
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
    );
  }
}
