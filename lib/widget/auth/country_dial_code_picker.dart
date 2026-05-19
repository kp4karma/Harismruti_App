import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/utils/app_color.dart';

class CountryDialCodePicker extends StatelessWidget {
  final String countryCode;
  final ValueChanged<String> onChanged;

  const CountryDialCodePicker({
    super.key,
    required this.countryCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withAlpha(18)),
      ),
      child: CountryCodePicker(
        pickerStyle: PickerStyle.bottomSheet,
        onChanged: (country) {
          final dialCode = country.dialCode;
          if (dialCode == null || dialCode.isEmpty) return;
          onChanged(dialCode);
        },
        initialSelection: countryCode,
        favorite: const ['IN', '+91'],
        showCountryOnly: false,
        showOnlyCountryWhenClosed: false,
        showFlag: true,
        showFlagDialog: true,
        showDropDownButton: true,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        flagWidth: 24,
        textStyle: const TextStyle(
          color: Color(0xFF322318),
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
        dialogTextStyle: const TextStyle(
          color: Color(0xFF322318),
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        searchDecoration: InputDecoration(
          hintText: 'Search country or code',
          prefixIcon: Icon(CupertinoIcons.search, color: primaryColor),
          filled: true,
          fillColor: Colors.white.withAlpha(230),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        backgroundColor: Colors.transparent,
        dialogBackgroundColor: const Color(0xFFF8F6F3),
        barrierColor: Colors.black.withAlpha(80),
        boxDecoration: BoxDecoration(
          color: const Color(0xFFF8F6F3),
          borderRadius: BorderRadius.circular(22),
        ),
        dialogSize: Size(
          MediaQuery.of(context).size.width * 0.9,
          MediaQuery.of(context).size.height * 0.72,
        ),
      ),
    );
  }
}
