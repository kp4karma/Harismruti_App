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

class CountryDialCodePicker extends StatefulWidget {
  final String countryCode;
  final ValueChanged<String> onChanged;

  const CountryDialCodePicker({
    super.key,
    required this.countryCode,
    required this.onChanged,
  });

  @override
  State<CountryDialCodePicker> createState() => _CountryDialCodePickerState();
}

class _CountryDialCodePickerState extends State<CountryDialCodePicker> {
  late String _selectedCountry;
  late String _selectedDialCode;

  @override
  void initState() {
    super.initState();
    _selectedDialCode = widget.countryCode;
    _selectedCountry = _selectionFor(widget.countryCode);
  }

  @override
  void didUpdateWidget(covariant CountryDialCodePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.countryCode != _selectedDialCode) {
      _selectedDialCode = widget.countryCode;
      _selectedCountry = _selectionFor(widget.countryCode);
    }
  }

  String _selectionFor(String value) {
    // USA and Canada share +1. Use USA when restoring a dial-code-only value;
    // an explicit ISO selection is retained in _selectedCountry while mounted.
    return value == '+1' ? 'US' : value;
  }

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
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(kPhoneInputRadius),
            border: Border.all(color: kPhoneInputBorder),
          ),
          child: CountryCodePicker(
            pickerStyle: PickerStyle.bottomSheet,
            onChanged: (country) {
              final dialCode = country.dialCode;
              if (dialCode == null || dialCode.isEmpty) return;
              setState(() {
                _selectedDialCode = dialCode;
                _selectedCountry = country.code ?? dialCode;
              });
              widget.onChanged(dialCode);
            },
            initialSelection: _selectedCountry,
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
                    country?.dialCode ?? widget.countryCode,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
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
            dialogTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            searchDecoration: InputDecoration(
              hintText: 'Search country or code',
              prefixIcon: Icon(CupertinoIcons.search, color: primaryColor),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            backgroundColor: Colors.transparent,
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
            barrierColor: Colors.black.withAlpha(80),
            boxDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
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
