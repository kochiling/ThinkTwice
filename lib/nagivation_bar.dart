import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:thinktwice/fetch_data.dart';
import 'package:thinktwice/home_page.dart';
import 'package:thinktwice/insert_page.dart';
import 'package:thinktwice/profile_page.dart';
import 'package:thinktwice/group_page.dart';

class CurveBar extends StatefulWidget {
  const CurveBar({super.key});

  @override
  State<CurveBar> createState() => _CurveBarState();
}

class _CurveBarState extends State<CurveBar> {
  int index = 0;
  final screen = const [
    HomePage(),
    GroupPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final items = [
      const Icon(Icons.home, size: 30),
      const Icon(Icons.monetization_on_outlined, size: 30),
      const Icon(Icons.person, size: 30),
    ];
    return Scaffold(
      //backgroundColor: Colors.transparent,
      extendBody: true,
      body: screen[index],
      // Center(
      //   child: Text(
      //     '$index',
      //     style: const TextStyle(
      //         fontSize: 110, fontWeight: FontWeight.bold, color: Colors.white),
      //   ),
      // ),
      bottomNavigationBar: Theme(
        // this them is for to change icon colors.
        data: Theme.of(context).copyWith(
            iconTheme: const IconThemeData(
              color: Colors.white,
            )),
        child: CurvedNavigationBar(
          // navigationBar colors
          color: Color(0xFFE991AA),
          //selected times colors
          buttonBackgroundColor: const Color (0xFFF4D0F2),
          backgroundColor: Colors.transparent,
          items: items,
          height: 60,
          index: index,
          onTap: (index) => setState(
                () => this.index = index,
          ),
        ),
      ),
    );
  }
}