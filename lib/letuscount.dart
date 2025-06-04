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
  const LetUsCountPage({Key? key,
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

  List<String> questionOrder = [];
  List<QueryDocumentSnapshot> allQuestions = [];
  int currentQuestionIndex = -1;
  Map<String, dynamic> userAnswers = {};

  final Random _random = Random();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // The game key used in saving and loading game state—must match the key expected by the homepage.
  

  // New state for submission logic
  int? _selectedOptionIndex;
  bool _hasSubmitted = false;
  bool _isCorrectSubmission = false;

  @override
  void initState() {
    super.initState();
    _loadGameState().then((_) => _fetchQuestionsInOrder());
  }

  /// Load saved game state from Realtime Database
  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snap = await _dbRef.child("users/${user.uid}/games/${widget.gameTitle}").get();
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

  /// Save game state to Realtime Database
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
    try {
      final snapshot = await _firestore
          .collection(widget.gameTitle)
          .get(const GetOptions(source: Source.serverAndCache));

      allQuestions = snapshot.docs;
      if (allQuestions.isEmpty) return;

      // Build or persist questionOrder
      if (questionOrder.isEmpty) {
        final answered = allQuestions
            .where((doc) => userAnswers.containsKey(doc.id))
            .map((doc) => doc.id)
            .toList();
        final unanswered = allQuestions
            .where((doc) => !userAnswers.containsKey(doc.id))
            .map((doc) => doc.id)
            .toList();

        questionOrder = [...answered, ...unanswered];
        await _saveGameState();
      }

      // If all answered, go to result
      bool allDone = questionOrder.every((id) => userAnswers.containsKey(id));
      if (allDone) {
        _navigateToResult();
        return;
      }

      _loadQuestionFromIndex(questionOrder.indexWhere(
        (id) => !userAnswers.containsKey(id),
      ));
    } catch (e) {
      debugPrint("Error fetching questions: $e");
    }
  }

  void _loadQuestionFromIndex(int index) {
    if (index < 0 || index >= allQuestions.length) return;

    final doc = allQuestions[index];
    final data = doc.data() as Map<String, dynamic>;

    // Check if already answered
    final saved = userAnswers[doc.id];

    setState(() {
      currentQuestionIndex = index;
      currentDocId = doc.id;
      question = data['text'] ?? "How many objects do you see?";
      imageCount = int.tryParse(data['numberField']?.toString() ?? "0") ?? 0;
      imageAssets = List.generate(
        imageCount,
        (_) => _random.nextBool() ? 'assets/circle.png' : 'assets/triangle.png',
      );
      options = (data['options'] as List)
          .map((o) => {...(o as Map<String, dynamic>), 'selected': false})
          .toList();

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

  void _submitAnswer() {
    if (_hasSubmitted || _selectedOptionIndex == null) return;

    int index = _selectedOptionIndex!;
    bool isCorrect = options[index]['isCorrect'] == true;

    setState(() {
      options[index]['selected'] = true;
      _hasSubmitted = true;
      _isCorrectSubmission = isCorrect;

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

  void showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
    // Only proceed if answered/submitted
    if (_hasSubmitted || userAnswers.containsKey(currentDocId)) {
      bool allDone = questionOrder.every((id) => userAnswers.containsKey(id));
      if (allDone) {
        _navigateToResult();
      } else if (currentQuestionIndex < allQuestions.length - 1) {
        _loadQuestionFromIndex(currentQuestionIndex + 1);
      }
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
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Text(
              widget.gameTitle,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
               IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white),
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
              question,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 17),

            // Display generated images
            Wrap(
              spacing: 10,
              children: imageAssets
                  .map((asset) => Image.asset(asset, width: 45, height: 45))
                  .toList(),
            ),
            const SizedBox(height: 20),

            // Options grid
            Expanded(
              child: GridView.builder(
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                  childAspectRatio: 1.5,
                ),
                itemBuilder: (context, i) {
                  final o = options[i];
                  bool isSelected = _selectedOptionIndex == i;
                  bool showResultForThis =
                      _hasSubmitted && _selectedOptionIndex == i;
                  bool corr = o['isCorrect'] == true;

                  return GestureDetector(
                    onTap: () {
                      // Only allow selecting if not already submitted/answered
                      if (!_hasSubmitted &&
                          !userAnswers.containsKey(currentDocId)) {
                        setState(() {
                          _selectedOptionIndex = i;
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        // Option container with appropriate border
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: isSelected && !_hasSubmitted
                                // Blue border when selected but not submitted
                                ? Border.all(color: Colors.blue, width: 4)
                                // Green or red border after submission
                                : showResultForThis
                                    ? Border.all(
                                        color: corr ? Colors.green : Colors.red,
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
                                // Option text
                                Positioned.fill(
                                  child: Center(
                                    child: Text(
                                      o['description'] ?? '',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: showResultForThis
                                            ? (corr ? Colors.green : Colors.red)
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                ),

                                // Blur overlay if showing result
                                if (showResultForThis)
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

                        // Tick or cross in top-right corner if showing result
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
                },
              ),
            ),

            // const SizedBox(height: 15),

            // Submit button (always visible but disabled if no selection or already submitted)
            

            const SizedBox(height: 15),

            // Score display
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

            const SizedBox(height: 15),

            // Navigation buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _goToPreviousQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        currentQuestionIndex > 0 ? Colors.orange : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                  ),
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
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                  ),
                ),

                ElevatedButton(
                  onPressed:
                      (_hasSubmitted || userAnswers.containsKey(currentDocId))
                          ? _goToNextQuestion
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        (_hasSubmitted || userAnswers.containsKey(currentDocId))
                            ? Colors.green
                            : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 15),
                  ),
                  child:  Text(
                    widget.isHindi ? "अगला" : "Next",
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
}
