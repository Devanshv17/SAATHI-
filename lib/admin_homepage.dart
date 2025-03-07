import 'package:flutter/material.dart';
import 'navbar.dart';
import 'package:provider/provider.dart';
import 'language_notifier.dart';
import 'package:translator_plus/translator_plus.dart';
import 'menu_bar.dart'; // This file contains the CustomMenuBar widget

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GoogleTranslator translator = GoogleTranslator();
  String appBarTitle = 'Admin Panel';
  String contentText = 'This is admin page';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final isHindi =
        Provider.of<LanguageNotifier>(context, listen: false).isHindi;
    if (isHindi) {
      try {
        final results = await Future.wait([
          translator.translate('Admin Panel', to: 'hi'),
          translator.translate('This is admin page', to: 'hi'),
        ]);
        setState(() {
          appBarTitle = results[0].text;
          contentText = results[1].text;
        });
      } catch (e) {
        // Fallback to English if translation fails.
      }
    } else {
      setState(() {
        appBarTitle = 'Admin Panel';
        contentText = 'This is admin page';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;
    return Scaffold(
      appBar: NavBar(
        title: appBarTitle,
        isHindi: isHindi,
        onToggleLanguage: (value) {
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(value);
          _updateTranslations();
        },
        showMenuButton: true, // Show the menu button on admin page.
      ),
      drawer: const CustomMenuBar(), // Left-side drawer with logout etc.
      body: Center(
        child: Text(
          contentText,
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
