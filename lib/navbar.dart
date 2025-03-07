import 'package:flutter/material.dart';

class NavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isHindi;
  final ValueChanged<bool> onToggleLanguage;

  const NavBar({
    Key? key,
    required this.title,
    required this.isHindi,
    required this.onToggleLanguage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: [
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Text('EN'),
            ),
            Switch(
              value: isHindi,
              onChanged: onToggleLanguage,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.0),
              child: Text('हिंदी'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
