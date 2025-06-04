import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import 'language_notifier.dart';
import 'navbar.dart';
import 'menu_bar.dart';
import 'game.dart';
import 'compare.dart';
import 'guesstheletter.dart';
import 'matching.dart';
import 'letustelltime.dart';
import 'letuscount.dart';
import 'left_or_right.dart';
import 'fit_the_shape.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Keep track of scores per game
  Map<String, int> correctScores = {};
  Map<String, int> incorrectScores = {};

  // Hard-coded English & Hindi labels for each box
  final Map<String, String> boxTextsEnglish = {
    'Box1': 'Name Picture Matching',
    'Box2': 'Guess the Letter',
    'Box3': 'Compare',
    'Box4': 'Let us Count',
    'Box5': 'Number Name Matching',
    'Box6': 'Name Number Matching',
    'Box7': 'Let us Tell Time',
    'Box9': 'Alphabet Knowledge',
    'Box10': 'Left or Right?',
    'Box11': 'Fit the Shape',
  };

  final Map<String, String> boxTextsHindi = {
    'Box1': 'नाम चित्र मिलान',
    'Box2': 'अक्षर अनुमान',
    'Box3': 'तुलना',
    'Box4': 'चलो गिनें',
    'Box5': 'संख्या नाम मिलान',
    'Box6': 'नाम संख्या मिलान',
    'Box7': 'चलो समय बताएँ',
    'Box9': 'वर्णमाला ज्ञान',
    'Box10': 'बाएँ या दाएँ?',
    'Box11': 'आकार फिट करें',
  };

  // English/Hindi versions of button labels
  String playText(bool isHindi) => isHindi ? 'खेलें' : 'Play';
  String continueText(bool isHindi) => isHindi ? 'जारी रखें' : 'Continue';
  String replayText(bool isHindi) => isHindi ? 'पुनः खेलें' : 'Replay';

  @override
  void initState() {
    super.initState();
    _loadGameScores();
  }

  Future<void> _loadGameScores() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _dbRef.child("users/${user.uid}/games").get();
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        final Map<String, int> correct = {};
        final Map<String, int> incorrect = {};

        // For each English label, fetch stored counts
        for (var game in boxTextsEnglish.values) {
          final gameData = data[game];
          if (gameData != null) {
            correct[game] = (gameData['correctCount'] ?? 0);
            incorrect[game] = (gameData['incorrectCount'] ?? 0);
          } else {
            correct[game] = 0;
            incorrect[game] = 0;
          }
        }

        setState(() {
          correctScores = correct;
          incorrectScores = incorrect;
        });
      }
    } catch (e) {
      print("Error fetching game scores: $e");
    }
  }

  void _navigateBasedOnText(String title, bool isHindi,
      {bool reset = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    if (reset) {
      await _dbRef.child("users/${user.uid}/games/$title").remove();
    }

    late Widget destination;
    if (title == boxTextsEnglish['Box3'] || title == boxTextsHindi['Box3']) {
      destination = ComparePage(isHindi: isHindi);
    } else if (title == boxTextsEnglish['Box2'] ||
        title == boxTextsHindi['Box2']) {
      destination = GuessTheLetterPage(isHindi: isHindi);
    } else if (title == boxTextsEnglish['Box4'] ||
        title == boxTextsHindi['Box4']) {
      destination = LetUsCountPage(isHindi: isHindi);
    } else if (title == boxTextsEnglish['Box7'] ||
        title == boxTextsHindi['Box7']) {
      destination = LetUsTellTimePage(isHindi: isHindi);
    } else if (title == boxTextsEnglish['Box5'] ||
        title == boxTextsHindi['Box5'] ||
        title == boxTextsEnglish['Box6'] ||
        title == boxTextsHindi['Box6'] ||
        title == boxTextsEnglish['Box9'] ||
        title == boxTextsHindi['Box9']) {
      // For MatchingPage, pass the English title as gameTitle
      final gameTitle = boxTextsEnglish.entries
          .firstWhere((e) => e.value == title || boxTextsHindi[e.key] == title)
          .value;
      destination = MatchingPage(gameTitle: gameTitle, isHindi: isHindi);
    } else if (title == boxTextsEnglish['Box10'] ||
        title == boxTextsHindi['Box10']) {
      // destination = LeftorRightPage(isHindi: isHindi);
    } else if (title == boxTextsEnglish['Box11'] ||
        title == boxTextsHindi['Box11']) {
      destination = FitTheShapePage(isHindi: isHindi);
    } else {
      // Fallback: GamePage with the English title
      final gameTitle = boxTextsEnglish.entries
          .firstWhere((e) => e.value == title || boxTextsHindi[e.key] == title)
          .value;
      destination = GamePage(gameTitle: gameTitle, isHindi: isHindi);
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => destination),
    ).then((_) {
      _loadGameScores();
    });
  }

  Widget buildBox(String key, bool isHindi, Color bgColor) {
    final title = isHindi ? boxTextsHindi[key]! : boxTextsEnglish[key]!;
    final englishTitle = boxTextsEnglish[key]!;
    final correct = correctScores[englishTitle] ?? 0;
    final incorrect = incorrectScores[englishTitle] ?? 0;
    final hasPlayed = (correct + incorrect) > 0;

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
              image: const DecorationImage(
                image: AssetImage('assets/image.png'),
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
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (hasPlayed)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$correct',
                            style: const TextStyle(
                                color: Colors.green,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const TextSpan(text: '  |  '),
                          TextSpan(
                            text: '$incorrect',
                            style: const TextStyle(
                                color: Colors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _navigateBasedOnText(title, isHindi),
                      child: Text(hasPlayed
                          ? continueText(isHindi)
                          : playText(isHindi)),
                    ),
                    if (hasPlayed) const SizedBox(width: 10),
                    if (hasPlayed)
                      ElevatedButton(
                        onPressed: () =>
                            _navigateBasedOnText(title, isHindi, reset: true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                        child: Text(replayText(isHindi)),
                      ),
                  ],
                ),
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
        title: isHindi ? 'साथी' : 'Saathi',
        isHindi: isHindi,
        onToggleLanguage: (value) {
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(value);
          setState(() {});
        },
        showMenuButton: true,
      ),
      drawer: const CustomMenuBar(),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              buildBox('Box1', isHindi, Colors.blue.shade100),
              buildBox('Box2', isHindi, Colors.blue.shade100),
              buildBox('Box3', isHindi, Colors.blue.shade100),
              buildBox('Box4', isHindi, Colors.blue.shade100),
              buildBox('Box5', isHindi, Colors.blue.shade100),
              buildBox('Box6', isHindi, Colors.blue.shade100),
              buildBox('Box7', isHindi, Colors.blue.shade100),
              // buildBox('Box8', isHindi, Colors.blue.shade100),
              buildBox('Box9', isHindi, Colors.blue.shade100),
              buildBox('Box10', isHindi, Colors.blue.shade100),
              buildBox('Box11', isHindi, Colors.blue.shade100),
            ],
          ),
        ),
      ),
    );
  }
}
