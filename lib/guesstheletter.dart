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

  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;
  String? imageUrl;
  Map<String, dynamic> userAnswers = {};

  List<String> questionOrder = [];
  List<QueryDocumentSnapshot> allQuestions = [];
  int currentQuestionIndex = 0;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  int? _selectedOptionIndex;
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadGameState().then((_) => _fetchQuestionsInOrder());
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
      "score": score,
      "correctCount": correctCount,
      "incorrectCount": incorrectCount,
      "answers": userAnswers,
      "questionOrder": questionOrder,
    });
  }

  Future<void> _fetchQuestionsInOrder() async {
    final snapshot =
        await FirebaseFirestore.instance.collection(widget.gameTitle).get();

    final qMap = {for (var d in snapshot.docs) d.id: d};

    if (questionOrder.isEmpty) {
      final answered = snapshot.docs
          .where((d) => userAnswers.containsKey(d.id))
          .map((d) => d.id)
          .toList();
      final unanswered = snapshot.docs
          .where((d) => !userAnswers.containsKey(d.id))
          .map((d) => d.id)
          .toList();
      questionOrder = [...answered, ...unanswered];
      await _saveGameState();
    }

    final allDone = questionOrder.every((id) => userAnswers.containsKey(id));
    if (allDone) {
      _navigateToResult();
      return;
    }

    setState(() {
      allQuestions = questionOrder
          .map((id) => qMap[id])
          .whereType<QueryDocumentSnapshot>()
          .toList();
    });

    _loadQuestionFromIndex(_firstUnansweredIndex());
  }

  int _firstUnansweredIndex() {
    for (var i = 0; i < questionOrder.length; i++) {
      if (!userAnswers.containsKey(questionOrder[i])) return i;
    }
    return 0;
  }

  void _loadQuestionFromIndex(int idx) {
    if (idx < 0 || idx >= allQuestions.length) return;
    final doc = allQuestions[idx];
    final data = doc.data() as Map<String, dynamic>;
    final saved = userAnswers[doc.id];

    setState(() {
      currentQuestionIndex = idx;
      currentDocId = doc.id;
      questionText = data['text'] ?? "Question";
      imageUrl = data['imageUrl'] as String?;
      options = List<Map<String, dynamic>>.from(data['options'] as List? ?? []);
      for (var o in options) o['selected'] = false;

      if (saved != null) {
        final i = saved['selectedOptionIndex'] as int? ?? 0;
        _selectedOptionIndex = i;
        _hasSubmitted = true;
        if (i < options.length) options[i]['selected'] = true;
      } else {
        _selectedOptionIndex = null;
        _hasSubmitted = false;
      }
    });
  }

  void _selectOption(int i) {
    if (_hasSubmitted) return;
    setState(() {
      _selectedOptionIndex = i;
      for (var j = 0; j < options.length; j++) options[j]['selected'] = false;
      options[i]['selected'] = true;
    });
  }

  void _submitAnswer() {
    if (_hasSubmitted || _selectedOptionIndex == null) return;
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
      };
    });
    _saveGameState();
  }

  void _goToPreviousQuestion() {
    if (currentQuestionIndex > 0)
      _loadQuestionFromIndex(currentQuestionIndex - 1);
  }

  void _goToNextQuestion() {
    if (currentQuestionIndex < allQuestions.length - 1) {
      _loadQuestionFromIndex(currentQuestionIndex + 1);
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
            // Question
            Text(
              questionText,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Image
            if (imageUrl != null) Image.network(imageUrl!, height: 100),
            const SizedBox(height: 15),

            // Options grid (non-scrollable)
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

            // Score & buttons
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
                  child: Text(
                    widget.isHindi ? "पिछला" : "Previous",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: (_selectedOptionIndex != null && !_hasSubmitted)
                      ? _submitAnswer
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(
                    widget.isHindi ? "जमा करें" : "Submit",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton(
                  onPressed: _hasSubmitted ? _goToNextQuestion : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasSubmitted ? Colors.green : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(
                    widget.isHindi ? "अगला" : "Next",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
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
                  spreadRadius: 1,
                ),
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
