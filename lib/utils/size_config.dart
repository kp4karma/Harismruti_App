import 'package:flutter/material.dart';

class SizeConfig {
  static double? _screenWidth;
  static double? _screenHeight;
  static double _blockWidth = 0;
  static double _blockHeight = 0;
  static double? textMultiplier;
  static double? imageSizeMultiplier;
  static double? heightMultiplier;
  static double? widthMultiplier;
  static bool isPortrait = true;
  static bool isTablet = false;
  static bool isMobilePortrait = false;

  Future<void> init(BoxConstraints constraints, Orientation orientation) async {
    if (orientation == Orientation.portrait) {
      _screenWidth = constraints.maxWidth;
      _screenHeight = constraints.maxHeight;
      isPortrait = true;
      if (_screenWidth! < 450) {
        isMobilePortrait = true;
        isTablet = false;
      } else if (_screenWidth! >= 800) {
        isTablet = true;

        isMobilePortrait = false;
      }
    } else {
      _screenWidth = constraints.maxHeight;
      _screenHeight = constraints.maxWidth;
      isPortrait = false;
      isMobilePortrait = false;
    }

    _blockWidth = _screenWidth! / 100;
    _blockHeight = _screenHeight! / 100;

    textMultiplier = _blockHeight;
    imageSizeMultiplier = _blockWidth;
    heightMultiplier = _blockHeight;
    widthMultiplier = _blockWidth;
  }
}

double getProportionateScreenHeight(double inputHeight) {
  double screenHeight = SizeConfig._screenHeight!;
  return (inputHeight / 812.0) * screenHeight;
}

double getProportionateScreenWidth(double inputWidth) {
  double screenWidth = SizeConfig._screenWidth!;
  return (inputWidth / 375.0) * screenWidth;
}
