import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'language_notifier.dart';
import 'navbar.dart';
import 'menu_bar.dart'; // Contains CustomMenuBar
import 'package:translator_plus/translator_plus.dart';

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
        // Fallback to English if translation fails.
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

  Widget buildRow(String text1, String text2) {
    return Row(
      children: [
        Expanded(child: buildBox(text1)),
        const SizedBox(width: 10),
        Expanded(child: buildBox(text2)),
      ],
    );
  }

  Widget buildBox(String text) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDD0),
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
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
        showMenuButton: true, // Shows the hamburger icon.
      ),
      drawer: const CustomMenuBar(), // Left-side drawer.
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              buildRow(box1Text, box2Text),
              const SizedBox(height: 10),
              buildRow(box3Text, box4Text),
            ],
          ),
        ),
      ),
    );
  }
}
