import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:pie_chart/pie_chart.dart';

// Import the game pages as needed.
import 'game.dart';
import 'guesstheletter.dart';
import 'compare.dart';
import 'letuscount.dart';
import 'matching.dart';
import 'letustelltime.dart';

class ResultPage extends StatelessWidget {
  final String gameTitle;
  final int score;
  final int correctCount;
  final int incorrectCount;
  final bool isHindi;
  

  ResultPage({
    required this.gameTitle,
    required this.score,
    required this.correctCount,
    required this.incorrectCount,
    required this.isHindi,
    
  });

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Returns the appropriate game page widget based on the gameTitle.
  Widget getGamePage(String gameTitle) {
    // Use the same conditions as in HomePage's _navigateBasedOnText.
    if (gameTitle == "Compare" || gameTitle=="तुलना") {
      return ComparePage(
         gameTitle: gameTitle,
        isHindi: isHindi,
      );
    } else if (gameTitle == "Let us Look at Calendar" ||
        gameTitle == "Guess the Letter" || gameTitle=="अक्षर अनुमान") {
      return GuessTheLetterPage(
          gameTitle: gameTitle,
        isHindi: isHindi,
      );
    } else if (gameTitle == "Let us Count" || gameTitle=="चलो गिनें") {
      return LetUsCountPage(
          gameTitle: gameTitle,
        isHindi: isHindi,
      );
    } else if (gameTitle == "Let us Tell Time" || gameTitle=="चलो समय बताएँ") {
      return LetUsTellTimePage(
          gameTitle: gameTitle,
        isHindi: isHindi,
      );
    } else if (gameTitle == "Number Name Matching" ||
        gameTitle == "Name Number Matching" ||
        gameTitle == "Alphabet Knowledge" ||
      
        gameTitle=="संख्या नाम मिलान"
        || gameTitle=="नाम संख्या मिलान"
        || gameTitle=="वर्णमाला ज्ञान"
       ) {
      // For these games, we assume MatchingPage takes the gameTitle.
      return MatchingPage(gameTitle: gameTitle, isHindi: isHindi);
    } else {
      // Fallback to a generic GamePage.
      return GamePage(gameTitle: gameTitle, isHindi: isHindi);
    }
  }

  Future<void> _resetGame(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Reset the game state on the Realtime Database.
      await _dbRef.child("users/${user.uid}/games/$gameTitle").update({
        "score": 0,
        "correctCount": 0,
        "incorrectCount": 0,
        "answers": {},
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => getGamePage(gameTitle),
        ),
      );
    } catch (e) {
      print("Error resetting game: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, double> dataMap = {
      isHindi? "सही":"Correct": correctCount.toDouble(),
      isHindi ? "गलत" : "Incorrect": incorrectCount.toDouble(),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(isHindi?"परिणाम" :"Result"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text( isHindi? "आपका अंक:":"Your Score: $score",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 30),
            PieChart(
              dataMap: dataMap,
              chartType: ChartType.ring,
              chartRadius: MediaQuery.of(context).size.width / 2.2,
              chartValuesOptions: ChartValuesOptions(
                showChartValuesInPercentage: true,
                showChartValues: true,
              ),
              legendOptions: LegendOptions(
                legendPosition: LegendPosition.right,
              ),
              colorList: [Colors.green, Colors.red],
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => _resetGame(context),
              child: Text(isHindi? "पुनः प्रयास करें" :"Replay"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
