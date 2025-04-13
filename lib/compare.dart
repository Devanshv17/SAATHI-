import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ComparePage extends StatefulWidget {
  const ComparePage({Key? key}) : super(key: key);

  @override
  _ComparePageState createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  List<CompareQuestion> questions = [];
  int currentIndex = 0;
  int score = 0;
  // Map storing the selected option index for each question.
  Map<int, int> selectedOptionIndices = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  // Fetch questions from the "Compare" collection ordered by timestamp.
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
    } catch (e) {
      print("Error fetching questions: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // Displays instructions in a pop-up dialog.
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
            "1. Compare the number of shapes on the left and right.\n"
            "2. Select the correct relation by tapping one option.\n"
            "3. If your answer is correct, a green border and check mark will appear; if wrong, a red border and cross will show.\n"
            "4. Use the Next and Previous buttons to navigate.\n"
            "5. Your score is updated as you play!",
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
      if (questions[currentIndex].options[optionIndex].isCorrect) {
        score++;
      }
    });
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

  // Move to the next question.
  void _goToNextQuestion() {
    if (selectedOptionIndices[currentIndex] == null) return;
    if (currentIndex < questions.length - 1) {
      setState(() {
        currentIndex++;
      });
    }
  }

  // Move to the previous question.
  void _goToPreviousQuestion() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });
    }
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
      appBar: AppBar(
        title: const Text("Compare"),
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
            children: [
              // Shape grids
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShapeGrid(
                      currentQuestion.compareNumber1, 'assets/circle.png'),
                  _buildShapeGrid(
                      currentQuestion.compareNumber2, 'assets/triangle.png'),
                ],
              ),
              const SizedBox(height: 30),
              // Question text
              const Text(
                "The number of circles is ____ the number of triangles.",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Options
              _buildOptions(),
              const SizedBox(height: 30),
              // Navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: currentIndex > 0 ? _goToPreviousQuestion : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 15),
                      textStyle: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    child: const Text("Previous"),
                  ),
                  ElevatedButton(
                    onPressed: selectedOptionIndices[currentIndex] != null
                        ? _goToNextQuestion
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 25, vertical: 15),
                      textStyle: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    child: const Text("Next"),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Score display (only current score)
              Text(
                "Score: $score",
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple),
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
          // Overlay icon if available
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
