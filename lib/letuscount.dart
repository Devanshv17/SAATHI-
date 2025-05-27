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

  /// Load saved game state from Realtime Database (mirroring GuessTheLetter)
  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snap = await _dbRef.child("users/${user.uid}/games/$gameKey").get();
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      setState(() {
        score = data['score'] ?? 0;
        correctCount = data['correctCount'] ?? 0;
        incorrectCount = data['incorrectCount'] ?? 0;
        userAnswers = Map<String, dynamic>.from(data['answers'] ?? {});
        questionOrder = List<String>.from(data['questionOrder'] ?? []);
      });
    }
  }

  /// Save game state only to Realtime Database
  Future<void> _saveGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _dbRef.child("users/${user.uid}/games/$gameKey").update({
      "score": score,
      "correctCount": correctCount,
      "incorrectCount": incorrectCount,
      "answers": userAnswers,
      "questionOrder": questionOrder,
    });
  }

  Future<void> _fetchQuestionsInOrder() async {
    try {
      final snapshot = await _firestore
          .collection('Let us Count')
          .get(const GetOptions(source: Source.serverAndCache));

      allQuestions = snapshot.docs;
      if (allQuestions.isEmpty) return;

      // First load: build or persist questionOrder
      if (questionOrder.isEmpty) {
        final answered = allQuestions
            .where((doc) => userAnswers.containsKey(doc.id))
            .map((doc) => doc.id)
            .toList();
        final unanswered = allQuestions
            .where((doc) => !userAnswers.containsKey(doc.id))
            .map((doc) => doc.id)
            .toList();

        questionOrder = [...answered, ...unanswered];
        await _saveGameState();
      }

      // Only navigate to result when user has answered all
      bool allDone = questionOrder.every((id) => userAnswers.containsKey(id));
      if (allDone) {
        _navigateToResult();
        return;
      }

      _loadQuestionFromIndex(questionOrder.indexWhere(
            (id) => !userAnswers.containsKey(id),
      ));
    } catch (e) {
      debugPrint("Error fetching questions: $e");
    }
  }

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
            (_) => _random.nextBool() ?
        'assets/circle.png' : 'assets/triangle.png',
      );
      options = (data['options'] as List)
          .map((o) => {...(o as Map<String, dynamic>), 'selected': false})
          .toList();

      // Restore saved selection
      final saved = userAnswers[doc.id];
      if (saved != null) {
        int idx = saved['selectedOptionIndex'] as int;
        if (idx < options.length) options[idx]['selected'] = true;
      }
    });
  }

  void _checkAnswer(int index) {
    if (userAnswers.containsKey(currentDocId)) return;
    bool isCorrect = options[index]['isCorrect'] == true;
    setState(() {
      options[index]['selected'] = true;
      if (isCorrect) { score++; correctCount++; } else { incorrectCount++; }
      userAnswers[currentDocId] = {
        'selectedOptionIndex': index,
        'isCorrect': isCorrect,
      };
    });
    _saveGameState();
  }

  void _navigateToResult() {
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
    if (options.any((o) => o['selected'] == true)) {
      // Move or finish
      bool allDone = questionOrder.every((id) => userAnswers.containsKey(id));
      if (allDone) {
        _navigateToResult();
      } else if (currentQuestionIndex < allQuestions.length - 1) {
        _loadQuestionFromIndex(currentQuestionIndex + 1);
      }
    }
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
            const Text("Let Us Count",  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {/* instructions */},
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Text(question, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 17),
          Wrap(
            spacing: 10,
            children: imageAssets.map((asset) => Image.asset(asset, width: 45, height: 45)).toList(),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              itemCount: options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 1.5,
              ),
              itemBuilder: (context, i) {
                final o = options[i];
                bool sel = o['selected'];
                bool corr = o['isCorrect'] == true;
                return GestureDetector(
                  onTap: sel ? null : () => _checkAnswer(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: sel ? Border.all(color: corr ? Colors.green : Colors.red, width: 4) : null,
                      boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 2, blurRadius: 5)],
                    ),
                    child: Center(
                      child: Text(
                        o['description'] ?? '',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                          color: sel ? (corr ? Colors.green : Colors.red) : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        
          const SizedBox(height: 15),
          Center(
            child: Column(
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
          ),

          const SizedBox(height: 15),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            ElevatedButton(
              onPressed: _goToPreviousQuestion, 
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                        currentQuestionIndex > 0 ? Colors.orange : Colors.grey,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
                 child: const Text("Previous",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                )),
            ElevatedButton(onPressed: _goToNextQuestion, 
            style: ElevatedButton.styleFrom(
               backgroundColor: options.any((o) => o['selected'] == true)
                        ? Colors.green
                        : Colors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)), 
              child: const Text("Next",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                )),
          ]),
        ]),
      ),
    );
  }
}