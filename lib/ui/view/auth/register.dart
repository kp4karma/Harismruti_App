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
                                _RegisterCountryCodeButton(
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
                            SizedBox(height: SizeConfig.heightMultiplier! * 4),
                            Obx(
                              () => CustomButton(
                                text: _authController.isLoading.value
                                    ? "Please wait..."
                                    : "Register",
                                isEnabled: _canSubmit,
                                onTap: () async {
                                  final registered = await _authController.register(
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
          ],
        ),
      ),
    );
  }

  _RegisterCountryCode get _selectedCountry {
    return _registerCountryCodes.firstWhere(
      (country) => country.dialCode == _countryCode,
      orElse: () => _registerCountryCodes.first,
    );
  }

  Future<void> _showCountryCodeSheet() async {
    final selected = await showModalBottomSheet<_RegisterCountryCode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _RegisterCountryCodeSheet(selectedCode: _countryCode),
    );
    if (selected == null) return;
    setState(() => _countryCode = selected.dialCode);
  }
}

class _RegisterCountryCode {
  final String name;
  final String dialCode;
  final String flag;

  const _RegisterCountryCode({
    required this.name,
    required this.dialCode,
    required this.flag,
  });
}

const List<_RegisterCountryCode> _registerCountryCodes = [
  _RegisterCountryCode(name: 'India', dialCode: '+91', flag: 'IN'),
  _RegisterCountryCode(name: 'United States', dialCode: '+1', flag: 'US'),
  _RegisterCountryCode(name: 'United Kingdom', dialCode: '+44', flag: 'GB'),
  _RegisterCountryCode(name: 'Canada', dialCode: '+1', flag: 'CA'),
  _RegisterCountryCode(name: 'Australia', dialCode: '+61', flag: 'AU'),
  _RegisterCountryCode(
    name: 'United Arab Emirates',
    dialCode: '+971',
    flag: 'AE',
  ),
  _RegisterCountryCode(name: 'Singapore', dialCode: '+65', flag: 'SG'),
  _RegisterCountryCode(name: 'New Zealand', dialCode: '+64', flag: 'NZ'),
  _RegisterCountryCode(name: 'South Africa', dialCode: '+27', flag: 'ZA'),
  _RegisterCountryCode(name: 'Kenya', dialCode: '+254', flag: 'KE'),
];

class _RegisterCountryCodeButton extends StatelessWidget {
  final _RegisterCountryCode country;
  final VoidCallback onTap;

  const _RegisterCountryCodeButton({
    required this.country,
    required this.onTap,
  });

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

class _RegisterCountryCodeSheet extends StatefulWidget {
  final String selectedCode;

  const _RegisterCountryCodeSheet({required this.selectedCode});

  @override
  State<_RegisterCountryCodeSheet> createState() =>
      _RegisterCountryCodeSheetState();
}

class _RegisterCountryCodeSheetState extends State<_RegisterCountryCodeSheet> {
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
    final countries = _registerCountryCodes.where((country) {
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
                        return _RegisterCountryCodeTile(
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

class _RegisterCountryCodeTile extends StatelessWidget {
  final _RegisterCountryCode country;
  final bool isSelected;
  final VoidCallback onTap;

  const _RegisterCountryCodeTile({
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
