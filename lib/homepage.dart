import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'language_notifier.dart';
import 'navbar.dart';
import 'package:translator_plus/translator_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GoogleTranslator translator = GoogleTranslator();
  String appBarTitle = 'Saathi';
  String box1Text = 'Box 1';
  String box2Text = 'Box 2';
  String box3Text = 'Box 3';
  String box4Text = 'Box 4';

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool loggedIn = prefs.getBool('loggedIn') ?? false;
    if (!loggedIn) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

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
          translator.translate('Saathi', to: 'hi'),
          translator.translate('Box 1', to: 'hi'),
          translator.translate('Box 2', to: 'hi'),
          translator.translate('Box 3', to: 'hi'),
          translator.translate('Box 4', to: 'hi'),
        ]);
        setState(() {
          appBarTitle = results[0].text;
          box1Text = results[1].text;
          box2Text = results[2].text;
          box3Text = results[3].text;
          box4Text = results[4].text;
        });
      } catch (e) {
        // Fallback to English.
      }
    } else {
      setState(() {
        appBarTitle = 'Saathi';
        box1Text = 'Box 1';
        box2Text = 'Box 2';
        box3Text = 'Box 3';
        box4Text = 'Box 4';
      });
    }
  }

  Widget buildBox(String text, String imagePath, Color bgColor) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.85, // 85% width
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          // Left-side Rounded Image
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50), // Circular shape
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 15),
          // Right-side Column for title & button
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // Play button logic
                  },
                  child: const Text('Play'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', false);
    Navigator.pushReplacementNamed(context, '/login');
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
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: ElevatedButton(
                    onPressed: _logout,
                    child: Text(isHindi ? 'लॉगआउट' : 'Logout'),
                  ),
                ),
              ),
              buildBox(box1Text, 'assets/image.png', Colors.blue.shade100),
              buildBox(box2Text, 'assets/image.png', Colors.blue.shade100),
              buildBox(box3Text, 'assets/image.png', Colors.blue.shade100),
              buildBox(box4Text, 'assets/image.png', Colors.blue.shade100),
            ],
          ),
        ),
      ),
    );
  }
}
