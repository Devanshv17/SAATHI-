import 'dart:ui'; // for ImageFilter
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart';

class LeftorRightPage extends StatefulWidget {
  final String gameTitle;
  final bool isHindi;
  const LeftorRightPage({Key? key, required this.gameTitle,
    required this.isHindi,
  }) : super(key: key);

  @override
  _LeftorRightPageState createState() => _LeftorRightPageState();
}

class _LeftorRightPageState extends State<LeftorRightPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> questions = [];
  int currentQuestionIndex = 0;

  // Stores finalized answers: key = questionId, value = {selectedOptionIndex, isCorrect}
  Map<String, dynamic> userAnswers = {};

  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;

  // Pending selection before hitting Submit
  int? _pendingSelectedIndex;
  bool _hasSubmitted = false;
  bool _currentIsCorrect = false;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGameState().then((_) => _loadQuestions());
  }

  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final snapshot = await _dbRef
          .child("users/${user.uid}/games/${widget.gameTitle}")
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
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
      await _dbRef.child("users/${user.uid}/games/${widget.gameTitle}").update({
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

  Future<void> _loadQuestions() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(widget.gameTitle)
          .orderBy('timestamp')
          .get();

      questions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final questionText = data['text'] as String? ?? "";
        final rawOptions = data['options'] as List<dynamic>? ?? [];
        final parsedOptions = rawOptions.map((opt) {
          final mapOpt = opt as Map<String, dynamic>;
          return {
            'title': mapOpt['title'] as String? ?? "",
            'isCorrect': mapOpt['isCorrect'] as bool? ?? false,
          };
        }).toList();
        return {
          'id': doc.id,
          'text': questionText,
          'options': parsedOptions,
        };
      }).toList();

      setState(() {
        isLoading = false;
      });

      _initQuestionState();
    } catch (e) {
      print("Error loading questions: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _initQuestionState() {
    if (questions.isEmpty) return;
    final qId = questions[currentQuestionIndex]['id'];
    if (userAnswers.containsKey(qId)) {
      final saved = userAnswers[qId];
      _pendingSelectedIndex = saved['selectedOptionIndex'] as int;
      _hasSubmitted = true;
      _currentIsCorrect = saved['isCorrect'] as bool;
    } else {
      _pendingSelectedIndex = null;
      _hasSubmitted = false;
      _currentIsCorrect = false;
    }
    setState(() {});
  }

  void _selectOption(int index) {
    if (_hasSubmitted) return;
    setState(() {
      _pendingSelectedIndex = index;
    });
  }

  void _submitAnswer() {
    if (_pendingSelectedIndex == null || _hasSubmitted) return;
    final currentQ = questions[currentQuestionIndex];
    final opts = currentQ['options'] as List<dynamic>;
    bool isCorrect = opts[_pendingSelectedIndex!]['isCorrect'] as bool;
    setState(() {
      _hasSubmitted = true;
      _currentIsCorrect = isCorrect;
      userAnswers[currentQ['id']] = {
        'selectedOptionIndex': _pendingSelectedIndex,
        'isCorrect': isCorrect
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

  void _previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
      });
      _initQuestionState();
      _saveGameState();
    }
  }

  void _nextQuestion() {
    final qId = questions[currentQuestionIndex]['id'];
    if (!_hasSubmitted && !userAnswers.containsKey(qId)) return;
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
      _initQuestionState();
      _saveGameState();
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

  void _showInstructionsDialog() {
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
    final qText = currentQ['text'] as String;
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
                widget.isHindi? "वस्तु के संरेखण का चयन करें|" : "Select the alignment of the object",
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              // Image
             
             if(qText=='l')
                  Align(
          alignment: Alignment.centerLeft,
          child: Image.asset(
            "assets/pencil.png",
            height: 50,
          ),
        ),
                     if (qText == 'r')
                Align(
                  alignment: Alignment.centerRight,
                  child: Image.asset(
                    "assets/pencil.png",
                    height: 50,
                  ),
                ),
                      // Image

              if (qText == 'c')
                Center(
  child: Image.asset(
    "assets/pencil.png",
    height: 50,
  ),
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
                  itemBuilder: (context, index) {
                    final option = opts[index];
                    bool isPending =
                        _pendingSelectedIndex == index && !_hasSubmitted;
                    bool showResult =
                        _pendingSelectedIndex == index && _hasSubmitted;
                    bool isCorrect = option['isCorrect'] as bool;

                    Color borderColor = Colors.white10;
                    Widget? overlayIcon;

                    if (isPending) {
                      borderColor = Colors.blue;
                    } else if (showResult) {
                      borderColor = isCorrect ? Colors.green : Colors.red;
                      overlayIcon = Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red,
                        size: 50,
                      );
                    }

                    return GestureDetector(
                      onTap: _hasSubmitted ? null : () => _selectOption(index),
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
                                ),
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
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  if (showResult)
                                    Positioned.fill(
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(
                                            sigmaX: 1.0, sigmaY: 1.0),
                                        child: Container(
                                          color: Colors.black.withOpacity(0.2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (overlayIcon != null)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: overlayIcon,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // const SizedBox(height: 15),
              
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
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed:
                        currentQuestionIndex > 0 ? _previousQuestion : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentQuestionIndex > 0
                          ? Colors.orange
                          : Colors.grey,
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
                    onPressed: (_pendingSelectedIndex != null && !_hasSubmitted)
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
                    onPressed: (_hasSubmitted ||
                            userAnswers.containsKey(
                                questions[currentQuestionIndex]['id']))
                        ? _nextQuestion
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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
      ),
    );
  }
}
