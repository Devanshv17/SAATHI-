import 'dart:ui'; // for ImageFilter
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'result.dart';

class GuessTheLetterPage extends StatefulWidget {
  final bool isHindi;
  const GuessTheLetterPage({Key? key,
    required this.isHindi,
  }) : super(key: key);

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

  // New state for submission logic
  int? _selectedOptionIndex;
  bool _hasSubmitted = false;
  bool _isCorrectSubmission = false;

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
      final snapshot =
          await _dbRef.child("users/${user.uid}/games/Guess the Letter").get();
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
        // No previous state
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
    } catch (e) {
      print("Error saving game state: $e");
    }
  }

  // Fetch questions from Firestore and reorder them based on whether they are answered
  Future<void> _fetchQuestionsInOrder() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('Guess the Letter').get();

      Map<String, QueryDocumentSnapshot> questionMap = {
        for (var doc in snapshot.docs) doc.id: doc
      };

      if (questionOrder.isEmpty) {
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

      bool allAnswered =
          questionOrder.every((id) => userAnswers.containsKey(id));
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

        int startIndex = _firstUnansweredIndex();
        _loadQuestionFromIndex(startIndex);
      });
    } catch (e) {
      print("Error fetching questions: $e");
    }
  }

  int _firstUnansweredIndex() {
    for (int i = 0; i < questionOrder.length; i++) {
      if (!userAnswers.containsKey(questionOrder[i])) {
        return i;
      }
    }
    return 0;
  }

  // Load a question based on its index in the ordered list.
  void _loadQuestionFromIndex(int index) {
    if (index < 0 || index >= allQuestions.length) return;
    final doc = allQuestions[index];
    final data = doc.data() as Map<String, dynamic>;
    final saved = userAnswers[doc.id];

    setState(() {
      currentQuestionIndex = index;
      currentDocId = doc.id;
      questionText = data['text'] ?? "Question";
      imageUrl = data['imageUrl'];
      options = List<Map<String, dynamic>>.from(data['options'] ?? []);
      for (var opt in options) {
        opt['selected'] = false;
      }
      if (saved != null) {
        int idx = saved['selectedOptionIndex'] as int;
        bool wasCorrect = saved['isCorrect'] as bool? ?? false;
        _selectedOptionIndex = idx;
        _hasSubmitted = true;
        _isCorrectSubmission = wasCorrect;
        if (idx < options.length) {
          options[idx]['selected'] = true;
        }
      } else {
        _selectedOptionIndex = null;
        _hasSubmitted = false;
        _isCorrectSubmission = false;
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
          isHindi: widget.isHindi,
        ),
      ),
    );
  }

  // Handle option tap: select but do not grade until submit
  void _selectOption(int index) {
    if (_hasSubmitted || userAnswers.containsKey(currentDocId)) return;
    setState(() {
      _selectedOptionIndex = index;
      for (var i = 0; i < options.length; i++) {
        options[i]['selected'] = false;
      }
      options[index]['selected'] = true;
    });
  }

  // Submit the currently selected option
  void _submitAnswer() {
    if (_hasSubmitted || _selectedOptionIndex == null) return;

    int index = _selectedOptionIndex!;
    bool isCorrect = options[index]['isCorrect'] == true;

    setState(() {
      _hasSubmitted = true;
      _isCorrectSubmission = isCorrect;
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
         title: Text(widget.isHindi ? "निर्देश" : "Instructions"),
        content:  Text(
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
            child:  Text(widget.isHindi ? "ठीक है" : "Got it!"),
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
              icon:
                  const Icon(Icons.info_outline, color: Colors.white, size: 28),
              onPressed: () => showInstructions(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Question text
            Text(
              questionText.isNotEmpty ? questionText : widget.isHindi
                      ? "प्रश्न लोड हो रहा है..."
                      : "Loading question...",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (imageUrl != null)
              Center(
                child: Image.network(
                  imageUrl!,
                  height: 100,
                ),
              ),
            const SizedBox(height: 15),
            Expanded(
              child: GridView.builder(
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, index) {
                  return buildOptionCard(options[index], index);
                },
              ),
            ),
            // const SizedBox(height: 15),

            // Submit button
          

            const SizedBox(height: 15),
            Center(
              child: Column(
                children: [
                  Text(
                    widget.isHindi ? "अंक: $score" : "Score: $score",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    widget.isHindi
                        ? "सही: $correctCount | गलत: $incorrectCount"
                        : "Correct: $correctCount | Incorrect: $incorrectCount",
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        currentQuestionIndex > 0 ? Colors.orange : Colors.grey,
                    padding:  EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onPressed:
                      currentQuestionIndex > 0 ? _goToPreviousQuestion : null,
                  child:  Text(
                    widget.isHindi ? "पिछला" : "Previous",
                    style: TextStyle(
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
                  child:  Text(
                    widget.isHindi ? "जमा करें" : "Submit",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding:  EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                ),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        (_hasSubmitted || userAnswers.containsKey(currentDocId))
                            ? Colors.green
                            : Colors.grey,
                    padding:  EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onPressed:
                      (_hasSubmitted || userAnswers.containsKey(currentDocId))
                          ? _goToNextQuestion
                          : null,
                  child:  Text( widget.isHindi?"अगला":
                    "Next",
                    style: TextStyle(
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

  Widget buildOptionCard(Map<String, dynamic> option, int index) {
    bool isSelected = _selectedOptionIndex == index;
    bool showResultForThis = _hasSubmitted && _selectedOptionIndex == index;
    bool corr = option['isCorrect'] == true;

    return GestureDetector(
      onTap: () => _selectOption(index),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isSelected && !_hasSubmitted
                  ? Border.all(color: Colors.blue, width: 4)
                  : showResultForThis
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Text(
                        option['title'],
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (showResultForThis)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                        child: Container(
                          color: Colors.black.withOpacity(0.2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showResultForThis)
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
