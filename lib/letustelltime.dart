import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_analog_clock/flutter_analog_clock.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart';

class LetUsTellTimePage extends StatefulWidget {
  const LetUsTellTimePage({Key? key}) : super(key: key);

  @override
  _LetUsTellTimePageState createState() => _LetUsTellTimePageState();
}

class _LetUsTellTimePageState extends State<LetUsTellTimePage> {
  // Game state variables
  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;

  // Questions & Navigation
  List<QueryDocumentSnapshot> allQuestions = [];
  List<String> questionOrder = [];
  int currentQuestionIndex = -1;
  String currentDocId = '';
  Map<String, dynamic> userAnswers = {};

  // Current question data
  String question = '';
  DateTime? clockTime;
  List<Map<String, dynamic>> options = [];

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Realtime Database reference
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Use the same game key as expected by the homepage:
  final String gameKey = "Let us Tell Time";

  @override
  void initState() {
    super.initState();
    _loadGameState().then((_) => _fetchQuestionsInOrder());
  }

  /// Loads saved game state from Firestore.
  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final doc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .doc(gameKey)
        .get();
    if (!doc.exists) return;
    final data = doc.data()!;
    setState(() {
      score = data['score'] ?? 0;
      correctCount = data['correctCount'] ?? 0;
      incorrectCount = data['incorrectCount'] ?? 0;
      userAnswers = Map<String, dynamic>.from(data['answers'] ?? {});
      questionOrder = List<String>.from(data['questionOrder'] ?? []);
    });
  }

  /// Saves the current game state to Firestore and Realtime Database.
  Future<void> _saveGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;
    Map<String, dynamic> gameState = {
      'score': score,
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'answers': userAnswers,
      'questionOrder': questionOrder,
    };
    // Save under key "Let us Tell Time" in Firestore.
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('games')
        .doc(gameKey)
        .set(gameState);
    // Also update the Realtime Database node so the homepage shows the updated game state.
    await _dbRef.child("users/${user.uid}/games/$gameKey").update(gameState);
  }

  /// Fetch questions from Firestore and set up the question order.
  Future<void> _fetchQuestionsInOrder() async {
    try {
      final snapshot = await _firestore
          .collection('Let us Tell Time')
          .get(const GetOptions(source: Source.serverAndCache));
      allQuestions = snapshot.docs;
      if (allQuestions.isEmpty) return;

      // Initialize question order if first launch.
      if (questionOrder.isEmpty) {
        final answeredIds = allQuestions
            .where((d) => userAnswers.containsKey(d.id))
            .map((d) => d.id)
            .toList();
        final unansweredIds = allQuestions
            .where((d) => !userAnswers.containsKey(d.id))
            .map((d) => d.id)
            .toList();
        questionOrder = [...answeredIds, ...unansweredIds];
        await _saveGameState();
      }

      // If all questions are answered, finish the game.
      if (_allQuestionsAnswered()) {
        _onFinishPressed();
        return;
      }
      // Load the first unanswered question.
      _loadQuestionFromIndex(_firstUnansweredIndex());
    } catch (e) {
      debugPrint('Error fetching questions: $e');
    }
  }

  bool _allQuestionsAnswered() =>
      questionOrder.every((id) => userAnswers.containsKey(id));

  int _firstUnansweredIndex() =>
      questionOrder.indexWhere((id) => !userAnswers.containsKey(id));

  /// Loads the question at the given index.
  void _loadQuestionFromIndex(int orderIndex) {
    if (orderIndex < 0 || orderIndex >= questionOrder.length) return;
    final docId = questionOrder[orderIndex];
    final doc = allQuestions.firstWhere((d) => d.id == docId);
    final data = doc.data() as Map<String, dynamic>;

    // Parse the question text and the time.
    final text = data['text'] ?? 'What time is shown?';
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(text);
    DateTime parsedTime = DateTime(2025, 1, 1, 10, 30);
    if (match != null) {
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      parsedTime = DateTime(2025, 1, 1, hour, minute);
    }

    // Prepare options and restore any saved selection.
    final fetchedOptions =
    List<Map<String, dynamic>>.from(data['options'] as List)
        .map((o) => {...o, 'selected': false})
        .toList();
    final saved = userAnswers[docId];
    if (saved != null) {
      final idx = saved['selectedOptionIndex'] as int?;
      if (idx != null && idx < fetchedOptions.length) {
        fetchedOptions[idx]['selected'] = true;
      }
    }

    setState(() {
      currentQuestionIndex = orderIndex;
      currentDocId = docId;
      question = text;
      clockTime = parsedTime;
      options = fetchedOptions;
    });
  }

  /// Called when an option is tapped.
  void _checkAnswer(int index) {
    if (userAnswers.containsKey(currentDocId)) return;
    final selected = options[index];
    final correctStr = DateFormat('H:mm').format(clockTime!);
    final altStr = DateFormat('HH:mm').format(clockTime!);
    final isCorrect = (selected['title'] == correctStr || selected['title'] == altStr);
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

  /// Navigate to the previous question.
  void _goToPreviousQuestion() {
    if (currentQuestionIndex > 0) {
      _loadQuestionFromIndex(currentQuestionIndex - 1);
    }
  }

  /// Navigate to the next question or finish if all have been answered.
  void _goToNextQuestion() {
    if (_allQuestionsAnswered()) {
      _onFinishPressed();
    } else if (currentQuestionIndex < questionOrder.length - 1) {
      _loadQuestionFromIndex(currentQuestionIndex + 1);
    }
  }

  /// Finish game: save state and navigate to the ResultPage.
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

  /// Builds the option card UI.
  Widget _buildOptionCard(int index) {
    final opt = options[index];
    final isSelected = opt['selected'] as bool;
    bool isCorrect = false;
    final saved = userAnswers[currentDocId];
    if (saved != null && saved['selectedOptionIndex'] == index) {
      isCorrect = saved['isCorrect'] as bool;
    }
    return GestureDetector(
      onTap: isSelected ? null : () => _checkAnswer(index),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
            color: isCorrect ? Colors.green : Colors.red,
            width: 3,
          )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 3,
              spreadRadius: 1,
            )
          ],
        ),
        child: Center(
          child: Text(
            opt['title'],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
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
            const Text('Let Us Tell Time', style: TextStyle(fontSize: 22)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Instructions'),
                  content: const Text(
                    '1. Answer all questions in order\n'
                        '2. Progress is saved automatically\n'
                        '3. Finish all questions to see results',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (clockTime != null)
              Center(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                          blurRadius: 4,
                          color: Colors.black12,
                          offset: Offset(2, 2)),
                    ],
                  ),
                  child: ClipOval(
                    child: AnalogClock(
                      key: ValueKey(clockTime),
                      dateTime: clockTime!,
                      dialColor: Colors.white,
                      hourHandColor: Colors.black,
                      minuteHandColor: Colors.black,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (ctx, idx) => _buildOptionCard(idx),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Score: $score',
                style:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: currentQuestionIndex > 0
                      ? _goToPreviousQuestion
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentQuestionIndex > 0
                        ? Colors.orange
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Previous',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: _allQuestionsAnswered()
                      ? _onFinishPressed
                      : _goToNextQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allQuestionsAnswered()
                        ? Colors.blue
                        : Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(
                    _allQuestionsAnswered() ? 'Finish' : 'Next',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
