import 'dart:ui'; // for ImageFilter
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'result.dart';

class GuessTheLetterPage extends StatefulWidget {
  final String gameTitle;
  final bool isHindi;
  const GuessTheLetterPage({
    Key? key,
    required this.gameTitle,
    required this.isHindi,
  }) : super(key: key);

  @override
  _GuessTheLetterPageState createState() => _GuessTheLetterPageState();
}

class _GuessTheLetterPageState extends State<GuessTheLetterPage> {
  String questionText = "";
  String currentDocId = "";
  List<Map<String, dynamic>> options = [];
  String? imageUrl;

  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;
  int currentQuestionIndex = 0;
  Map<String, dynamic> userAnswers = {};

  int? _selectedOptionIndex;
  bool _hasSubmitted = false;
  DateTime? _questionStartTime;
  DateTime? _gameStartTime;
  

  List<QueryDocumentSnapshot> allQuestions = [];

  final FirebaseAuth _auth = FirebaseAuth.instance;
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
      "score": score,
      "correctCount": correctCount,
      "incorrectCount": incorrectCount,
      "currentQuestionIndex": currentQuestionIndex,
      "answers": userAnswers,
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
    final snapshot = await FirebaseFirestore.instance
        .collection(widget.gameTitle)
        .orderBy('timestamp')
        .get();

    setState(() {
      allQuestions = snapshot.docs;
    });

    if (currentQuestionIndex >= allQuestions.length) {
      _navigateToResult();
    } else {
      _loadQuestionFromIndex(currentQuestionIndex);
    }
  }

  void _loadQuestionFromIndex(int idx) {
    if (idx < 0 || idx >= allQuestions.length) return;
    final doc = allQuestions[idx];
    final data = doc.data() as Map<String, dynamic>;
    final saved = userAnswers[doc.id];

    setState(() {
      currentDocId = doc.id;
      questionText = data['text'] ?? "Question";
      imageUrl = data['imageUrl'] as String?;
      options = List<Map<String, dynamic>>.from(data['options'] as List? ?? []);
      _selectedOptionIndex =
          saved != null ? saved['selectedOptionIndex'] as int? : null;
      _hasSubmitted = saved != null;
      _questionStartTime = DateTime.now();
    });
  }

  void _selectOption(int i) {
    if (_hasSubmitted) return;
    setState(() => _selectedOptionIndex = i);
  }

  void _submitAnswer() {
    if (_hasSubmitted || _selectedOptionIndex == null) return;
    final now = DateTime.now();
    final duration = _questionStartTime != null
        ? now.difference(_questionStartTime!)
        : Duration.zero;
    final i = _selectedOptionIndex!;
    final correct = options[i]['isCorrect'] as bool? ?? false;

    setState(() {
      _hasSubmitted = true;
      if (correct) {
        score++;
        correctCount++;
      } else {
        incorrectCount++;
      }
      userAnswers[currentDocId] = {
        'selectedOptionIndex': i,
        'isCorrect': correct,
        'timeTakenSeconds': duration.inSeconds,
      };
    });
    _saveGameState();
  }

  void _goToPreviousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
        _hasSubmitted = false;
      });
      _loadQuestionFromIndex(currentQuestionIndex);
    }
  }

  void _goToNextQuestion() {
    if (!_hasSubmitted && !userAnswers.containsKey(currentDocId)) return;
    if (currentQuestionIndex < allQuestions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        _hasSubmitted = false;
      });
      _loadQuestionFromIndex(currentQuestionIndex);
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
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.gameTitle,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, size: 28),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(widget.isHindi ? "निर्देश" : "Instructions"),
                  content: Text(
                    widget.isHindi
                        ? "१. विकल्प चुनें (नीला बॉर्डर).\n"
                            "२. जमा करें पर टैप करें.\n"
                            "३. सही: हरा टिक; गलत: लाल क्रॉस.\n"
                            "४. Prev/Next.\n"
                            "५. प्रगति सेव."
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
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              questionText,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (imageUrl != null) Image.network(imageUrl!, height: 100),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (ctx, i) => buildOptionCard(options[i], i),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isHindi ? "अंक: $score" : "Score: $score",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isHindi
                  ? "सही: $correctCount | गलत: $incorrectCount"
                  : "Correct: $correctCount | Incorrect: $incorrectCount",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _goToPreviousQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        currentQuestionIndex > 0 ? Colors.orange : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(widget.isHindi ? "पिछला" : "Previous",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: (_selectedOptionIndex != null && !_hasSubmitted)
                      ? _submitAnswer
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        (_selectedOptionIndex != null && !_hasSubmitted)
                            ? Colors.blue
                            : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(widget.isHindi ? "जमा करें" : "Submit",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: _hasSubmitted ? _goToNextQuestion : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasSubmitted ? Colors.green : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(widget.isHindi ? "अगला" : "Next",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOptionCard(Map<String, dynamic> option, int index) {
    final isSel = _selectedOptionIndex == index;
    final showRes = _hasSubmitted && isSel;
    final corr = option['isCorrect'] as bool? ?? false;

    return GestureDetector(
      onTap: () => _selectOption(index),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isSel && !_hasSubmitted
                  ? Border.all(color: Colors.blue, width: 4)
                  : showRes
                      ? Border.all(
                          color: corr ? Colors.green : Colors.red, width: 4)
                      : null,
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    spreadRadius: 1),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: Text(
                  option['title'] as String,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
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
  }
}
