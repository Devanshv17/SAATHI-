import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class GamePage extends StatefulWidget {
  final String gameTitle;

  const GamePage({Key? key, required this.gameTitle}) : super(key: key);

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  int score = 0;
  String question = "";
  List<Map<String, dynamic>> options = [];
  Set<String> shownQuestions = {}; // Track displayed questions

  @override
  void initState() {
    super.initState();
    fetchNewQuestion();
  }

  Future<void> fetchNewQuestion() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('Name Picture Matching')
          .get();

      if (snapshot.docs.isNotEmpty) {
        List<QueryDocumentSnapshot> allQuestions = snapshot.docs;
        allQuestions.shuffle(); // Randomize the order

        for (var doc in allQuestions) {
          var data = doc.data() as Map<String, dynamic>;
          if (!shownQuestions.contains(data['text'])) {
            setState(() {
              question = data['text'] ?? "What is this?";
              options = List<Map<String, dynamic>>.from(data['options']);
              shownQuestions.add(question); // Mark as shown
            });
            return; // Exit loop after selecting a new question
          }
        }

        // If all questions are shown, reset the set
        setState(() {
          shownQuestions.clear();
        });

        // Fetch again
        fetchNewQuestion();
      }
    } catch (e) {
      print("Error fetching question: $e");
    }
  }

  void checkAnswer(bool isCorrect, int index) {
    setState(() {
      if (isCorrect) {
        score++;
      }
      options[index]['selected'] = true;
    });
  }

  void showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Instructions"),
        content: Text(
          "1. Tap the correct image.\n"
          "2. A green circle appears for correct answers.\n"
          "3. A red circle appears for wrong answers.\n"
          "4. Your score increases only for correct answers.\n"
          "5. Click 'Skip' or 'Next' to get a new question.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Got it!"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        backgroundColor: Colors.blue.shade300,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.gameTitle,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white, size: 28),
              onPressed: () => showInstructions(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.isNotEmpty ? question : "Loading question...",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.only(bottom: 20),
                itemCount: options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                ),
                itemBuilder: (context, index) {
                  var option = options[index];
                  bool isSelected =
                      option.containsKey('selected') && option['selected'];
                  bool isCorrect = option['isCorrect'];

                  return GestureDetector(
                    onTap:
                        isSelected ? null : () => checkAnswer(isCorrect, index),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: isSelected
                                ? Border.all(
                                    color:
                                        isCorrect ? Colors.green : Colors.red,
                                    width: 6,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 5,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(option['imageUrl'],
                                fit: BoxFit.cover),
                          ),
                        ),
                        if (isSelected && isCorrect)
                          Positioned(
                            bottom: 10,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                option['description'],
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                "Your Score: $score",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  onPressed: fetchNewQuestion,
                  child: Text("Skip",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  onPressed: fetchNewQuestion,
                  child: Text("Next",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
