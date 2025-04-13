import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart';

class MatchingPage extends StatefulWidget {
  final String gameTitle;
  const MatchingPage({Key? key, required this.gameTitle}) : super(key: key);

  @override
  _MatchingPageState createState() => _MatchingPageState();
}

class _MatchingPageState extends State<MatchingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;
  Map<String, dynamic> userAnswers =
      {}; // key: question id, value: {selectedOptionIndex, isCorrect}
  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;
  bool answered = false;

  @override
  void initState() {
    super.initState();
    _loadGameState().then((_) => loadQuestions());
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
          currentQuestionIndex = data['currentQuestionIndex'] ?? 0;
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
        "currentQuestionIndex": currentQuestionIndex,
      });
    } catch (e) {
      print("Error saving game state: $e");
    }
  }

  Future<void> loadQuestions() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(widget.gameTitle)
          .orderBy('timestamp')
          .get();

      questions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final questionText = data['text'] as String? ?? "No question text";
        final rawOptions = data['options'] as List<dynamic>? ?? [];

        final parsedOptions = rawOptions.map((opt) {
          final optionMap = opt as Map<String, dynamic>;
          final optionTitle =
              optionMap['title'] as String? ?? "No option title";
          final isCorrect = optionMap['isCorrect'] as bool? ?? false;
          return {
            'title': optionTitle,
            'isCorrect': isCorrect,
          };
        }).toList();

        return {
          'id': doc.id,
          'text': questionText,
          'options': parsedOptions,
        };
      }).toList();

      setState(() {
        // If the current question was already answered, mark the answered flag.
        if (questions.isNotEmpty &&
            userAnswers.containsKey(questions[currentQuestionIndex]['id'])) {
          answered = true;
        } else {
          answered = false;
        }
      });
    } catch (e) {
      print("Error loading questions: $e");
    }
  }

  void _selectOption(int optionIndex) {
    if (answered) return;

    final currentQuestion = questions[currentQuestionIndex];
    final String questionId = currentQuestion['id'];
    final options = currentQuestion['options'] as List<dynamic>;
    bool isCorrect = options[optionIndex]['isCorrect'] as bool? ?? false;

    setState(() {
      answered = true;
      userAnswers[questionId] = {
        "selectedOptionIndex": optionIndex,
        "isCorrect": isCorrect,
      };
      if (isCorrect) {
        score++;
        correctCount++;
      } else {
        incorrectCount++;
      }
    });
    _saveGameState();
  }

  void _previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
        final currentQuestion = questions[currentQuestionIndex];
        answered = userAnswers.containsKey(currentQuestion['id']);
      });
      _saveGameState();
    }
  }

  void _nextQuestion() {
    // Do not proceed if the current question hasn't been answered
    if (!userAnswers.containsKey(questions[currentQuestionIndex]['id'])) return;
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        final currentQuestion = questions[currentQuestionIndex];
        answered = userAnswers.containsKey(currentQuestion['id']);
      });
      _saveGameState();
    } else {
      _navigateToResult();
    }
  }

  void _navigateToResult() {
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
  }

  void _showInstructionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Instructions"),
        content: const Text(
          "• Select the correct option.\n"
          "• Correct: Green border + Tick.\n"
          "• Incorrect: Red border + Cross.\n"
          "• Use Next/Previous to navigate.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.gameTitle),
          backgroundColor: Colors.indigo,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showInstructionsDialog,
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentQuestion = questions[currentQuestionIndex];
    final questionText = currentQuestion['text'] as String;
    final options = currentQuestion['options'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gameTitle),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInstructionsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                questionText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: GridView.builder(
                  itemCount: options.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.1,
                  ),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    bool isSelected = false;
                    bool isCorrect = option['isCorrect'] as bool? ?? false;

                    if (userAnswers.containsKey(currentQuestion['id'])) {
                      isSelected = userAnswers[currentQuestion['id']]
                              ['selectedOptionIndex'] ==
                          index;
                    }

                    Color borderColor = Colors.grey;
                    Widget? icon;

                    if (isSelected && answered) {
                      borderColor = isCorrect ? Colors.green : Colors.red;
                      icon = Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red,
                      );
                    }

                    return ElevatedButton(
                      onPressed: answered ? null : () => _selectOption(index),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: isSelected && answered
                            ? Colors.grey.shade300
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: borderColor,
                            width: 3,
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        elevation: 3,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              option['title'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          if (icon != null)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: icon,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed:
                        currentQuestionIndex > 0 ? _previousQuestion : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Previous"),
                  ),
                  Text(
                    "Score: $score",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: userAnswers.containsKey(currentQuestion['id'])
                        ? _nextQuestion
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Next"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
