import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'result.dart';

class LetUsCountPage extends StatefulWidget {
  const LetUsCountPage({Key? key}) : super(key: key);

  @override
  _LetUsCountPageState createState() => _LetUsCountPageState();
}

class _LetUsCountPageState extends State<LetUsCountPage> {
  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;
  String question = "Loading...";
  int imageCount = 0;
  List<String> imageAssets = [];
  List<Map<String, dynamic>> options = [];
  String currentDocId = "";

  List<String> questionOrder = [];
  List<QueryDocumentSnapshot> allQuestions = [];
  int currentQuestionIndex = -1;
  Map<String, dynamic> userAnswers = {};

  final Random _random = Random();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // The game key used in saving and loading game state—must match the key expected by the homepage.
  final String gameKey = "Let us Count";

  @override
  void initState() {
    super.initState();
    _loadGameState().then((_) => _fetchQuestionsInOrder());
  }

  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("games")
        .doc(gameKey)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        score = data['score'] ?? 0;
        correctCount = data['correctCount'] ?? 0;
        incorrectCount = data['incorrectCount'] ?? 0;
        userAnswers = Map<String, dynamic>.from(data['answers'] ?? {});
        questionOrder = List<String>.from(data['questionOrder'] ?? []);
      });
    }
  }

  Future<void> _saveGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;

    Map<String, dynamic> gameState = {
      "score": score,
      "correctCount": correctCount,
      "incorrectCount": incorrectCount,
      "answers": userAnswers,
      "questionOrder": questionOrder,
    };

    // Save to Firestore under the game key "Let us Count".
    await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("games")
        .doc(gameKey)
        .set(gameState);

    // Also update Realtime Database so that your homepage (which listens here) gets the updated state.
    await _dbRef.child("users/${user.uid}/games/$gameKey").update(gameState);
  }

  Future<void> _fetchQuestionsInOrder() async {
    try {
      final snapshot = await _firestore
          .collection('Let us Count')
          .get(const GetOptions(source: Source.serverAndCache));

      allQuestions = snapshot.docs;
      if (allQuestions.isEmpty) return;

      if (questionOrder.isEmpty) {
        final answered = allQuestions
            .where((doc) => userAnswers.containsKey(doc.id))
            .map((doc) => doc.id)
            .toList();
        final unanswered = allQuestions
            .where((doc) => !userAnswers.containsKey(doc.id))
            .map((doc) => doc.id)
            .toList();

        setState(() => questionOrder = [...answered, ...unanswered]);
        await _saveGameState();
      }

      if (_allQuestionsAnswered()) {
        _onFinishPressed();
        return;
      }

      _loadQuestionFromIndex(_firstUnansweredIndex());
    } catch (e) {
      debugPrint("Error fetching questions: $e");
    }
  }

  bool _allQuestionsAnswered() =>
      questionOrder.every((id) => userAnswers.containsKey(id));

  int _firstUnansweredIndex() =>
      questionOrder.indexWhere((id) => !userAnswers.containsKey(id));

  void _loadQuestionFromIndex(int index) {
    if (index < 0 || index >= allQuestions.length) return;

    final doc = allQuestions[index];
    final data = doc.data() as Map<String, dynamic>;

    setState(() {
      currentQuestionIndex = index;
      currentDocId = doc.id;
      question = data['text'] ?? "How many objects do you see?";
      imageCount = int.tryParse(data['numberField']?.toString() ?? "0") ?? 0;
      imageAssets = List.generate(
          imageCount,
              (_) => _random.nextBool()
              ? 'assets/circle.png'
              : 'assets/triangle.png');
      options = (data['options'] as List)
          .map((o) => {...(o as Map<String, dynamic>), 'selected': false})
          .toList();

      final savedAnswer = userAnswers[doc.id];
      if (savedAnswer != null) {
        final savedIndex = savedAnswer['selectedOptionIndex'] as int?;
        if (savedIndex != null && savedIndex < options.length) {
          options[savedIndex]['selected'] = true;
        }
      }
    });
  }

  void _checkAnswer(int index) {
    if (userAnswers.containsKey(currentDocId)) return;

    final isCorrect = options[index]['isCorrect'] == true;
    setState(() {
      options[index]['selected'] = true;
      if (isCorrect) {
        score++;
        correctCount++;
      } else {
        incorrectCount++;
      }
      userAnswers[currentDocId] = {
        'selectedOptionIndex': index,
        'isCorrect': isCorrect,
      };
    });
    _saveGameState();
  }

  Future<void> _onFinishPressed() async {
    await _saveGameState();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          gameTitle: gameKey,
          score: score,
          correctCount: correctCount,
          incorrectCount: incorrectCount,
        ),
      ),
    );
  }

  void _goToPreviousQuestion() {
    if (currentQuestionIndex > 0) {
      _loadQuestionFromIndex(currentQuestionIndex - 1);
    }
  }

  void _goToNextQuestion() {
    if (_allQuestionsAnswered()) {
      _onFinishPressed();
    } else if (currentQuestionIndex < allQuestions.length - 1) {
      _loadQuestionFromIndex(currentQuestionIndex + 1);
    }
  }

  void showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Instructions"),
          content: const Text(
            "1. Answer all questions in order.\n"
                "2. Answered questions are marked.\n"
                "3. Progress is saved automatically.\n"
                "4. Finish all questions to see results.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
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
            const Text("Let Us Count", style: TextStyle(fontSize: 22)),
            IconButton(
              icon: const Icon(Icons.info_outline),
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
              question,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              children: imageAssets
                  .map((asset) => Image.asset(
                asset,
                width: 50,
                height: 50,
              ))
                  .toList(),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  childAspectRatio: 1.5,
                ),
                itemBuilder: (context, index) => _buildOptionCard(index),
              ),
            ),
            const SizedBox(height: 15),
            Column(
              children: [
                Text(
                  "Score: $score",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Correct: $correctCount | Incorrect: $incorrectCount",
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _goToPreviousQuestion,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15)),
                  child: const Text("Previous"),
                ),
                ElevatedButton(
                  onPressed: _allQuestionsAnswered()
                      ? _onFinishPressed
                      : _goToNextQuestion,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15)),
                  child: Text(_allQuestionsAnswered() ? "Finish" : "Next"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(int index) {
    final option = options[index];
    final isSelected = option['selected'] == true;
    final isCorrect = option['isCorrect'] == true;

    return GestureDetector(
      onTap: () {
        if (!userAnswers.containsKey(currentDocId)) {
          _checkAnswer(index);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: isSelected
              ? Border.all(
            color: isCorrect ? Colors.green : Colors.red,
            width: 4,
          )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Text(
            option['description'] ?? "",
            style: TextStyle(
              fontSize: 24,
              color: isSelected
                  ? (isCorrect ? Colors.green : Colors.red)
                  : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
