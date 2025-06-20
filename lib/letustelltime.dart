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

  List<QueryDocumentSnapshot> allQuestions = [];
  List<String> questionOrder = [];
  int currentQuestionIndex = -1;
  String currentDocId = '';
  Map<String, dynamic> userAnswers =
      {}; // {questionId: {selectedOptionIndex, isCorrect}}

  String question = '';
  DateTime? clockTime;
  List<Map<String, dynamic>> options = [];

  // Pending selection before submission
  int? _pendingSelectedIndex;
  bool _hasSubmitted = false;
  bool _currentIsCorrect = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
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
        userAnswers = Map<String, dynamic>.from(data['answers'] ?? {});
        questionOrder = List<String>.from(data['questionOrder'] ?? []);
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
      'answers': userAnswers,
      'questionOrder': questionOrder,
    });
  }

  Future<void> _fetchQuestions() async {
    try {
      final snap = await _firestore
          .collection(widget.gameTitle)
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

      _loadQuestion(
          questionOrder.indexWhere((id) => !userAnswers.containsKey(id)));
    } catch (e) {
      debugPrint('Error fetching questions: $e');
    }
  }

  bool _allAnswered() =>
      questionOrder.isNotEmpty &&
      questionOrder.every((id) => userAnswers.containsKey(id));

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
      currentQuestionIndex = orderIndex;
      currentDocId = docId;
      question = text;
      clockTime = time;
      options = opts;
    });
  }

  void _selectOption(int index) {
    if (_hasSubmitted || userAnswers.containsKey(currentDocId)) return;
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

    // ←── here’s the fix: use your stored flag!
    final isCorrect = options[_pendingSelectedIndex!]['isCorrect'] as bool;

    setState(() {
      _hasSubmitted = true;
      _currentIsCorrect = isCorrect;
      options[_pendingSelectedIndex!]['selected'] = true;
      userAnswers[currentDocId] = {
        'selectedOptionIndex': _pendingSelectedIndex,
        'isCorrect': isCorrect,
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
        title: Text(
          widget.gameTitle,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(widget.isHindi ? "निर्देश" : "Instructions"),
                  content: Text(
                    widget.isHindi
                        ? "१. विकल्प चुनने के लिए टैप करें (नीले बॉर्डर).\n"
                            "२. अपनी पसंद लॉक करने के लिए जमा करें पर टैप करें.\n"
                            "३. सही उत्तर: हरा टिक; गलत उत्तर: लाल क्रॉस .\n"
                            "४. आगे/पीछे जाने के लिए अगला/पिछला उपयोग करें.\n"
                            "५. आपकी प्रगति सेव हो जाती है."
                        : "1. Tap an option to select (blue border).\n"
                            "2. Tap Submit to lock in your choice.\n"
                            "3. Correct: green tick ; incorrect: red cross .\n"
                            "4. Use Previous/Next to navigate.\n"
                            "5. Progress is saved.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.isHindi ? "ठीक है" : "Got it!"),
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
            Text(
              widget.isHindi ? "सही समय चुनें" : "Select the correct time",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            if (clockTime != null)
              Center(
                child: Container(
                  width: 180,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 4,
                        color: Colors.black12,
                        offset: Offset(2, 2),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: AnalogClock(
                        key: ValueKey(clockTime), dateTime: clockTime!),
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
                  childAspectRatio: 1.4,
                ),
                itemBuilder: (_, i) {
                  final opt = options[i];
                  bool isPending =
                      (_pendingSelectedIndex == i && !_hasSubmitted);
                  bool showResult =
                      (_pendingSelectedIndex == i && _hasSubmitted);
                  bool isCorrect = false;
                  if (_hasSubmitted && _pendingSelectedIndex == i) {
                    isCorrect = _currentIsCorrect;
                  }

                  Color borderColor = Colors.white10;
                  if (isPending) {
                    borderColor = Colors.blue;
                  } else if (showResult) {
                    borderColor = isCorrect ? Colors.green : Colors.red;
                  }

                  return GestureDetector(
                    onTap:
                        (_hasSubmitted || userAnswers.containsKey(currentDocId))
                            ? null
                            : () => _selectOption(i),
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
                                spreadRadius: 1,
                              )
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
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                if (showResult)
                                  Positioned.fill(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 1.0,
                                        sigmaY: 1.0,
                                      ),
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
            const SizedBox(height: 15),
            Center(
              child: Column(
                children: [
                  Text(
                    widget.isHindi ? "अंक: $score" : "Score: $score",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.isHindi
                        ? "सही: $correctCount | गलत: $incorrectCount"
                        : "Correct: $correctCount | Incorrect: $incorrectCount",
                    style: const TextStyle(fontSize: 16),
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
                    backgroundColor:
                        currentQuestionIndex > 0 ? Colors.orange : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(
                    widget.isHindi ? "पिछला" : "Previous",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  onPressed: (_pendingSelectedIndex != null && !_hasSubmitted)
                      ? _submitAnswer
                      : null,
                  child: Text(
                    widget.isHindi ? "जमा करें" : "Submit",
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                ),
                ElevatedButton(
                  // ←── only enabled once you’ve submitted or all Q’s done
                  onPressed: (_hasSubmitted || _allAnswered())
                      ? (_allAnswered() ? _navigateToResult : _goNext)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_hasSubmitted || _allAnswered())
                        ? Colors.green
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(
                    widget.isHindi ? "अगला" : "Next",
                    style: const TextStyle(
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
