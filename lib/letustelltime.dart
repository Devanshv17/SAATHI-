// letustelltime.dart
import 'dart:math';
import 'dart:ui'; // for ImageFilter
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_analog_clock/flutter_analog_clock.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart';

class LetUsTellTimePage extends StatefulWidget {
  final String gameTitle;
  final bool isHindi;
  const LetUsTellTimePage({
    Key? key,
    required this.gameTitle,
    required this.isHindi,
  }) : super(key: key);

  @override
  _LetUsTellTimePageState createState() => _LetUsTellTimePageState();
}

class _LetUsTellTimePageState extends State<LetUsTellTimePage> {
  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;
  int currentQuestionIndex = 0;
  DateTime? _questionStartTime;
  DateTime? _gameStartTime;

  List<QueryDocumentSnapshot> allQuestions = [];
  Map<String, dynamic> userAnswers = {};

  String currentDocId = '';
  String question = '';
  DateTime? clockTime;
  List<Map<String, dynamic>> options = [];

  int? _pendingSelectedIndex;
  bool _hasSubmitted = false;
  bool _currentIsCorrect = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _gameStartTime = DateTime.now();
    _loadGameState().then((_) => _fetchQuestions());
  }

  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final snap =
        await _dbRef.child("users/${user.uid}/games/${widget.gameTitle}").get();
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      setState(() {
        score = data['score'] ?? 0;
        correctCount = data['correctCount'] ?? 0;
        incorrectCount = data['incorrectCount'] ?? 0;
        currentQuestionIndex = data['currentQuestionIndex'] ?? 0;
        userAnswers = Map<String, dynamic>.from(data['answers'] ?? {});
      });
    }
  }

  Future<void> _saveGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _dbRef.child("users/${user.uid}/games/${widget.gameTitle}").update({
      'score': score,
      'correctCount': correctCount,
      'incorrectCount': incorrectCount,
      'currentQuestionIndex': currentQuestionIndex,
      'answers': userAnswers,
    });
  }
  Future<void> _recordGameVisit() async {
    final user = _auth.currentUser;
    final start = _gameStartTime;
    if (user == null || start == null) return;

    final now = DateTime.now();
    final seconds = now.difference(start).inSeconds;
    final dateKey = now.toIso8601String().substring(0, 10); // “YYYY-MM-DD”

    // Path in your Realtime DB:
    final path =
        "users/${user.uid}/games/${widget.gameTitle}/gameVisits/$dateKey";

    // 1) Read previous total (or zero)
    final snap = await _dbRef.child(path).get();
    final prev = (snap.exists && snap.value is int) ? snap.value as int : 0;

    // 2) Write updated total
    await _dbRef.child(path).set(prev + seconds);
  }


  Future<void> _fetchQuestions() async {
    try {
      final snap = await _firestore
          .collection(widget.gameTitle)
          .orderBy('timestamp')
          .get();
      allQuestions = snap.docs;

      if (currentQuestionIndex >= allQuestions.length) {
        _navigateToResult();
      } else {
        _loadQuestion(currentQuestionIndex);
      }
    } catch (e) {
      debugPrint('Error fetching questions: $e');
    }
  }

  void _loadQuestion(int index) {
    if (index < 0 || index >= allQuestions.length) return;
    final doc = allQuestions[index];
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

    final saved = userAnswers[doc.id];
    if (saved != null) {
      final idx = saved['selectedOptionIndex'] as int;
      final wasCorrect = saved['isCorrect'] as bool;
      _pendingSelectedIndex = idx;
      _hasSubmitted = true;
      _currentIsCorrect = wasCorrect;
      if (idx < opts.length) opts[idx]['selected'] = true;
    } else {
      _pendingSelectedIndex = null;
      _hasSubmitted = false;
      _currentIsCorrect = false;
    }

    setState(() {
      currentDocId = doc.id;
      currentQuestionIndex = index;
      question = text;
      clockTime = time;
      options = opts;
      _questionStartTime = DateTime.now(); // Start timing here
    });
  }

  void _selectOption(int index) {
    if (_hasSubmitted) return;
    setState(() {
      _pendingSelectedIndex = index;
      for (var i = 0; i < options.length; i++) {
        options[i]['selected'] = false;
      }
      options[index]['selected'] = true;
    });
  }

  void _submitAnswer() {
    if (_pendingSelectedIndex == null || _hasSubmitted) return;
    final isCorrect = options[_pendingSelectedIndex!]['isCorrect'] as bool;
    final duration = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!)
        : Duration.zero;

    setState(() {
      _hasSubmitted = true;
      _currentIsCorrect = isCorrect;
      options[_pendingSelectedIndex!]['selected'] = true;
      userAnswers[currentDocId] = {
        'selectedOptionIndex': _pendingSelectedIndex,
        'isCorrect': isCorrect,
        'timeTakenSeconds': duration.inSeconds,
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

  void _goPrev() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
        _hasSubmitted = false;
      });
      _loadQuestion(currentQuestionIndex);
    }
  }

  void _goNext() {
    if (!_hasSubmitted && !userAnswers.containsKey(currentDocId)) return;
    if (currentQuestionIndex < allQuestions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        _hasSubmitted = false;
      });
      _loadQuestion(currentQuestionIndex);
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
          isHindi: widget.isHindi,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _saveGameState();
    _recordGameVisit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        backgroundColor: Colors.blue.shade300,
        title: Text(
          widget.gameTitle,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(widget.isHindi ? "निर्देश" : "Instructions"),
                content: Text(
                  widget.isHindi
                      ? "१. विकल्प चुनें (नीला बॉर्डर)।\n"
                          "२. जमा करें पर टैप करें।\n"
                          "३. सही: हरा टिक; गलत: लाल क्रॉस।\n"
                          "४. Prev/Next बटन से जाएं।\n"
                          "५. प्रगति सेव हो जाती है।"
                      : "1. Tap an option (blue border).\n"
                          "2. Tap Submit.\n"
                          "3. Correct: green tick; incorrect: red cross.\n"
                          "4. Use Previous/Next.\n"
                          "5. Progress is saved.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(widget.isHindi ? "ठीक है" : "Got it!"),
                  )
                ],
              ),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              widget.isHindi ? "सही समय चुनें" : "Select the correct time",
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 10),
            if (clockTime != null)
              Container(
                width: 180,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                  boxShadow: const [
                    BoxShadow(
                        blurRadius: 4,
                        color: Colors.black12,
                        offset: Offset(2, 2)),
                  ],
                ),
                child: ClipOval(
                  child: AnalogClock(
                      key: ValueKey(clockTime), dateTime: clockTime!),
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
                  childAspectRatio: 1.4,
                ),
                itemBuilder: (_, i) {
                  final opt = options[i];
                  final isPending =
                      (_pendingSelectedIndex == i && !_hasSubmitted);
                  final showResult =
                      (_pendingSelectedIndex == i && _hasSubmitted);
                  final isCorrect = _hasSubmitted && _pendingSelectedIndex == i
                      ? _currentIsCorrect
                      : false;

                  Color borderColor = Colors.white10;
                  if (isPending) {
                    borderColor = Colors.blue;
                  } else if (showResult) {
                    borderColor = isCorrect ? Colors.green : Colors.red;
                  }

                  return GestureDetector(
                    onTap: _hasSubmitted ? null : () => _selectOption(i),
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor, width: 3),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 3,
                                  spreadRadius: 1)
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Center(
                                    child: Text(
                                      opt['title'] as String,
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                if (showResult)
                                  Positioned.fill(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 1, sigmaY: 1),
                                      child: Container(
                                        color: Colors.black.withOpacity(0.2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (showResult)
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              color: isCorrect ? Colors.green : Colors.red,
                              size: 50,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.isHindi ? "अंक: $score" : "Score: $score",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.isHindi
                  ? "सही: $correctCount | गलत: $incorrectCount"
                  : "Correct: $correctCount | Incorrect: $incorrectCount",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: currentQuestionIndex > 0 ? _goPrev : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        currentQuestionIndex > 0 ? Colors.orange : Colors.grey,
                  ),
                  child: Text(widget.isHindi ? "पिछला" : "Previous",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: (_pendingSelectedIndex != null && !_hasSubmitted)
                      ? _submitAnswer
                      : null,
                  child: Text(widget.isHindi ? "जमा करें" : "Submit",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                ),
                ElevatedButton(
                  onPressed: _hasSubmitted ? _goNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasSubmitted ? Colors.green : Colors.grey,
                  ),
                  child: Text(widget.isHindi ? "अगला" : "Next",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
