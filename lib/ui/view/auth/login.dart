import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/auth_controller.dart';
import 'package:harismruti/ui/view/auth/otp_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/responsive.dart';
import 'package:harismruti/utils/size_config.dart';
import 'package:harismruti/utils/storage_helper.dart';
import 'package:harismruti/widget/auth/country_dial_code_picker.dart';
import 'package:harismruti/widget/buttons/custom_button.dart';
import 'package:harismruti/widget/carousel/auth_recent_carousel.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _authController = Get.find<AuthController>();
  final TextEditingController _mobileController = TextEditingController();
  final FocusNode _mobileFocusNode = FocusNode();
  String _countryCode = '+91';
  String _validationMethod = 'email';
  bool _hasShownWhatsappOtpAlert = false;
  bool _showMobileError = false;

  bool get _canSubmit {
    return _mobileController.text.trim().isNotEmpty &&
        !_authController.isLoading.value;
  }

  @override
  void initState() {
    super.initState();
    final savedCountryCode = StorageHelper.getValue<String>(
      key: StorageKeys.lastMobileCountryCode,
    );
    if (savedCountryCode != null && savedCountryCode.isNotEmpty) {
      _countryCode = savedCountryCode;
    }
    _mobileController.addListener(_refreshForm);
    _mobileFocusNode.addListener(_handleMobileFocusChange);
  }

  void _refreshForm() => setState(() {});

  void _handleMobileFocusChange() {
    if (_mobileFocusNode.hasFocus) {
      if (_showMobileError) setState(() => _showMobileError = false);
      return;
    }
    final isEmpty = _mobileController.text.trim().isEmpty;
    if (isEmpty != _showMobileError) {
      setState(() => _showMobileError = isEmpty);
    }
  }

  @override
  void dispose() {
    _mobileController.removeListener(_refreshForm);
    _mobileController.dispose();
    _mobileFocusNode.removeListener(_handleMobileFocusChange);
    _mobileFocusNode.dispose();
    super.dispose();
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
        title: const Text("Sign In", style: TextStyle(letterSpacing: 1)),
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
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  CountryDialCodePicker(
                                    countryCode: _countryCode,
                                    onChanged: (dialCode) =>
                                        setState(() => _countryCode = dialCode),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          kPhoneInputRadius,
                                        ),
                                        boxShadow: kPhoneInputShadow,
                                      ),
                                      child: Container(
                                        height: kPhoneInputHeight,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: kPhoneInputFill,
                                          borderRadius: BorderRadius.circular(
                                            kPhoneInputRadius,
                                          ),
                                          border: Border.all(
                                            color: _showMobileError
                                                ? const Color(0xFFC62828)
                                                : _mobileFocusNode.hasFocus
                                                ? primaryColor
                                                : kPhoneInputBorder,
                                            width: _mobileFocusNode.hasFocus
                                                ? 1.6
                                                : 1,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _mobileController,
                                          focusNode: _mobileFocusNode,
                                          keyboardType: TextInputType.phone,
                                          style: const TextStyle(
                                            color: Color(0xFF322318),
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isCollapsed: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (_showMobileError) ...[
                                const SizedBox(height: 6),
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Mobile number is required',
                                      style: TextStyle(
                                        color: Color(0xFFC62828),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Verification Method",
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'email',
                                      label: Text('Email'),
                                    ),
                                    ButtonSegment(
                                      value: 'whatsapp',
                                      label: Text('Whatsapp'),
                                    ),
                                  ],
                                  selected: {_validationMethod},
                                  onSelectionChanged: (selected) {
                                    final method = selected.first;
                                    if (method == 'whatsapp') {
                                      if (!_hasShownWhatsappOtpAlert) {
                                        _hasShownWhatsappOtpAlert = true;
                                        _showWhatsappOtpAlert();
                                        return;
                                      }
                                      setState(
                                        () => _validationMethod = method,
                                      );
                                      return;
                                    }
                                    setState(() => _validationMethod = method);
                                  },
                                ),
                              ),
                              SizedBox(
                                height: SizeConfig.heightMultiplier! * 4,
                              ),
                              Obx(
                                () => CustomButton(
                                  text: _authController.isLoading.value
                                      ? "Please wait..."
                                      : "Sign In",
                                  isEnabled: _canSubmit,
                                  onTap: () async {
                                    final sent = await _authController.login(
                                      mobile:
                                          '$_countryCode${_mobileController.text}',
                                      validationMethod: _validationMethod,
                                    );
                                    if (!context.mounted || !sent) return;
                                    StorageHelper.setValue(
                                      key: StorageKeys.lastMobileNumber,
                                      value: _mobileController.text.trim(),
                                    );
                                    StorageHelper.setValue(
                                      key: StorageKeys.lastMobileCountryCode,
                                      value: _countryCode,
                                    );
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(
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
                                  const Text("Don't have an account? "),
                                  GestureDetector(
                                    onTap: () => Get.toNamed('/register'),
                                    child: Text(
                                      "Register",
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

  void _showWhatsappOtpAlert() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Use Email OTP'),
          content: const Text(
            'WhatsApp OTP is chargeable for us.\nPlease choose Email OTP.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
