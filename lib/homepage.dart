import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translator_plus/translator_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'language_notifier.dart';
import 'navbar.dart';
import 'menu_bar.dart';
import 'game.dart';
import 'compare.dart';
import 'letuscount.dart';
import 'matching.dart';
import 'letustelltime.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GoogleTranslator translator = GoogleTranslator();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String appBarTitle = 'Saathi';

  Map<String, String> boxTexts = {
    'Box1': 'Name Picture Matching',
    'Box2': 'Guess the Letter',
    'Box3': 'Compare',
    'Box4': 'Let us Count',
    'Box5': 'Number Name Matching',
    'Box6': 'Name Number Matching',
    'Box7': 'Let us Tell Time',
    'Box8': 'Let us Look at Calendar',
    'Box9': 'Alphabet Knowledge',
  };

  Map<String, int> correctScores = {};
  Map<String, int> incorrectScores = {};

  @override
  void initState() {
    super.initState();
    _loadGameScores();
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
          ...boxTexts.values.map((e) => translator.translate(e, to: 'hi')),
        ]);

        setState(() {
          appBarTitle = results[0].text;
          int i = 1;
          for (String key in boxTexts.keys) {
            boxTexts[key] = results[i++].text;
          }
        });
      } catch (e) {
        print("Translation failed: $e");
      }
    } else {
      setState(() {
        boxTexts = {
          'Box1': 'Name Picture Matching',
          'Box2': 'Guess the Letter',
          'Box3': 'Compare',
          'Box4': 'Let us Count',
          'Box5': 'Number Name Matching',
          'Box6': 'Name Number Matching',
          'Box7': 'Let us Tell Time',
          'Box8': 'Let us Look at Calendar',
          'Box9': 'Alphabet Knowledge',
        };
      });
    }
  }

  Future<void> _loadGameScores() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _dbRef.child("users/${user.uid}/games").get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        print("Fetched user game data: $data");

        final Map<String, int> correct = {};
        final Map<String, int> incorrect = {};

        boxTexts.values.forEach((game) {
          final gameData = data[game];
          if (gameData != null) {
            correct[game] = (gameData['correctCount'] ?? 0);
            incorrect[game] = (gameData['incorrectCount'] ?? 0);
          } else {
            correct[game] = 0;
            incorrect[game] = 0;
          }
        });

        setState(() {
          correctScores = correct;
          incorrectScores = incorrect;
        });
      } else {
        print("No game data found in Realtime Database.");
      }
    } catch (e) {
      print("Error fetching game scores: $e");
    }
  }

  void _navigateBasedOnText(String title, {bool reset = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (reset) {
      await _dbRef.child("users/${user.uid}/games/$title").remove();
    }

    Widget destination;
    if (title == "Compare") {
      destination = ComparePage(); // sample values; adjust as needed
    } else if (title == "Let us Count" || title == "Let us Look at Calendar" || title == "Guess the Letter") {
      destination = LetUsCountPage();
    } else if (title == "Let us Tell Time") {
      destination = LetUsTellTimePage();
    } else if (title == "Number Name Matching" || title == "Name Number Matching" || title == "Alphabet Knowledge") {
      destination = MatchingPage();
    } else {
      destination = GamePage(gameTitle: title);
    }


    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => destination),
    ).then((_) {
      _loadGameScores(); // Refresh after returning
    });
  }

  Widget buildBox(String key, String imagePath, Color bgColor) {
    final title = boxTexts[key]!;
    final correct = correctScores[title] ?? 0;
    final incorrect = incorrectScores[title] ?? 0;
    final hasPlayed = correct + incorrect > 0;

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (hasPlayed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$correct',
                            style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: ' | '),
                          TextSpan(
                            text: '$incorrect',
                            style: const TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _navigateBasedOnText(title),
                      child: Text(hasPlayed ? 'Continue' : 'Play'),
                    ),
                    if (hasPlayed) const SizedBox(width: 10),
                    if (hasPlayed)
                      ElevatedButton(
                        onPressed: () => _navigateBasedOnText(title, reset: true),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        child: const Text('Replay'),
                      ),
                  ],
                )
              ],
            ),
          ),
        ],
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
          Provider.of<LanguageNotifier>(context, listen: false).toggleLanguage(value);
          _updateTranslations();
        },
        showMenuButton: true,
      ),
      drawer: const CustomMenuBar(),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              buildBox('Box1', 'assets/image.png', Colors.blue.shade100),
              buildBox('Box2', 'assets/image.png', Colors.blue.shade100),
              buildBox('Box3', 'assets/image.png', Colors.blue.shade100),
              buildBox('Box4', 'assets/image.png', Colors.blue.shade100),
              buildBox('Box5', 'assets/image.png', Colors.blue.shade100),
              buildBox('Box6', 'assets/image.png', Colors.blue.shade100),
              buildBox('Box7', 'assets/image.png', Colors.blue.shade100),
              buildBox('Box8', 'assets/image.png', Colors.blue.shade100),
              buildBox('Box9', 'assets/image.png', Colors.blue.shade100),
            ],
          ),
        ),
      ),
    );
  }
}
