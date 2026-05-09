import 'package:flutter/cupertino.dart';
import 'package:harismruti/ui/view/home/album_smruti.dart';
import 'package:harismruti/ui/view/home/collection_smruti.dart';
import 'package:harismruti/ui/view/home/location_smruti.dart';
import 'package:harismruti/ui/view/home/people_smruti.dart';
import 'package:harismruti/ui/view/home/recent_smruti.dart';
import 'package:harismruti/ui/view/home/smruti_of.dart';
import 'package:harismruti/ui/view/home/smruti_with.dart';
import 'package:harismruti/ui/view/home/wallpaper_smruti.dart';

class AppText {
  static const recentSmruti = "Recent Smruti";
}

class SmrutiSectionKeys {
  static const recent = "Recent Smruti";
  static const withSmruti = "Smruti with";
  static const ofSmruti = "Smruti of";
  static const location = "Location";
  static const album = "Album";
  static const collections = "Collections";
  static const people = "People";
  static const wallpapers = "Wallpapers";
  static const pinnedCollection = "Pinned Collection";
}



final List<Map<String, dynamic>> photoAlbumList = [
  {
    'title': 'Surat',
    'subtitle': '12 Photos',
    'images': imageUrls,
  },
  {
    'title': 'Ahmedabad',
    'subtitle': '18 Photos',
    'images': imageUrls,
  }, {
    'title': 'Surat',
    'subtitle': '12 Photos',
    'images': imageUrls,
  },
  {
    'title': 'Ahmedabad',
    'subtitle': '18 Photos',
    'images': imageUrls,
  }, {
    'title': 'Surat',
    'subtitle': '12 Photos',
    'images': imageUrls,
  },
  {
    'title': 'Ahmedabad',
    'subtitle': '18 Photos',
    'images': imageUrls,
  }, {
    'title': 'Surat',
    'subtitle': '12 Photos',
    'images': imageUrls,
  },
  {
    'title': 'Ahmedabad',
    'subtitle': '18 Photos',
    'images': imageUrls,
  },
];

final List<Map<String, dynamic>> eventList = [
  {
    'title': 'Gurupurnima Utsav',
    'subtitle': '13th July 2025',
    'images': imageUrls, // define imageUrls globally as well
  },
  {
    'title': 'Sadbhavna Sabha',
    'subtitle': '15th August 2025',
    'images': imageUrls,
  },
];



final List<String> imageUrls = const [
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
  "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
];

