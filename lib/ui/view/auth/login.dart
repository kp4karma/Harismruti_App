import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:harismruti/ui/controller/auth_controller.dart';
import 'package:harismruti/ui/view/auth/otp_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/size_config.dart';
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
  String _countryCode = '+91';
  String _validationMethod = 'email';
  bool _hasShownWhatsappOtpAlert = false;

  bool get _canSubmit {
    return _mobileController.text.trim().isNotEmpty &&
        !_authController.isLoading.value;
  }

  @override
  void initState() {
    super.initState();
    _mobileController.addListener(_refreshForm);
  }

  void _refreshForm() => setState(() {});

  @override
  void dispose() {
    _mobileController.removeListener(_refreshForm);
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
                                _CountryCodeButton(
                                  country: _selectedCountry,
                                  onTap: _showCountryCodeSheet,
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
                                    setState(() => _validationMethod = method);
                                    return;
                                  }
                                  setState(() => _validationMethod = method);
                                },
                              ),
                            ),
                            SizedBox(height: SizeConfig.heightMultiplier! * 4),
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
                                  Navigator.push(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (context) => const OTPScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            SizedBox(height: SizeConfig.heightMultiplier! * 4),
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
          ],
        ),
      ),
    );
  }

  _CountryCode get _selectedCountry {
    return _countryCodes.firstWhere(
      (country) => country.dialCode == _countryCode,
      orElse: () => _countryCodes.first,
    );
  }

  Future<void> _showCountryCodeSheet() async {
    final selected = await showModalBottomSheet<_CountryCode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CountryCodeSheet(selectedCode: _countryCode),
    );
    if (selected == null) return;
    setState(() => _countryCode = selected.dialCode);
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

class _CountryCode {
  final String name;
  final String dialCode;
  final String flag;

  const _CountryCode({
    required this.name,
    required this.dialCode,
    required this.flag,
  });
}

const List<_CountryCode> _countryCodes = [
  _CountryCode(name: 'India', dialCode: '+91', flag: 'IN'),
  _CountryCode(name: 'United States', dialCode: '+1', flag: 'US'),
  _CountryCode(name: 'United Kingdom', dialCode: '+44', flag: 'GB'),
  _CountryCode(name: 'Canada', dialCode: '+1', flag: 'CA'),
  _CountryCode(name: 'Australia', dialCode: '+61', flag: 'AU'),
  _CountryCode(name: 'United Arab Emirates', dialCode: '+971', flag: 'AE'),
  _CountryCode(name: 'Singapore', dialCode: '+65', flag: 'SG'),
  _CountryCode(name: 'New Zealand', dialCode: '+64', flag: 'NZ'),
  _CountryCode(name: 'South Africa', dialCode: '+27', flag: 'ZA'),
  _CountryCode(name: 'Kenya', dialCode: '+254', flag: 'KE'),
];

class _CountryCodeButton extends StatelessWidget {
  final _CountryCode country;
  final VoidCallback onTap;

  const _CountryCodeButton({required this.country, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(230),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withAlpha(18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              country.flag,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            Text(
              country.dialCode,
              style: const TextStyle(
                color: Color(0xFF322318),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            Icon(CupertinoIcons.chevron_down, size: 15, color: primaryColor),
          ],
        ),
      ),
    );
  }
}

class _CountryCodeSheet extends StatefulWidget {
  final String selectedCode;

  const _CountryCodeSheet({required this.selectedCode});

  @override
  State<_CountryCodeSheet> createState() => _CountryCodeSheetState();
}

class _CountryCodeSheetState extends State<_CountryCodeSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countries = _countryCodes.where((country) {
      if (_query.isEmpty) return true;
      return '${country.name} ${country.dialCode} ${country.flag}'
          .toLowerCase()
          .contains(_query);
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6F3).withAlpha(246),
              border: Border(
                top: BorderSide(color: primaryColor.withAlpha(18)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(35),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Country Code',
                            style: TextStyle(
                              color: Color(0xFF322318),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(220),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CupertinoIcons.xmark,
                              color: primaryColor,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search country or code',
                        prefixIcon: Icon(
                          CupertinoIcons.search,
                          color: primaryColor,
                        ),
                        filled: true,
                        fillColor: Colors.white.withAlpha(230),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                      itemCount: countries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final country = countries[index];
                        final isSelected =
                            country.dialCode == widget.selectedCode;
                        return _CountryCodeTile(
                          country: country,
                          isSelected: isSelected,
                          onTap: () => Navigator.pop(context, country),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryCodeTile extends StatelessWidget {
  final _CountryCode country;
  final bool isSelected;
  final VoidCallback onTap;

  const _CountryCodeTile({
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withAlpha(28)
              : Colors.white.withAlpha(230),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor.withAlpha(90) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: primaryColor.withAlpha(16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                country.flag,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                country.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF322318),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              country.dialCode,
              style: TextStyle(
                color: primaryColor,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isSelected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: primaryColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
