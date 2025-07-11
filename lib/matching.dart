// lib/matching_page.dart

import 'dart:ui'; // for ImageFilter
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart';
import 'ai.dart';
import 'video_lesson.dart';

class MatchingPage extends StatefulWidget {
  final String gameTitle;
  final bool isHindi;
  const MatchingPage({
    Key? key,
    required this.gameTitle,
    required this.isHindi,
  }) : super(key: key);

  @override
  _MatchingPageState createState() => _MatchingPageState();
}

class _MatchingPageState extends State<MatchingPage> {
  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // AI service
  late final AiService _aiService;

  // Game state
  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;
  Map<String, dynamic> userAnswers = {};

  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;

  int? _pendingSelectedIndex;
  bool _hasSubmitted = false;
  bool _currentIsCorrect = false;
  bool isLoading = true;

  DateTime? _questionStartTime;
  DateTime? _gameStartTime;

  @override
  void initState() {
    super.initState();
    _aiService = AiService();
    _gameStartTime = DateTime.now();
    _loadGameState().then((_) => _loadQuestions());
  }

  @override
  void dispose() {
    _saveGameState();
    _recordGameVisit();
    super.dispose();
  }

  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final snap = await _dbRef
          .child("users/${user.uid}/games/${widget.gameTitle}")
          .get();
      if (snap.exists) {
        final data = snap.value as Map<dynamic, dynamic>;
        setState(() {
          score = data['score'] ?? 0;
          correctCount = data['correctCount'] ?? 0;
          incorrectCount = data['incorrectCount'] ?? 0;
          currentQuestionIndex = data['currentQuestionIndex'] ?? 0;
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
      await _dbRef
          .child("users/${user.uid}/games/${widget.gameTitle}")
          .update({
        "score": score,
        "correctCount": correctCount,
        "incorrectCount": incorrectCount,
        "currentQuestionIndex": currentQuestionIndex,
        "answers": userAnswers,
      });
    } catch (e) {
      print("Error saving game state: $e");
    }
  }

  Future<void> _recordGameVisit() async {
    final user = _auth.currentUser;
    final start = _gameStartTime;
    if (user == null || start == null) return;

    final now = DateTime.now();
    final seconds = now.difference(start).inSeconds;
    final dateKey = now.toIso8601String().substring(0, 10);

    final path =
        "users/${user.uid}/games/${widget.gameTitle}/gameVisits/$dateKey";

    final snap = await _dbRef.child(path).get();
    final prev = (snap.exists && snap.value is int) ? snap.value as int : 0;
    await _dbRef.child(path).set(prev + seconds);
  }

  Future<void> _loadQuestions() async {
    try {
      final snapshot = await _firestore
          .collection(widget.gameTitle)
          .orderBy('timestamp')
          .get();

      questions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final rawOpts = (data['options'] as List<dynamic>?) ?? [];
        final opts = rawOpts.map((opt) {
          final m = opt as Map<String, dynamic>;
          return {
            'title': m['title'] as String? ?? '',
            'isCorrect': m['isCorrect'] as bool? ?? false,
          };
        }).toList();
        return {
          'id': doc.id,
          'text': data['text'] as String? ?? '',
          'options': opts,
        };
      }).toList();

      setState(() => isLoading = false);
      _initQuestionState();
    } catch (e) {
      print("Error loading questions: $e");
      setState(() => isLoading = false);
    }
  }

  void _initQuestionState() {
    if (questions.isEmpty) return;
    final qId = questions[currentQuestionIndex]['id'] as String;
    if (userAnswers.containsKey(qId)) {
      final saved = userAnswers[qId] as Map<String, dynamic>;
      _pendingSelectedIndex = saved['selectedOptionIndex'] as int?;
      _hasSubmitted = true;
      _currentIsCorrect = saved['isCorrect'] as bool;
    } else {
      _pendingSelectedIndex = null;
      _hasSubmitted = false;
      _currentIsCorrect = false;
    }
    _questionStartTime = DateTime.now();
    setState(() {});
  }

  void _selectOption(int idx) {
    if (_hasSubmitted) return;
    setState(() => _pendingSelectedIndex = idx);
  }

  Future<void> _submitAnswer() async {
    if (_pendingSelectedIndex == null || _hasSubmitted) return;
    final currentQ = questions[currentQuestionIndex];
    final opts = currentQ['options'] as List<dynamic>;
    final isCorrect = opts[_pendingSelectedIndex!]['isCorrect'] as bool;

    final now = DateTime.now();
    final timeTaken = _questionStartTime != null
        ? now.difference(_questionStartTime!).inSeconds
        : 0;

    setState(() {
      _hasSubmitted = true;
      _currentIsCorrect = isCorrect;
      userAnswers[currentQ['id']] = {
        'selectedOptionIndex': _pendingSelectedIndex,
        'isCorrect': isCorrect,
        'timeTakenSeconds': timeTaken,
      };
      if (isCorrect) {
        score++;
        correctCount++;
      } else {
        incorrectCount++;
      }
    });

    await _saveGameState();
    // AI hint button now appears below options
  }

  Future<void> _analyzeWithAI() async {
    final currentQ = questions[currentQuestionIndex];
    final opts = currentQ['options'] as List<dynamic>;
    final questionText = currentQ['text'] as String;
    final optionTitles = opts.map((o) => o['title'] as String).toList();
    final correctTitle =
    optionTitles[opts.indexWhere((o) => o['isCorrect'] as bool)];
    final userTitle = optionTitles[_pendingSelectedIndex!];

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(widget.isHindi ? 'कृपया प्रतीक्षा करें' : 'Please wait'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(widget.isHindi
                ? 'AI उत्तर का विश्लेषण कर रहा है...'
                : 'AI is analyzing your answer...'),
          ],
        ),
      ),
    );

    try {
      final fb = await _aiService.getFeedback(
        question: questionText,
        options: optionTitles,
        correctAnswer: correctTitle,
        userAnswer: userTitle,
      );
      Navigator.of(context).pop(); // close loading
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoLesson(script: fb['explanation']),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI feedback failed: $e')),
      );
    }
  }

  void _previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() => currentQuestionIndex--);
      _initQuestionState();
      _saveGameState();
    }
  }

  void _nextQuestion() {
    final qId = questions[currentQuestionIndex]['id'] as String;
    if (!_hasSubmitted && !userAnswers.containsKey(qId)) return;
    if (currentQuestionIndex < questions.length - 1) {
      setState(() => currentQuestionIndex++);
      _initQuestionState();
      _saveGameState();
    } else {
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
  }

  void _showInstructionsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(widget.isHindi ? "निर्देश" : "Instructions"),
        content: Text(widget.isHindi
            ? "१. विकल्प चुनें (नीला बॉर्डर).\n२. जमा करें पर टैप करें.\n३. सही: हरा टिक; गलत: लाल क्रॉस.\n४. Prev/Next.\n५. प्रगति सेव."
            : "1. Tap an option (blue border).\n2. Tap Submit.\n3. Correct: green tick; incorrect: red cross.\n4. Use Prev/Next.\n5. Progress is saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.isHindi ? "ठीक है" : "Got it!"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No questions available.")),
      );
    }

    final currentQ = questions[currentQuestionIndex];
    final opts = currentQ['options'] as List<dynamic>;

    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        title: Text(
          widget.gameTitle,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade300,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInstructionsDialog,
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Text(
                currentQ['text'] as String,
                textAlign: TextAlign.center,
                style:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: GridView.builder(
                  itemCount: opts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.1,
                  ),
                  itemBuilder: (ctx, idx) {
                    final option = opts[idx];
                    final isPending =
                        _pendingSelectedIndex == idx && !_hasSubmitted;
                    final showResult =
                        _pendingSelectedIndex == idx && _hasSubmitted;
                    final isCorrectOpt = option['isCorrect'] as bool;

                    Color borderColor = Colors.white10;
                    Widget? overlayIcon;
                    if (isPending) {
                      borderColor = Colors.blue;
                    } else if (showResult) {
                      borderColor =
                      isCorrectOpt ? Colors.green : Colors.red;
                      overlayIcon = Icon(
                        isCorrectOpt ? Icons.check_circle : Icons.cancel,
                        color: borderColor,
                        size: 50,
                      );
                    }

                    return GestureDetector(
                      onTap: _hasSubmitted ? null : () => _selectOption(idx),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: borderColor, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: Center(
                                      child: Text(
                                        option['title'] as String,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 25,
                                            fontWeight:
                                            FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  if (showResult)
                                    Positioned.fill(
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 1.0, sigmaY: 1.0),
                                        child: Container(
                                          color:
                                          Colors.black.withOpacity(0.2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (overlayIcon != null)
                            Positioned(top: 5, right: 5, child: overlayIcon),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // AI Hint button (only shows after submission)
              if (_hasSubmitted && !_currentIsCorrect)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: ElevatedButton.icon(
                    onPressed: _analyzeWithAI,
                    icon: const Icon(Icons.lightbulb_outline),
                    label: Text(widget.isHindi
                        ? 'AI से सही उत्तर जानें'
                        : 'Know the correct answer using AI'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF9F3ACDFF),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),

              // Score display
              const SizedBox(height: 15),
              Column(
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
              const SizedBox(height: 15),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: currentQuestionIndex > 0
                        ? _previousQuestion
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentQuestionIndex > 0
                          ? Colors.orange
                          : Colors.grey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 15),
                    ),
                    child: Text(
                      widget.isHindi ? "पिछला" : "Previous",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (_pendingSelectedIndex != null &&
                        !_hasSubmitted)
                        ? _submitAnswer
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15)),
                    child: Text(
                      widget.isHindi ? "जमा करें" : "Submit",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (_hasSubmitted ||
                        userAnswers.containsKey(
                            questions[currentQuestionIndex]['id']))
                        ? _nextQuestion
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15)),
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
      ),
    );
  }
}
