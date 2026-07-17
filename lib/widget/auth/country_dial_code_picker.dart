import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/utils/app_color.dart';

/// Shared visual style for the country code selector and the mobile number
/// field beside it, so together they read as one phone-number input.
const double kPhoneInputHeight = 54;
const double kPhoneInputRadius = 16;
const Color kPhoneInputFill = Colors.white;
final Color kPhoneInputBorder = primaryColor.withAlpha(18);
final List<BoxShadow> kPhoneInputShadow = [
  BoxShadow(
    color: Colors.black.withAlpha(14),
    blurRadius: 14,
    offset: const Offset(0, 5),
  ),
];

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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kPhoneInputRadius),
        boxShadow: kPhoneInputShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(kPhoneInputRadius),
        child: Container(
          height: kPhoneInputHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: kPhoneInputFill,
            borderRadius: BorderRadius.circular(kPhoneInputRadius),
            border: Border.all(color: kPhoneInputBorder),
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
            showFlagDialog: true,
            flagWidth: 22,
            builder: (country) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (country?.flagUri != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.asset(
                        country!.flagUri!,
                        package: 'country_code_picker',
                        width: 22,
                        height: 16,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 7),
                  Text(
                    country?.dialCode ?? countryCode,
                    style: const TextStyle(
                      color: Color(0xFF322318),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 13,
                    color: primaryColor.withAlpha(200),
                  ),
                ],
              ),
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
        ),
      ),
    );
  }
}
