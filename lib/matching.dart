import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchingPage extends StatefulWidget {
  final String gameTitle;
  const MatchingPage({Key? key, required this.gameTitle}) : super(key: key);

  @override
  _MatchingPageState createState() => _MatchingPageState();
}

class _MatchingPageState extends State<MatchingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> questions = [];

  int currentQuestionIndex = 0;
  Map<int, int> selectedAnswers = {};
  int score = 0;
  bool answered = false;

  @override
  void initState() {
    super.initState();
    loadQuestions();
  }

  Future<void> loadQuestions() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection(widget.gameTitle)
          .orderBy('timestamp')
          .get();

      questions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final questionText = data['text'] as String? ?? "No question text";
        final rawOptions = data['options'] as List<dynamic>? ?? [];

        final parsedOptions = rawOptions.map((opt) {
          final optionMap = opt as Map<String, dynamic>;
          final optionTitle =
              optionMap['title'] as String? ?? "No option title";
          final isCorrect = optionMap['isCorrect'] as bool? ?? false;
          return {
            'title': optionTitle,
            'isCorrect': isCorrect,
          };
        }).toList();

        return {
          'text': questionText,
          'options': parsedOptions,
        };
      }).toList();

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error loading questions: $e");
    }
  }

  void _selectOption(int optionIndex) {
    if (answered) return;
    setState(() {
      selectedAnswers[currentQuestionIndex] = optionIndex;
      answered = true;
      bool isCorrect =
          questions[currentQuestionIndex]['options'][optionIndex]['isCorrect'];
      if (isCorrect) score++;
    });
  }

  void _previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
        answered = selectedAnswers.containsKey(currentQuestionIndex);
      });
    }
  }

  void _nextQuestion() {
    if (!selectedAnswers.containsKey(currentQuestionIndex)) return;
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        answered = selectedAnswers.containsKey(currentQuestionIndex);
      });
    } else {
      _showFinalScore();
    }
  }

  void _showFinalScore() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Quiz Completed 🎉"),
        content: Text("Your score is $score out of ${questions.length}."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          )
        ],
      ),
    );
  }

  void _showInstructionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Instructions"),
        content: const Text(
          "• Select the correct option.\n"
          "• Correct: Green border + Tick.\n"
          "• Incorrect: Red border + Cross.\n"
          "• Use Next/Previous to navigate.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.gameTitle),
          backgroundColor: Colors.indigo,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showInstructionsDialog,
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentQuestion = questions[currentQuestionIndex];
    final questionText = currentQuestion['text'] as String;
    final options = currentQuestion['options'] as List<dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.gameTitle),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInstructionsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                questionText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: GridView.builder(
                  itemCount: options.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.1,
                  ),
                  itemBuilder: (context, index) {
                    bool isSelected =
                        selectedAnswers[currentQuestionIndex] == index;
                    bool isCorrect =
                        options[index]['isCorrect'] as bool? ?? false;
                    Color borderColor = Colors.grey;
                    Widget? icon;

                    if (isSelected && answered) {
                      borderColor = isCorrect ? Colors.green : Colors.red;
                      icon = Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red,
                      );
                    }

                    return ElevatedButton(
                      onPressed: answered ? null : () => _selectOption(index),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.black,
                        backgroundColor: isSelected && answered
                            ? Colors.grey.shade300
                            : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: borderColor,
                            width: 3,
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        elevation: 3,
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              options[index]['title'],
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                          if (icon != null)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: icon,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed:
                        currentQuestionIndex > 0 ? _previousQuestion : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Previous"),
                  ),
                  Text(
                    "Score: $score",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: selectedAnswers.containsKey(currentQuestionIndex)
                        ? _nextQuestion
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Next"),
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
