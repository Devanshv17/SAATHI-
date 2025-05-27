import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart'; // Import your ResultPage

class ComparePage extends StatefulWidget {
  const ComparePage({Key? key}) : super(key: key);

  @override
  _ComparePageState createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  List<CompareQuestion> questions = [];
  int currentIndex = 0;
  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;

  // Map storing the selected option index for each question.
  Map<int, int> selectedOptionIndices = {};

  bool isLoading = true;

  // Firebase instances for authentication and realtime DB.
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    // Load previous game state first then fetch questions.
    _loadGameState().then((_) => _fetchQuestions());
  }

  Future<void> _loadGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot =
          await _dbRef.child("users/${user.uid}/games/Compare").get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          score = data['score'] ?? 0;
          correctCount = data['correctCount'] ?? 0;
          incorrectCount = data['incorrectCount'] ?? 0;
          currentIndex = data['currentIndex'] ?? 0;
          // For selectedOptionIndices, convert keys from string to int.
          if (data['selectedOptionIndices'] != null) {
            final Map<dynamic, dynamic> savedMap =
                data['selectedOptionIndices'];
            selectedOptionIndices = savedMap.map((key, value) =>
                MapEntry(int.tryParse(key.toString()) ?? key, value));
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
      // Convert the selectedOptionIndices keys to string for saving.
      final formattedAnswers = selectedOptionIndices
          .map((key, value) => MapEntry(key.toString(), value));
      await _dbRef.child("users/${user.uid}/games/Compare").update({
        "score": score,
        "correctCount": correctCount,
        "incorrectCount": incorrectCount,
        "currentIndex": currentIndex,
        "selectedOptionIndices": formattedAnswers,
      });
    } catch (e) {
      print("Error saving game state: $e");
    }
  }

  // Fetch questions from Firestore.
  Future<void> _fetchQuestions() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection("Compare")
          .orderBy("timestamp")
          .get();

      List<CompareQuestion> loadedQuestions = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CompareQuestion(
          compareNumber1:
              int.tryParse(data['compareNumber1']?.toString() ?? '') ?? 0,
          compareNumber2:
              int.tryParse(data['compareNumber2']?.toString() ?? '') ?? 0,
          options: (data['options'] as List<dynamic>?)
                  ?.map((option) => CompareOption.fromMap(option))
                  .toList() ??
              [],
          text: data['text'] ?? "",
        );
      }).toList();

      setState(() {
        questions = loadedQuestions;
        isLoading = false;
      });

      // If all questions already answered, automatically navigate to result.
      if (selectedOptionIndices.length == questions.length) {
        _navigateToResult();
      }
      // Also, if currentIndex is out of bound (for instance if questions were reduced), reset.
      if (currentIndex >= questions.length) {
        setState(() {
          currentIndex = questions.length - 1;
        });
      }
    } catch (e) {
      print("Error fetching questions: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Displays an instructions dialog.
  void _showInstructionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Instructions",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "1. Compare the number of shapes shown.\n"
            "2. Select the correct relation by tapping one option.\n"
            "3. If your answer is correct, a green border and check mark will appear; if wrong, a red border and cross will show.\n"
            "4. Use the Next and Previous buttons to navigate.\n"
            "5. Your progress is saved and resumed when you come back.\n"
            "6. After the last question, you will see the results.",
            style: TextStyle(fontSize: 20),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                "Got it!",
                style: TextStyle(fontSize: 20, color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  // Build grid for shapes using asset images.
  Widget _buildShapeGrid(int count, String assetPath) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black54, width: 2),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5,
            spreadRadius: 1,
            offset: Offset(2, 2),
          )
        ],
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: count,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
        ),
        itemBuilder: (context, index) {
          return Image.asset(assetPath, width: 40, height: 40);
        },
      ),
    );
  }

  // Called when an option is tapped.
  void _handleOptionSelected(int optionIndex) {
    // Allow only one selection per question.
    if (selectedOptionIndices.containsKey(currentIndex)) return;
    setState(() {
      selectedOptionIndices[currentIndex] = optionIndex;
      // Check if the selected option is correct.
      if (questions[currentIndex].options[optionIndex].isCorrect) {
        score++;
        correctCount++;
      } else {
        incorrectCount++;
      }
    });
    _saveGameState();
  }

  // Build the option tiles.
  Widget _buildOptions() {
    final currentQuestion = questions[currentIndex];
    int? selected = selectedOptionIndices[currentIndex];

    return Column(
      children: List.generate(currentQuestion.options.length, (index) {
        final option = currentQuestion.options[index];
        // Determine border color and overlay icon if this option is selected.
        Color borderColor = Colors.blueAccent;
        Widget? overlayIcon;
        if (selected != null && selected == index) {
          if (option.isCorrect) {
            borderColor = Colors.green;
            overlayIcon =
                const Icon(Icons.check_circle, color: Colors.green, size: 40);
          } else {
            borderColor = Colors.red;
            overlayIcon = const Icon(Icons.cancel, color: Colors.red, size: 40);
          }
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: OptionTile(
            text: option.title,
            borderColor: borderColor,
            overlayIcon: overlayIcon,
            onTap: selected == null ? () => _handleOptionSelected(index) : null,
          ),
        );
      }),
    );
  }

  // Move to the next question or go to result if it's the last.
  void _goToNextQuestion() {
    // Only allow navigation if this question has an answer.
    if (!selectedOptionIndices.containsKey(currentIndex)) return;
    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
      });
      _saveGameState();
    } else {
      // Last question answered, navigate to results.
      _navigateToResult();
    }
  }

  // Move to the previous question.
  void _goToPreviousQuestion() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });
      _saveGameState();
    }
  }

  // Navigate to the results page.
  void _navigateToResult() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          gameTitle: "Compare",
          score: score,
          correctCount: correctCount,
          incorrectCount: incorrectCount,
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
    // Display a loading indicator while fetching.
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If no questions are loaded.
    if (questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No Compare questions available.")),
      );
    }

    final currentQuestion = questions[currentIndex];

    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        title: const Text("Compare",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade300,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 30),
            onPressed: _showInstructionsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // New Question Header.
              const Text(
                "Compare the number of shapes",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Shape grids.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShapeGrid(
                      currentQuestion.compareNumber1, 'assets/circle.png'),
                  _buildShapeGrid(
                      currentQuestion.compareNumber2, 'assets/triangle.png'),
                ],
              ),
              const SizedBox(height: 15),
              // Options.
              _buildOptions(),


  const SizedBox(height: 15),
              Center(
                child: Column(
                  children: [
                    Text(
                      "Score: $score",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Correct: $correctCount | Incorrect: $incorrectCount",
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              // Navigation buttons.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: currentIndex > 0 ? _goToPreviousQuestion : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentIndex > 0
                          ? Colors.orange
                          : Colors.grey,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    
                    ),
                    child: const Text("Previous",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: selectedOptionIndices.containsKey(currentIndex)
                        ? _goToNextQuestion
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                     
                    ),
                    child: Text(
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
      ),
    );
  }
}

// OptionTile widget: a clickable, kid-friendly option.
class OptionTile extends StatelessWidget {
  final String text;
  final Color borderColor;
  final Widget? overlayIcon;
  final VoidCallback? onTap;

  const OptionTile({
    Key? key,
    required this.text,
    required this.borderColor,
    this.overlayIcon,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: borderColor, width: 4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
          ),
          if (overlayIcon != null)
            Positioned(
              right: 10,
              top: 10,
              child: overlayIcon!,
            ),
        ],
      ),
    );
  }
}

// Model for a Compare question.
class CompareQuestion {
  final int compareNumber1;
  final int compareNumber2;
  final List<CompareOption> options;
  final String text;

  CompareQuestion({
    required this.compareNumber1,
    required this.compareNumber2,
    required this.options,
    required this.text,
  });
}

// Model for an option.
class CompareOption {
  final String title;
  final bool isCorrect;

  CompareOption({
    required this.title,
    required this.isCorrect,
  });

  factory CompareOption.fromMap(Map<String, dynamic> map) {
    return CompareOption(
      title: map['title'] ?? '',
      isCorrect: map['isCorrect'] ?? false,
    );
  }
}
