import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:harismruti/utils/app_color.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class ImagePickerHelper {
  static Future<void> showPickerSheet({
    required BuildContext context,
    required Color themeColor,
    required bool allowMultiple,
    required bool enableCrop,
    CropStyle cropStyle = CropStyle.rectangle,
    required Function(List<String> filePaths) onImagesPicked,
  }) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: Icon(CupertinoIcons.camera, color: themeColor),
            title: const Text("Camera"),
            onTap: () async {
              Navigator.pop(context);
              final result = await _pickImage(
                ImageSource.camera,
                allowMultiple,
                enableCrop,
                cropStyle,
              );
              if (result.isNotEmpty) onImagesPicked(result);
            },
          ),
          ListTile(
            leading: Icon(CupertinoIcons.photo_on_rectangle, color: themeColor),
            title: const Text("Gallery"),
            onTap: () async {
              Navigator.pop(context);
              final result = await _pickImage(
                ImageSource.gallery,
                allowMultiple,
                enableCrop,
                cropStyle,
              );
              if (result.isNotEmpty) onImagesPicked(result);
            },
          ),
        ],
      ),
    );
  }

  static Future<List<String>> pickGalleryImages({
    required bool allowMultiple,
    required bool enableCrop,
    CropStyle cropStyle = CropStyle.rectangle,
  }) {
    return _pickImage(
      ImageSource.gallery,
      allowMultiple,
      enableCrop,
      cropStyle,
    );
  }

  static Future<List<String>> _pickImage(
    ImageSource source,
    bool allowMultiple,
    bool enableCrop,
    CropStyle cropStyle,
  ) async {
    final picker = ImagePicker();
    final List<String> pickedPaths = [];

    if (allowMultiple && source == ImageSource.gallery) {
      final pickedFiles = await picker.pickMultiImage(imageQuality: 85);
      for (var file in pickedFiles) {
        final path = await _cropIfNeeded(file.path, enableCrop, cropStyle);
        if (path != null) pickedPaths.add(path);
      }
    } else {
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final path = await _cropIfNeeded(
          pickedFile.path,
          enableCrop,
          cropStyle,
        );
        if (path != null) pickedPaths.add(path);
      }
    }

    return pickedPaths;
  }

  static Future<String?> _cropIfNeeded(
    String path,
    bool enableCrop,
    CropStyle cropStyle,
  ) async {
    if (!enableCrop) return path;

    final croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: primaryColor,
          toolbarWidgetColor: Colors.white,
          cropStyle: cropStyle,
        ),
        IOSUiSettings(title: 'Crop Image', cropStyle: cropStyle),
      ],
    );
    return croppedFile?.path;
  }
}
