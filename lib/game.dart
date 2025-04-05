import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart'; // Import result page

class GamePage extends StatefulWidget {
  final String gameTitle;

  const GamePage({Key? key, required this.gameTitle}) : super(key: key);

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  String questionText = "";
  String currentDocId = "";
  List<Map<String, dynamic>> options = [];

  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;
  Map<String, dynamic> userAnswers = {};

  List<QueryDocumentSnapshot> allQuestions = [];
  List<String> questionHistory = [];
  int currentHistoryIndex = -1;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadGameState().then((_) => _fetchAllQuestions());
  }

  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _dbRef
          .child("users/${user.uid}/games/${widget.gameTitle}")
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          score = data['score'] ?? 0;
          correctCount = data['correctCount'] ?? 0;
          incorrectCount = data['incorrectCount'] ?? 0;
          if (data['answers'] != null) {
            userAnswers = Map<String, dynamic>.from(data['answers']);
          }
        });
      }
    } catch (e) {
      print("Error loading game state: $e");
    }
  }

  Future<void> _saveGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _dbRef.child("users/${user.uid}/games/${widget.gameTitle}").update({
        "score": score,
        "correctCount": correctCount,
        "incorrectCount": incorrectCount,
        "answers": userAnswers,
      });
    } catch (e) {
      print("Error saving game state: $e");
    }
  }

  Future<void> _fetchAllQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(widget.gameTitle)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          allQuestions = snapshot.docs;
        });
        _getNewQuestion();
      }
    } catch (e) {
      print("Error fetching questions: $e");
    }
  }

  void _loadQuestionFromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      currentDocId = doc.id;
      questionText = data['text'] ?? "Question";
      options = List<Map<String, dynamic>>.from(data['options'] ?? []);

      // Reset previous selections
      for (var opt in options) {
        opt['selected'] = false;
      }

      if (userAnswers.containsKey(doc.id)) {
        final savedAnswer = userAnswers[doc.id];
        final savedIndex = savedAnswer['selectedOptionIndex'] as int?;
        if (savedIndex != null && savedIndex < options.length) {
          options[savedIndex]['selected'] = true;
        }
      }
    });
  }

  void _getNewQuestion() {
    List<QueryDocumentSnapshot> unanswered = allQuestions
        .where((doc) => !userAnswers.containsKey(doc.id))
        .toList();

    if (unanswered.isEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultPage(
            gameTitle: widget.gameTitle,
            score: score,
            correctCount: correctCount,
            incorrectCount: incorrectCount,
          ),
        ),
      );
      return;
    }

    unanswered.shuffle();
    QueryDocumentSnapshot selectedDoc = unanswered.first;
    _loadQuestionFromDoc(selectedDoc);
    questionHistory.add(selectedDoc.id);
    currentHistoryIndex = questionHistory.length - 1;
  }

  void _goToPreviousQuestion() {
    if (currentHistoryIndex > 0) {
      currentHistoryIndex--;
      String prevDocId = questionHistory[currentHistoryIndex];
      QueryDocumentSnapshot? doc = allQuestions.firstWhere(
              (doc) => doc.id == prevDocId,
          orElse: () => null as QueryDocumentSnapshot);
      if (doc != null) _loadQuestionFromDoc(doc);
    }
  }

  void _goToNextQuestion() {
    if (currentHistoryIndex < questionHistory.length - 1) {
      currentHistoryIndex++;
      String nextDocId = questionHistory[currentHistoryIndex];
      QueryDocumentSnapshot? doc = allQuestions.firstWhere(
              (doc) => doc.id == nextDocId,
          orElse: () => null as QueryDocumentSnapshot);
      if (doc != null) _loadQuestionFromDoc(doc);
    } else {
      _getNewQuestion();
    }
  }

  void checkAnswer(int index) {
    if (userAnswers.containsKey(currentDocId)) return;

    bool isCorrect = options[index]['isCorrect'] == true;

    setState(() {
      options[index]['selected'] = true;

      if (isCorrect) {
        score++;
        correctCount++;
      } else {
        incorrectCount++;
      }

      userAnswers[currentDocId] = {
        "selectedOptionIndex": index,
        "isCorrect": isCorrect,
      };
    });

    _saveGameState();
  }

  void showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Instructions"),
        content: Text(
          "1. Tap the correct image.\n"
              "2. A green border means correct, red means wrong.\n"
              "3. Once answered, questions are locked.\n"
              "4. Use 'Next' for new questions.\n"
              "5. Use 'Previous' to revisit answered ones.",
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
  void dispose() {
    _saveGameState();
    super.dispose();
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
            Text(widget.gameTitle),
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white),
              onPressed: () => showInstructions(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              questionText.isNotEmpty ? questionText : "Loading question...",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15),
                itemBuilder: (context, index) {
                  var option = options[index];
                  bool isSelected = option['selected'] == true;
                  bool isCorrect = option['isCorrect'] == true;

                  return GestureDetector(
                    onTap: () {
                      if (!userAnswers.containsKey(currentDocId)) {
                        checkAnswer(index);
                      }
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: isSelected
                                ? Border.all(
                              color: isCorrect ? Colors.green : Colors.red,
                              width: 6,
                            )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 5,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.network(
                              option['imageUrl'],
                              fit: BoxFit.cover,
                            ),
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
                                option['description'] ?? '',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          )
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),
            Column(
              children: [
                Text(
                  "Score: $score",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Correct: $correctCount | Incorrect: $incorrectCount",
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _goToPreviousQuestion,
                  child: Text("Previous"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange),
                ),
                ElevatedButton(
                  onPressed: _goToNextQuestion,
                  child: Text("Next"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
