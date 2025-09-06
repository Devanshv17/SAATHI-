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
import 'matching.dart';
import 'letustelltime.dart';
import 'letuscount.dart';


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

  Widget buildBox(String key, bool isHindi, Color bgColor,String imgpath,String imgpathHindi) {
    final title = isHindi ? boxTextsHindi[key]! : boxTextsEnglish[key]!;
    final correct = correctScores[title] ?? 0;
    final incorrect = incorrectScores[title] ?? 0;
    final hasPlayed = (correct + incorrect) > 0;
    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: Color.fromARGB(255, 101, 65, 239), width: 2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              border: Border.all(color: Color.fromARGB(255, 101, 65, 239),width: 1),
              borderRadius: BorderRadius.circular(50),
              image:  DecorationImage(
                image: AssetImage(isHindi?imgpathHindi:imgpath),
                fit: BoxFit.cover
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
                      fontSize: 16, color: Color.fromARGB(255, 101, 65, 239), fontWeight: FontWeight.bold,fontFamily: 'MyCustom2'),
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
                                color: Color.fromARGB(255, 63, 108, 64),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,fontFamily: 'MyCustomFont'),
                          ),
                          const TextSpan( text: '  |  ', style: const TextStyle(color: Color.fromARGB(255, 101, 65, 239),
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                          TextSpan(
                            text: '$incorrect',
                            style: const TextStyle(
                                color: Color.fromARGB(255, 200, 82, 87),
                                fontSize: 16,
                                fontWeight: FontWeight.bold, fontFamily: 'MyCustomFont'),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ElevatedButton(
                    style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 191, 235, 239)),
                      onPressed: () => _navigateBasedOnText(title, isHindi),
                      child: Text( style: const TextStyle(color: Color.fromARGB(255, 101, 65, 239), fontSize: 14,fontFamily: 'MyCustomFont',fontWeight: FontWeight.normal),
                        hasPlayed ? continueText(isHindi) : playText(isHindi),
                      ),
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
      backgroundColor: Color.fromARGB(255, 245, 255, 255),
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
              buildBox('Box1', isHindi, Color.fromARGB(100, 191, 235, 239),'assets/npp.png','assets/npph.jpg'),
              buildBox('Box2', isHindi, Color.fromARGB(100, 191, 235, 239),'assets/gtl.png','assets/gtlh.jpg'),
              buildBox('Box3', isHindi, Color.fromARGB(100, 191, 235, 239),'assets/cmp.png','assets/cmp.png'),
              buildBox('Box4', isHindi, Color.fromARGB(100, 191, 235, 239), 'assets/cnt.png','assets/cnth.jpg'),
              buildBox('Box5', isHindi, Color.fromARGB(100, 191, 235, 239),'assets/namenm.png','assets/namenmh.jpg'),
              buildBox('Box6', isHindi, Color.fromARGB(100, 191, 235, 239), 'assets/numnp.png','assets/numnph.jpg'),
              buildBox('Box7', isHindi, Color.fromARGB(100, 191, 235, 239), 'assets/ltt.png','assets/ltth.jpg'),
              // buildBox('Box8', isHindi, Colors.blue.shade100),
              buildBox('Box9', isHindi, Color.fromARGB(100, 191, 235, 239), 'assets/ak.png','assets/akh.jpg'),
              buildBox('Box10', isHindi, Color.fromARGB(100, 191, 235, 239), 'assets/lr.png','assets/lrh.jpg'),
              buildBox('Box11', isHindi, Color.fromARGB(100, 191, 235, 239), 'assets/fs.png','assets/fsh.jpg'),
              const SizedBox(height: 60),
            ],
            
          ),
        ),
        
      ),
      
    );
  }
}
