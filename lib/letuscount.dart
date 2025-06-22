// letuscount.dart

import 'dart:math';
import 'dart:ui'; // for ImageFilter
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'result.dart';

class LetUsCountPage extends StatefulWidget {
  final String gameTitle;
  final bool isHindi;
  const LetUsCountPage({
    Key? key,
    required this.gameTitle,
    required this.isHindi,
  }) : super(key: key);

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

  List<QueryDocumentSnapshot> allQuestions = [];
  int currentQuestionIndex = 0;
  Map<String, dynamic> userAnswers = {};

  final Random _random = Random();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  final List<String> shapeAssets = [
    'assets/circle.png',
    'assets/triangle.png',
    'assets/book.png',
    'assets/pencil.png',
  ];

  final Map<String, List<String>> _assetsByQuestion = {};

  int? _selectedOptionIndex;
  bool _hasSubmitted = false;

  late DateTime _questionStartTime;
  DateTime? _gameStartTime;

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
      "score": score,
      "correctCount": correctCount,
      "incorrectCount": incorrectCount,
      "answers": userAnswers,
      "currentQuestionIndex": currentQuestionIndex,
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
      final snapshot = await _firestore
          .collection(widget.gameTitle)
          .orderBy("timestamp")
          .get(const GetOptions(source: Source.serverAndCache));

      allQuestions = snapshot.docs;
      if (allQuestions.isEmpty) return;

      if (currentQuestionIndex >= allQuestions.length) {
        _navigateToResult();
        return;
      }

      _loadQuestionFromIndex(currentQuestionIndex);
    } catch (e) {
      debugPrint("Error fetching questions: $e");
    }
  }

  void _loadQuestionFromIndex(int index) {
    if (index < 0 || index >= allQuestions.length) return;

    final doc = allQuestions[index];
    final data = doc.data() as Map<String, dynamic>;
    final saved = userAnswers[doc.id];

    setState(() {
      currentQuestionIndex = index;
      currentDocId = doc.id;
      question = data['text'] ?? "How many objects do you see?";
      imageCount = int.tryParse(data['numberField']?.toString() ?? "0") ?? 0;

      if (!_assetsByQuestion.containsKey(doc.id)) {
        final useSame = _random.nextBool();
        if (useSame) {
          final idx = _random.nextInt(shapeAssets.length);
          _assetsByQuestion[doc.id] = List.filled(imageCount, shapeAssets[idx]);
        } else {
          _assetsByQuestion[doc.id] = List.generate(
            imageCount,
            (_) => shapeAssets[_random.nextInt(shapeAssets.length)],
          );
        }
      }
      imageAssets = _assetsByQuestion[doc.id]!;

      options = (data['options'] as List)
          .map((o) => {...(o as Map<String, dynamic>), 'selected': false})
          .toList();

      if (saved != null) {
        final idx = saved['selectedOptionIndex'] as int;
        _selectedOptionIndex = idx;
        _hasSubmitted = true;
        if (idx < options.length) options[idx]['selected'] = true;
      } else {
        _selectedOptionIndex = null;
        _hasSubmitted = false;
      }

      _questionStartTime = DateTime.now(); // Start timer
    });
  }

  void _submitAnswer() {
    if (_hasSubmitted || _selectedOptionIndex == null) return;

    final idx = _selectedOptionIndex!;
    final isCorrect = options[idx]['isCorrect'] == true;
    final timeTaken = DateTime.now().difference(_questionStartTime).inSeconds;

    setState(() {
      options[idx]['selected'] = true;
      _hasSubmitted = true;
      if (isCorrect) {
        score++;
        correctCount++;
      } else {
        incorrectCount++;
      }

      userAnswers[currentDocId] = {
        'selectedOptionIndex': idx,
        'isCorrect': isCorrect,
        'timeTakenSeconds': timeTaken,
      };
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

  void _goToPreviousQuestion() {
    if (currentQuestionIndex > 0) {
      _loadQuestionFromIndex(currentQuestionIndex - 1);
    }
  }

  void _goToNextQuestion() {
    if (_hasSubmitted || userAnswers.containsKey(currentDocId)) {
      if (currentQuestionIndex < allQuestions.length - 1) {
        _loadQuestionFromIndex(currentQuestionIndex + 1);
      } else {
        _navigateToResult();
      }
    }
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.gameTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(widget.isHindi ? "निर्देश" : "Instructions"),
                  content: Text(widget.isHindi
                      ? "१. विकल्प चुनने के लिए टैप करें (नीले बॉर्डर).\n"
                          "२. अपनी पसंद लॉक करने के लिए जमा करें पर टैप करें.\n"
                          "३. सही उत्तर: हरा टिक; गलत उत्तर: लाल क्रॉस.\n"
                          "४. आगे/पीछे जाने के लिए अगला/पिछला उपयोग करें.\n"
                          "५. आपकी प्रगति सेव हो जाती है."
                      : "1. Tap an option to select (blue border).\n"
                          "2. Tap Submit to lock in your choice.\n"
                          "3. Correct: green tick; incorrect: red cross.\n"
                          "4. Use Previous/Next to navigate.\n"
                          "5. Progress is saved."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.isHindi ? "ठीक है" : "Got it!"),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    question,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 17),
                  Wrap(
                    spacing: 10,
                    children: imageAssets
                        .map((asset) =>
                            Image.asset(asset, width: 45, height: 45))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: options.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 15,
                      crossAxisSpacing: 15,
                      childAspectRatio: 1.5,
                    ),
                    itemBuilder: (context, i) {
                      final o = options[i];
                      final isSel = _selectedOptionIndex == i;
                      final showRes =
                          _hasSubmitted && _selectedOptionIndex == i;
                      final corr = o['isCorrect'] == true;
                      return GestureDetector(
                        onTap: () {
                          if (!_hasSubmitted &&
                              !userAnswers.containsKey(currentDocId)) {
                            setState(() => _selectedOptionIndex = i);
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: isSel && !_hasSubmitted
                                    ? Border.all(color: Colors.blue, width: 4)
                                    : showRes
                                        ? Border.all(
                                            color: corr
                                                ? Colors.green
                                                : Colors.red,
                                            width: 4)
                                        : null,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.3),
                                    spreadRadius: 2,
                                    blurRadius: 5,
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
                                          o['title'] ?? '',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: showRes
                                                ? (corr
                                                    ? Colors.green
                                                    : Colors.red)
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (showRes)
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
                            if (showRes)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Icon(
                                  corr ? Icons.check_circle : Icons.cancel,
                                  size: 50,
                                  color: corr ? Colors.green : Colors.red,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
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
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: _goToPreviousQuestion,
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
                      onPressed: (_selectedOptionIndex != null &&
                              !_hasSubmitted &&
                              !userAnswers.containsKey(currentDocId))
                          ? _submitAnswer
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
                      ),
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
                              userAnswers.containsKey(currentDocId))
                          ? _goToNextQuestion
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_hasSubmitted ||
                                userAnswers.containsKey(currentDocId))
                            ? Colors.green
                            : Colors.grey,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
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
        ],
      ),
    );
  }
}
