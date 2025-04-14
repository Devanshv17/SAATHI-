import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart';

class GuessTheLetterPage extends StatefulWidget {
  const GuessTheLetterPage({Key? key}) : super(key: key);

  @override
  _GuessTheLetterPageState createState() => _GuessTheLetterPageState();
}

class _GuessTheLetterPageState extends State<GuessTheLetterPage> {
  // Current question data
  String questionText = "";
  String currentDocId = "";
  List<Map<String, dynamic>> options = [];

  // Scoring and answer tracking
  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;
  String? imageUrl;
  Map<String, dynamic> userAnswers = {};

  // Order of questions (answered first, then unanswered)
  List<String> questionOrder = [];
  List<QueryDocumentSnapshot> allQuestions = [];
  int currentQuestionIndex = 0;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _loadGameState().then((_) => _fetchQuestionsInOrder());
  }

  // Load saved game state (score, counts, answers, questionOrder) from Realtime DB
  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final snapshot = await _dbRef
          .child("users/${user.uid}/games/Guess the Letter")
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
          if (data['questionOrder'] != null) {
            questionOrder = List<String>.from(data['questionOrder']);
          }
        });
      } else {
        print("No existing game state for Guess the Letter.");
      }
    } catch (e) {
      print("Error loading game state: $e");
    }
  }

  // Save current game state to Realtime DB
  Future<void> _saveGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _dbRef.child("users/${user.uid}/games/Guess the Letter").update({
        "score": score,
        "correctCount": correctCount,
        "incorrectCount": incorrectCount,
        "answers": userAnswers,
        "questionOrder": questionOrder,
      });
      print("Saved game state: score=$score, correct=$correctCount, incorrect=$incorrectCount");
    } catch (e) {
      print("Error saving game state: $e");
    }
  }

  // Fetch questions from Firestore and reorder them based on whether they are answered
  Future<void> _fetchQuestionsInOrder() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Guess the Letter')
          .get();

      // Create a map of question docID -> document snapshot.
      Map<String, QueryDocumentSnapshot> questionMap = {
        for (var doc in snapshot.docs) doc.id: doc
      };

      if (questionOrder.isEmpty) {
        // First load: split questions into answered and unanswered.
        List<String> answered = [];
        List<String> unanswered = [];

        for (var doc in snapshot.docs) {
          if (userAnswers.containsKey(doc.id)) {
            answered.add(doc.id);
          } else {
            unanswered.add(doc.id);
          }
        }
        questionOrder = [...answered, ...unanswered];
        await _saveGameState();
      }

      // Check if all questions are answered. If so, go straight to result.
      bool allAnswered = questionOrder.every((id) => userAnswers.containsKey(id));
      if (allAnswered) {
        _navigateToResult();
        return;
      }

      setState(() {
        allQuestions = questionOrder
            .map((id) => questionMap[id])
            .where((doc) => doc != null)
            .cast<QueryDocumentSnapshot>()
            .toList();

        // Start at the first unanswered question:
        int startIndex = _firstUnansweredIndex();
        _loadQuestionFromIndex(startIndex);
      });
    } catch (e) {
      print("Error fetching questions: $e");
    }
  }

  // Returns the index of the first unanswered question.
  int _firstUnansweredIndex() {
    for (int i = 0; i < questionOrder.length; i++) {
      if (!userAnswers.containsKey(questionOrder[i])) {
        return i;
      }
    }
    return 0; // Fallback in case all are answered
  }

  // Load a question based on its index in the ordered list.
  void _loadQuestionFromIndex(int index) {
    if (index < 0 || index >= allQuestions.length) return;

    final doc = allQuestions[index];
    final data = doc.data() as Map<String, dynamic>;
    setState(() {
      currentQuestionIndex = index;
      currentDocId = doc.id;
      questionText = data['text'] ?? "Question";
      imageUrl = data['imageUrl']; // Assign the image URL here.
      options = List<Map<String, dynamic>>.from(data['options'] ?? []);
      // Reset selected flags for the options.
      for (var opt in options) {
        opt['selected'] = false;
      }
      // If the question was already answered, restore the selected option.
      if (userAnswers.containsKey(doc.id)) {
        final savedAnswer = userAnswers[doc.id];
        final savedIndex = savedAnswer['selectedOptionIndex'] as int?;
        if (savedIndex != null && savedIndex < options.length) {
          options[savedIndex]['selected'] = true;
        }
      }
    });
  }


  // Navigate to previous question (if available)
  void _goToPreviousQuestion() {
    if (currentQuestionIndex > 0) {
      _loadQuestionFromIndex(currentQuestionIndex - 1);
    }
  }

  // Navigate to next question or to result page if done.
  void _goToNextQuestion() {
    if (currentQuestionIndex < allQuestions.length - 1) {
      _loadQuestionFromIndex(currentQuestionIndex + 1);
    } else {
      _navigateToResult();
    }
  }

  // Navigate to the result page.
  void _navigateToResult() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          gameTitle: "Guess the Letter",
          score: score,
          correctCount: correctCount,
          incorrectCount: incorrectCount,
        ),
      ),
    );
  }

  // Handles answer selection.
  void checkAnswer(int index) {
    if (userAnswers.containsKey(currentDocId)) return; // Lock question if answered.

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

  // Instruction dialog.
  void showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Instructions"),
        content: const Text(
          "1. Tap the correct option.\n"
              "2. A green border means correct, red means wrong.\n"
              "3. Your score increases only for correct answers.\n"
              "4. Use 'Previous' or 'Next' to navigate through questions.\n"
              "5. Answered questions are not repeated.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it!"),
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
            const Text(
              "Guess the Letter",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white, size: 28),
              onPressed: () => showInstructions(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              questionText.isNotEmpty ? questionText : "Loading question...",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            if (imageUrl != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.network(
                    imageUrl!,
                    height: 120,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, index) => buildOptionCard(options[index], index),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "Your Score: $score",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentQuestionIndex > 0 ? Colors.orange : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: currentQuestionIndex > 0 ? _goToPreviousQuestion : null,
                  child: const Text(
                    "Previous",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: options.any((o) => o['selected'] == true) ? Colors.green : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: options.any((o) => o['selected'] == true) ? _goToNextQuestion : null,
                  child: const Text(
                    "Next",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOptionCard(Map<String, dynamic> option, int index) {
    bool isSelected = option['selected'] == true;
    bool isCorrect = option['isCorrect'] == true;
    return GestureDetector(
      onTap: isSelected ? null : () => checkAnswer(index),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                color: isCorrect ? Colors.green : Colors.red,
                width: 4,
              )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                option['title'],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (isSelected &&
              option['description'] != null &&
              option['description'] != "")
            Positioned(
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  option['description'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
