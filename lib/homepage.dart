import 'dart:ui';

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
import 'guesstheletter.dart';
import 'matching.dart';
import 'letustelltime.dart';
import 'letuscount.dart';
import 'widgets/voice_icon.dart';
import 'widgets/game_card.dart';
import 'theme/app_colors.dart';


class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Keep track of scores per game, keyed by the displayed title
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
    'Box10': 'Left Middle Right',
    'Box11': 'Shape Knowledge',
  };

  final Map<String, String> boxTextsHindi = {
    'Box1': 'नाम चित्र मिलान',
    'Box2': 'अक्षर ज्ञान',
    'Box3': 'तुलना',
    'Box4': 'चलो गिनें',
    'Box5': 'संख्या नाम मिलान',
    'Box6': 'नाम संख्या मिलान',
    'Box7': 'चलो समय बताएँ',
    'Box9': 'वर्णमाला ज्ञान',
    'Box10': 'बाएँ दाएँ मध्य',
    'Box11': 'आकार ज्ञान',
  };

  // English/Hindi versions of button labels
  String playText(bool isHindi) => isHindi ? 'खेलें' : 'Play';
  String continueText(bool isHindi) => isHindi ? 'जारी रखें' : 'Continue';
  String replayText(bool isHindi) => isHindi ? 'पुनः खेलें' : 'Replay';

  @override
  void initState() {
    super.initState();
    // Load scores once when the page first builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGameScores();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Whenever dependencies change (for example, language toggled), reload scores
    _loadGameScores();
  }
// Note: This function must be inside a State class that has access to
// _dbRef, _auth, setState, boxTextsEnglish, boxTextsHindi, correctScores, and incorrectScores.

// --- Safe casting helper function (Required by _loadGameScores) ---
  Map<String, dynamic>? _deepCastMap(Map? data) {
    if (data == null) return null;
    return Map<String, dynamic>.from(data.map((key, value) {
      var newKey = key.toString();
      var newValue = value;
      if (value is Map) {
        newValue = _deepCastMap(value);
      } else if (value is List) {
        newValue = _deepCastList(value);
      }
      return MapEntry(newKey, newValue);
    }));
  }

  List<dynamic>? _deepCastList(List? data) {
    if (data == null) return null;
    return data.map((item) {
      if (item is Map) {
        return _deepCastMap(item);
      } else if (item is List) {
        return _deepCastList(item);
      }
      return item;
    }).toList();
  }

  Future<void> _loadGameScores() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final isHindi =
        Provider.of<LanguageNotifier>(context, listen: false).isHindi;

    try {
      final snapshot = await _dbRef.child("users/${user.uid}/games").get();
      final Map<String, int> correct = {};
      final Map<String, int> incorrect = {};

      if (snapshot.exists) {
        final allGamesData = _deepCastMap(snapshot.value as Map) ?? {};

        for (var key in boxTextsEnglish.keys) {
          final engTitle = boxTextsEnglish[key]!;
          final hinTitle = boxTextsHindi[key]!;
          final displayTitle = isHindi ? hinTitle : engTitle;

          // Access the specific game's data
          final gameData = _deepCastMap(allGamesData[displayTitle]);

          // **FIX:** Now, access the nested 'main_game' object
          final mainGameData = _deepCastMap(gameData?['main_game']);

          if (mainGameData != null) {
            // Read scores from within 'main_game'
            correct[displayTitle] = (mainGameData['correctCount'] ?? 0);
            incorrect[displayTitle] = (mainGameData['incorrectCount'] ?? 0);
          } else {
            correct[displayTitle] = 0;
            incorrect[displayTitle] = 0;
          }
        }
      } else {
        // No 'games' node exists, initialize all to zero
        for (var key in boxTextsEnglish.keys) {
          final displayTitle =
              isHindi ? boxTextsHindi[key]! : boxTextsEnglish[key]!;
          correct[displayTitle] = 0;
          incorrect[displayTitle] = 0;
        }
      }

      if (mounted) {
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
      // Remove the node under the exact displayed title (English or Hindi)
      await _dbRef.child("users/${user.uid}/games/$title").remove();
    }

    late Widget destination;
    if (title == boxTextsEnglish['Box3'] || title == boxTextsHindi['Box3']) {
      destination = ComparePage(
        gameTitle: title, // pass the displayed title
        isHindi: isHindi,
      );
    } else if (title == boxTextsEnglish['Box2'] ||
        title == boxTextsHindi['Box2'] || title == boxTextsEnglish['Box11'] ||
        title == boxTextsHindi['Box11']) {
      destination = GuessTheLetterPage(
        gameTitle: title,
        isHindi: isHindi,
      );
    } else if (title == boxTextsEnglish['Box4'] ||
        title == boxTextsHindi['Box4']) {
      destination = LetUsCountPage(
        gameTitle: title,
        isHindi: isHindi,
      );
    } else if (title == boxTextsEnglish['Box7'] ||
        title == boxTextsHindi['Box7']) {
      destination = LetUsTellTimePage(
        gameTitle: title,
        isHindi: isHindi,
      );
    } else if (title == boxTextsEnglish['Box5'] ||
        title == boxTextsHindi['Box5'] ||
        title == boxTextsEnglish['Box6'] ||
        title == boxTextsHindi['Box6'] ||
        title == boxTextsEnglish['Box9'] ||
        title == boxTextsHindi['Box9'] ||
        title == boxTextsEnglish['Box10'] ||
        title == boxTextsHindi['Box10']  ) {
      destination = MatchingPage(
        gameTitle: title,
        isHindi: isHindi,
      );
    }  else if (
        title == boxTextsEnglish['Box1'] ||
        title == boxTextsHindi['Box1']
    ){
      // Fallback: generic GamePage with the displayed title
      destination = GamePage(
        gameTitle: title,
        isHindi: isHindi,
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => destination),
    ).then((_) {
      // After returning from a game, reload scores (in case something changed)
      _loadGameScores();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: NavBar(
        isHindi: isHindi,
        onToggleLanguage: (value) {
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(value);
          setState(() {}); // Rebuild to re-fetch scores in new language
        },
        showMenuButton: true,
      ),
      drawer:  CustomMenuBar(isHindi:isHindi),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              GameCard(
                title: isHindi ? boxTextsHindi['Box1']! : boxTextsEnglish['Box1']!,
                imagePath: isHindi ? 'assets/npph.jpg' : 'assets/npp.png',
                correctScore: correctScores[isHindi ? boxTextsHindi['Box1']! : boxTextsEnglish['Box1']!] ?? 0,
                incorrectScore: incorrectScores[isHindi ? boxTextsHindi['Box1']! : boxTextsEnglish['Box1']!] ?? 0,
                isHindi: isHindi,
                onPlay: () => _navigateBasedOnText(isHindi ? boxTextsHindi['Box1']! : boxTextsEnglish['Box1']!, isHindi),
                playLabel: playText(isHindi),
                continueLabel: continueText(isHindi),
              ),
              GameCard(
                title: isHindi ? boxTextsHindi['Box2']! : boxTextsEnglish['Box2']!,
                imagePath: isHindi ? 'assets/gtlh.jpg' : 'assets/gtl.png',
                correctScore: correctScores[isHindi ? boxTextsHindi['Box2']! : boxTextsEnglish['Box2']!] ?? 0,
                incorrectScore: incorrectScores[isHindi ? boxTextsHindi['Box2']! : boxTextsEnglish['Box2']!] ?? 0,
                isHindi: isHindi,
                onPlay: () => _navigateBasedOnText(isHindi ? boxTextsHindi['Box2']! : boxTextsEnglish['Box2']!, isHindi),
                playLabel: playText(isHindi),
                continueLabel: continueText(isHindi),
              ),
              GameCard(
                title: isHindi ? boxTextsHindi['Box3']! : boxTextsEnglish['Box3']!,
                imagePath: isHindi ? 'assets/cmp.png' : 'assets/cmp.png',
                correctScore: correctScores[isHindi ? boxTextsHindi['Box3']! : boxTextsEnglish['Box3']!] ?? 0,
                incorrectScore: incorrectScores[isHindi ? boxTextsHindi['Box3']! : boxTextsEnglish['Box3']!] ?? 0,
                isHindi: isHindi,
                onPlay: () => _navigateBasedOnText(isHindi ? boxTextsHindi['Box3']! : boxTextsEnglish['Box3']!, isHindi),
                playLabel: playText(isHindi),
                continueLabel: continueText(isHindi),
              ),
              GameCard(
                title: isHindi ? boxTextsHindi['Box4']! : boxTextsEnglish['Box4']!,
                imagePath: isHindi ? 'assets/cnth.jpg' : 'assets/cnt.png',
                correctScore: correctScores[isHindi ? boxTextsHindi['Box4']! : boxTextsEnglish['Box4']!] ?? 0,
                incorrectScore: incorrectScores[isHindi ? boxTextsHindi['Box4']! : boxTextsEnglish['Box4']!] ?? 0,
                isHindi: isHindi,
                onPlay: () => _navigateBasedOnText(isHindi ? boxTextsHindi['Box4']! : boxTextsEnglish['Box4']!, isHindi),
                playLabel: playText(isHindi),
                continueLabel: continueText(isHindi),
              ),
              GameCard(
                title: isHindi ? boxTextsHindi['Box5']! : boxTextsEnglish['Box5']!,
                imagePath: isHindi ? 'assets/namenmh.jpg' : 'assets/namenm.png',
                correctScore: correctScores[isHindi ? boxTextsHindi['Box5']! : boxTextsEnglish['Box5']!] ?? 0,
                incorrectScore: incorrectScores[isHindi ? boxTextsHindi['Box5']! : boxTextsEnglish['Box5']!] ?? 0,
                isHindi: isHindi,
                onPlay: () => _navigateBasedOnText(isHindi ? boxTextsHindi['Box5']! : boxTextsEnglish['Box5']!, isHindi),
                playLabel: playText(isHindi),
                continueLabel: continueText(isHindi),
              ),
              GameCard(
                title: isHindi ? boxTextsHindi['Box6']! : boxTextsEnglish['Box6']!,
                imagePath: isHindi ? 'assets/numnph.jpg' : 'assets/numnp.png',
                correctScore: correctScores[isHindi ? boxTextsHindi['Box6']! : boxTextsEnglish['Box6']!] ?? 0,
                incorrectScore: incorrectScores[isHindi ? boxTextsHindi['Box6']! : boxTextsEnglish['Box6']!] ?? 0,
                isHindi: isHindi,
                onPlay: () => _navigateBasedOnText(isHindi ? boxTextsHindi['Box6']! : boxTextsEnglish['Box6']!, isHindi),
                playLabel: playText(isHindi),
                continueLabel: continueText(isHindi),
              ),
              GameCard(
                title: isHindi ? boxTextsHindi['Box7']! : boxTextsEnglish['Box7']!,
                imagePath: isHindi ? 'assets/ltth.jpg' : 'assets/ltt.png',
                correctScore: correctScores[isHindi ? boxTextsHindi['Box7']! : boxTextsEnglish['Box7']!] ?? 0,
                incorrectScore: incorrectScores[isHindi ? boxTextsHindi['Box7']! : boxTextsEnglish['Box7']!] ?? 0,
                isHindi: isHindi,
                onPlay: () => _navigateBasedOnText(isHindi ? boxTextsHindi['Box7']! : boxTextsEnglish['Box7']!, isHindi),
                playLabel: playText(isHindi),
                continueLabel: continueText(isHindi),
              ),
              GameCard(
                title: isHindi ? boxTextsHindi['Box9']! : boxTextsEnglish['Box9']!,
                imagePath: isHindi ? 'assets/akh.jpg' : 'assets/ak.png',
                correctScore: correctScores[isHindi ? boxTextsHindi['Box9']! : boxTextsEnglish['Box9']!] ?? 0,
                incorrectScore: incorrectScores[isHindi ? boxTextsHindi['Box9']! : boxTextsEnglish['Box9']!] ?? 0,
                isHindi: isHindi,
                onPlay: () => _navigateBasedOnText(isHindi ? boxTextsHindi['Box9']! : boxTextsEnglish['Box9']!, isHindi),
                playLabel: playText(isHindi),
                continueLabel: continueText(isHindi),
              ),
              GameCard(
                title: isHindi ? boxTextsHindi['Box10']! : boxTextsEnglish['Box10']!,
                imagePath: isHindi ? 'assets/lrh.jpg' : 'assets/lr.png',
                correctScore: correctScores[isHindi ? boxTextsHindi['Box10']! : boxTextsEnglish['Box10']!] ?? 0,
                incorrectScore: incorrectScores[isHindi ? boxTextsHindi['Box10']! : boxTextsEnglish['Box10']!] ?? 0,
                isHindi: isHindi,
                onPlay: () => _navigateBasedOnText(isHindi ? boxTextsHindi['Box10']! : boxTextsEnglish['Box10']!, isHindi),
                playLabel: playText(isHindi),
                continueLabel: continueText(isHindi),
              ),
              GameCard(
                title: isHindi ? boxTextsHindi['Box11']! : boxTextsEnglish['Box11']!,
                imagePath: isHindi ? 'assets/fsh.jpg' : 'assets/fs.png',
                correctScore: correctScores[isHindi ? boxTextsHindi['Box11']! : boxTextsEnglish['Box11']!] ?? 0,
                incorrectScore: incorrectScores[isHindi ? boxTextsHindi['Box11']! : boxTextsEnglish['Box11']!] ?? 0,
                isHindi: isHindi,
                onPlay: () => _navigateBasedOnText(isHindi ? boxTextsHindi['Box11']! : boxTextsEnglish['Box11']!, isHindi),
                playLabel: playText(isHindi),
                continueLabel: continueText(isHindi),
              ),
              const SizedBox(height: 60),
            ],
            
          ),
        ),
        
      ),
      
    );
  }
}
