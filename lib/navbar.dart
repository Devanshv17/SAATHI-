import 'package:flutter/material.dart';

class NavBar extends StatelessWidget implements PreferredSizeWidget {
 
  final bool isHindi;
  final ValueChanged<bool> onToggleLanguage;
  final bool showMenuButton; // show the drawer menu icon

  const NavBar({
    Key? key,
    required this.isHindi,
    required this.onToggleLanguage,
    this.showMenuButton = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // If the drawer menu is enabled, show it; otherwise no leading icon.
      leading: showMenuButton
          ? IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            )
          : null,
      backgroundColor: const Color.fromARGB(255, 112, 60, 254),
      elevation: 1,
      // Title row: logo + text
      title: Row(
        children: [
          Image.asset(
            'logo.png',
            height: 24,
          ),
          const SizedBox(width: 8),
          Text(
            isHindi ? 'साथी' : 'SAATHI',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      centerTitle: false,
      // Language toggle stays on the right
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              Text(
                'EN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isHindi ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              Switch(
                value: isHindi,
                onChanged: onToggleLanguage,
                activeColor: const Color.fromARGB(255, 6, 23, 0),
              ),
              Text(
                'हिंदी',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isHindi ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
