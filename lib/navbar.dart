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
              padding: EdgeInsets.only(left: 11.0),
              iconSize: 50.0,
              color: Color.fromARGB(255, 239, 255, 245),
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            )
          : null,
      backgroundColor: const Color.fromARGB(255, 101, 65, 239
      ),
      elevation: 1,
      // Title row: logo + text
      title: Row(
        children: [
          Image.asset(
            'assets/logo.png',
            height: 40,
          ),
          const SizedBox(width: 10),
          Text(
            isHindi ? 'साथी' : 'Saathi',
            style: const TextStyle(
              color: Color.fromARGB(255, 239, 255, 245),
              fontSize: 28,
              fontWeight: FontWeight.normal,
              fontFamily: 'MyCustomFont',
            ),
          ),
        ],
      ),
      centerTitle: false,
      // Language toggle stays on the right
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11.0),
          child: Row(
            children: [
              Text(
                'EN',
                style: TextStyle(
                  color: Color.fromARGB(255, 191, 235, 239),
                  fontWeight: isHindi ? FontWeight.normal : FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              Switch(
                value: isHindi,
                onChanged: onToggleLanguage,
                activeColor: const Color.fromARGB(255, 239, 255, 245),
              ),
              Text(
                'हिंदी',
                style: TextStyle(
                  color: Color.fromARGB(255, 191, 235, 239),
                  fontWeight: isHindi ? FontWeight.bold : FontWeight.normal, fontSize: 20,
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
