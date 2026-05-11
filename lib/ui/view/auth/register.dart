import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:harismruti/utils/size_config.dart';
import 'package:harismruti/widget/buttons/custom_button.dart';
import 'package:harismruti/widget/carousel/auto_scroll_carousel.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

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
        title: Text("Register", style: TextStyle(letterSpacing: 1)),
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
                            const TextField(
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                              ),
                            ),
                            const SizedBox(height: 12),
                            const TextField(
                              decoration: InputDecoration(labelText: 'Email'),
                            ),
                            const SizedBox(height: 12),
                            const TextField(
                              decoration: InputDecoration(
                                labelText: 'Location',
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Verification Method",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: RadioListTile(
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    title: const Text("Whatsapp"),
                                    value: "whatsapp",
                                    groupValue: "whatsapp",
                                    onChanged: (_) {},
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile(
                                    contentPadding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    title: const Text("Email"),
                                    value: "email",
                                    groupValue: "whatsapp",
                                    onChanged: (_) {},
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                DropdownButton<String>(
                                  value: '+91',
                                  items: ['+91', '+1', '+44']
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) {},
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: TextField(
                                    keyboardType: TextInputType.phone,
                                    decoration: InputDecoration(
                                      hintText: '98540 02451',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: SizeConfig.heightMultiplier! * 4),
                            CustomButton(text: "Register", onTap: () {}),
                            SizedBox(height: SizeConfig.heightMultiplier! * 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("Already have an account? "),
                                GestureDetector(
                                  onTap: () {
                                    // Navigate to Sign In
                                  },
                                  child: Text(
                                    "Sign In",
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
