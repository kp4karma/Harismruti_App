import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:harismruti/utils/size_config.dart';
import 'package:parallax_cards/parallax_cards.dart';

class SmrutiWith extends StatelessWidget {
  final List<Map<String, String>> imageItems = [
    {
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      'title': 'Divine Moments',
      'subtitle': 'With P.P. Swamiji',
    },
    {
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      'title': 'Blessings',
      'subtitle': 'Spiritual Grace',
    },
    {
      'image': "https://assets.epuzzle.info//puzzle/145/264/original.jpg",
      'title': 'Harismruti',
      'subtitle': 'Peaceful Memories',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ParallaxCards(
      borderRadius: BorderRadius.circular(20),
      scrollDirection: Axis.horizontal,
      imagesList: imageItems.map((e) => e['image'].toString()).toList() ?? [],
      width: 250.h,
      height: 350.h,
      thumbVisibility: false,
      thickness: 0,margin: EdgeInsetsGeometry.symmetric(horizontal: 8),
      onTap: (index) {},
      overlays: [
        for (var item in imageItems)
        Stack(
          children: [
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  stops: [0.2, 0.4],
                  colors: [Colors.black.withAlpha(100), Colors.transparent],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    item['title']!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: SizeConfig.textMultiplier! * 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: SizeConfig.heightMultiplier! * 0.5),
                  Text(
                    item['subtitle']!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: SizeConfig.textMultiplier! * 1.7,
                    ),
                  ),
                  SizedBox(height: SizeConfig.heightMultiplier! * 1.5),
                ],
              ),
            ),
          ],
        ),
      ],
    );
    // return SizedBox(
    //   height: 250.h,
    //   child: ListView.builder(
    //     scrollDirection: Axis.horizontal,
    //     itemCount: imageItems.length,
    //     padding: EdgeInsets.symmetric(
    //       horizontal: SizeConfig.widthMultiplier! * 3,
    //     ),
    //     itemBuilder: (context, index) {
    //       final item = imageItems[index];
    //       return Container(
    //         width: 250.h,
    //         margin: EdgeInsets.only(right: SizeConfig.widthMultiplier! * 2),
    //         decoration: BoxDecoration(
    //           borderRadius: BorderRadius.circular(20),
    //           image: DecorationImage(
    //             image: NetworkImage(item['image']!),
    //             fit: BoxFit.cover,
    //           ),
    //         ),
    //         child: Stack(
    //           children: [
    //             // Gradient overlay
    //             Container(
    //               decoration: BoxDecoration(
    //                 borderRadius: BorderRadius.circular(20),
    //                 gradient: LinearGradient(
    //                   begin: Alignment.bottomCenter,
    //                   end: Alignment.topCenter,
    //                   stops: [0.2, 0.4],
    //                   colors: [Colors.black.withAlpha(100), Colors.transparent],
    //                 ),
    //               ),
    //             ),
    //             Center(
    //               child: Column(
    //                 mainAxisAlignment: MainAxisAlignment.end,
    //                 children: [
    //                   Text(
    //                     item['title']!,
    //                     style: TextStyle(
    //                       color: Colors.white,
    //                       fontSize: SizeConfig.textMultiplier! * 2,
    //                       fontWeight: FontWeight.bold,
    //                     ),
    //                   ),
    //                   SizedBox(height: SizeConfig.heightMultiplier! * 0.5),
    //                   Text(
    //                     item['subtitle']!,
    //                     style: TextStyle(
    //                       color: Colors.white,
    //                       fontSize: SizeConfig.textMultiplier! * 1.7,
    //                     ),
    //                   ),
    //                   SizedBox(height: SizeConfig.heightMultiplier! * 1.5),
    //                 ],
    //               ),
    //             ),
    //           ],
    //         ),
    //       );
    //     },
    //   ),
    // );
  }
}
