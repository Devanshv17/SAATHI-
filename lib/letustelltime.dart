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
  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;

  List<QueryDocumentSnapshot> allQuestions = [];
  List<String> questionOrder = [];
  int currentQuestionIndex = -1;
  String currentDocId = '';
  Map<String, dynamic> userAnswers = {};

  String question = '';
  DateTime? clockTime;
  List<Map<String, dynamic>> options = [];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final Random _random = Random();

  final String gameKey = 'Let us Tell Time';

  @override
  void initState() {
    super.initState();
    _loadGameState().then((_) => _fetchQuestions());
  }

  /// Load saved game state from RTDB.
  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final snap = await _dbRef.child('users/${user.uid}/games/$gameKey').get();
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

  /// Persist state to RTDB.
  Future<void> _saveGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _dbRef.child('users/${user.uid}/games/$gameKey').update({
      'score': score,
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'answers': userAnswers,
      'questionOrder': questionOrder,
    });
  }

  /// Fetches all questions, initializes order, and loads the first unanswered.
  Future<void> _fetchQuestions() async {
    try {
      final snap = await _firestore
          .collection('Let us Tell Time')
          .get(const GetOptions(source: Source.serverAndCache));
      allQuestions = snap.docs;
      if (allQuestions.isEmpty) return;

      if (questionOrder.isEmpty) {
        final answered = allQuestions
            .where((d) => userAnswers.containsKey(d.id))
            .map((d) => d.id)
            .toList();
        final unanswered = allQuestions
            .where((d) => !userAnswers.containsKey(d.id))
            .map((d) => d.id)
            .toList();
        questionOrder = [...answered, ...unanswered];
        await _saveGameState();
      }

      if (_allAnswered()) {
        _navigateToResult();
        return;
      }

      _loadQuestion(questionOrder.indexWhere(
            (id) => !userAnswers.containsKey(id),
      ));
    } catch (e) {
      debugPrint('Error fetching questions: $e');
    }
  }

  bool _allAnswered() =>
      questionOrder.isNotEmpty && questionOrder.every((id) => userAnswers.containsKey(id));

  void _loadQuestion(int orderIndex) {
    if (orderIndex < 0 || orderIndex >= questionOrder.length) return;
    final docId = questionOrder[orderIndex];
    final doc = allQuestions.firstWhere((d) => d.id == docId);
    final data = doc.data() as Map<String, dynamic>;

    final text = data['text'] ?? 'What time is shown?';
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(text);
    DateTime time = DateTime(2025, 1, 1, 0, 0);
    if (match != null) {
      time = DateTime(
        2025,
        1,
        1,
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
      );
    }

    final opts = List<Map<String, dynamic>>.from(data['options'] as List)
        .map((o) => {...o, 'selected': false})
        .toList();
    final saved = userAnswers[docId];
    if (saved != null) {
      final idx = saved['selectedOptionIndex'] as int;
      if (idx < opts.length) opts[idx]['selected'] = true;
    }

    setState(() {
      currentQuestionIndex = orderIndex;
      currentDocId = docId;
      question = text;
      clockTime = time;
      options = opts;
    });
  }

  void _checkAnswer(int index) {
    if (userAnswers.containsKey(currentDocId)) return;
    final formatted1 = DateFormat('H:mm').format(clockTime!);
    final formatted2 = DateFormat('HH:mm').format(clockTime!);
    final isCorrect =
        options[index]['title'] == formatted1 || options[index]['title'] == formatted2;
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

  void _goPrev() {
    if (currentQuestionIndex > 0) {
      _loadQuestion(currentQuestionIndex - 1);
    }
  }

  void _goNext() {
    if (_allAnswered()) {
      _navigateToResult();
    } else if (currentQuestionIndex < questionOrder.length - 1) {
      _loadQuestion(currentQuestionIndex + 1);
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
        title: const Text('Let Us Tell Time', style: TextStyle(fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Instructions'),
                  content: const Text(
                    '1. Tap the correct time.\n'
                        '2. Progress is saved automatically.\n'
                        '3. Finish all questions to see results.',
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
          children: [
            if (clockTime != null)
              Center(
                child: Container(
                  width: 180,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12, offset: Offset(2, 2))],
                  ),
                  child: ClipOval(
                    child: AnalogClock(key: ValueKey(clockTime), dateTime: clockTime!),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.2,
                ),
                itemBuilder: (_, i) {
                  final opt = options[i];
                  final sel = opt['selected'] as bool;
                  final saved = userAnswers[currentDocId];
                  final corr = saved != null && saved['selectedOptionIndex'] == i && saved['isCorrect'] == true;
                  return GestureDetector(
                    onTap: sel ? null : () => _checkAnswer(i),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: sel ? Border.all(color: corr ? Colors.green : Colors.red, width: 3) : null,
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 3, spreadRadius: 1)],
                      ),
                      child: Center(
                        child: Text(opt['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: currentQuestionIndex > 0 ? _goPrev : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentQuestionIndex > 0 ? Colors.orange : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: const Text('Previous',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                   ),
                ),
                ElevatedButton(
                  onPressed: _allAnswered() ? _navigateToResult : _goNext,
                  style: ElevatedButton.styleFrom(
                     backgroundColor: options.any((o) => o['selected'] == true)
                        ? Colors.green
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  child: Text( 'Next',  style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
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
