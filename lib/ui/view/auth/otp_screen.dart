import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/ui/view/Auth/otp_screen.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/size_config.dart';
import 'package:harismruti/widget/buttons/custom_button.dart';
import 'package:harismruti/widget/carousel/auto_scroll_carousel.dart';
import 'package:flutter_pin_code_fields/flutter_pin_code_fields.dart';
class OTPScreen extends StatelessWidget {
  const OTPScreen({super.key});

  final List<String> imageUrls = const [
    "https://assets.epuzzle.info/puzzle/145/264/original.jpg",
    "https://assets.epuzzle.info/puzzle/145/264/original.jpg",
    "https://assets.epuzzle.info/puzzle/145/264/original.jpg",
    "https://assets.epuzzle.info/puzzle/145/264/original.jpg",
    "https://assets.epuzzle.info/puzzle/145/264/original.jpg",
    "https://assets.epuzzle.info/puzzle/145/264/original.jpg",
  ];

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

                  child: Padding(
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
        title: Text("OTP Verification", style: TextStyle(letterSpacing: 1)),
      ),
      backgroundColor: Color(0xFFF5F5F5),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Background Swami images
            SizedBox(
              height: SizeConfig.heightMultiplier! * 30,
              child: AutoScrollCarousel(imageUrls: imageUrls),
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "We have sent a one time verification\ncode to your number.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "+91 6352411412",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold,color: primaryColor),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: SizeConfig.heightMultiplier! * 4),

                            PinCodeFields(
                              length: 6,
                              fieldBorderStyle: FieldBorderStyle.square,
                              responsive: true,
                              fieldHeight: SizeConfig.widthMultiplier! * 12,
                              // fieldWidth:  SizeConfig.widthMultiplier! * 10,
                              borderWidth: 1.0,

                              activeBorderColor: primaryColor,
                              activeBackgroundColor: Colors.transparent,
                              borderRadius: BorderRadius.circular(12.0),
                              keyboardType: TextInputType.number,
                              autoHideKeyboard: true,
                              fieldBackgroundColor: Colors.transparent,
                              borderColor: Colors.grey,
                              textStyle: TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                              ),

                              onComplete: (output) {
                                // Your logic with pin code
                                print(output);
                              },
                            ),
                            SizedBox(height: SizeConfig.heightMultiplier! * 4),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () {

                                  },
                                  child: Text(
                                    "Resend Code",
                                    style: TextStyle(
                                      color: Color(0xFF833737),
                                      fontWeight: FontWeight.bold,
                                      decorationColor: primaryColor,

                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: SizeConfig.heightMultiplier! * 4),
                            CustomButton(
                              text: "Verify",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => OTPScreen(),
                                  ),
                                );
                              },
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
