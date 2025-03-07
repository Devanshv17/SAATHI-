import 'package:flutter/material.dart';

class NavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isHindi;
  final ValueChanged<bool> onToggleLanguage;
  final bool showMenuButton; // Show menu button only if user is logged in

  const NavBar({
    Key? key,
    required this.title,
    required this.isHindi,
    required this.onToggleLanguage,
    this.showMenuButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Display hamburger menu if showMenuButton is true
      leading: showMenuButton
          ? Builder(
        builder: (context) {
          return IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              // Open left-side drawer
              Scaffold.of(context).openDrawer();
            },
          );
        },
      )
          : null,
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
