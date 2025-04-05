import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pie_chart/pie_chart.dart';
import 'game.dart';

class ResultPage extends StatelessWidget {
  final String gameTitle;
  final int score;
  final int correctCount;
  final int incorrectCount;

  ResultPage({
    required this.gameTitle,
    required this.score,
    required this.correctCount,
    required this.incorrectCount,
  });

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Future<void> _resetGame(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _dbRef.child("users/${user.uid}/games/$gameTitle").update({
        "score": 0,
        "correctCount": 0,
        "incorrectCount": 0,
        "answers": {},
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GamePage(gameTitle: gameTitle),
        ),
      );
    } catch (e) {
      print("Error resetting game: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, double> dataMap = {
      "Correct": correctCount.toDouble(),
      "Incorrect": incorrectCount.toDouble(),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text("Result"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text("Your Score: $score",
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
              child: Text("Replay"),
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
