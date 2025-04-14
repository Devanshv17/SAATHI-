import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LetUsCountPage extends StatefulWidget {
  const LetUsCountPage({Key? key}) : super(key: key);

  @override
  _LetUsCountPageState createState() => _LetUsCountPageState();
}

class _LetUsCountPageState extends State<LetUsCountPage> {
  int score = 0;
  String question = "";
  int imageCount = 0;
  List<String> imageAssets = [];
  List<Map<String, dynamic>> options = [];
  Set<String> shownQuestions = {};
  List<Map<String, dynamic>> previousQuestions = [];
  int currentQuestionIndex = -1;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    fetchNewQuestion();
  }

  // Returns a random asset path (either circle or triangle)
  String getRandomAsset() {
    return _random.nextBool() ? 'assets/circle.png' : 'assets/triangle.png';
  }

  Future<void> fetchNewQuestion() async {
    // If navigating forward to a question already answered.
    if (currentQuestionIndex + 1 < previousQuestions.length) {
      setState(() {
        currentQuestionIndex++;
        final current = previousQuestions[currentQuestionIndex];
        question = current['question'];
        imageCount = current['imageCount'];
        imageAssets = List<String>.from(current['imageAssets']);
        options = List<Map<String, dynamic>>.from(current['options']);
      });
      return;
    }

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('Let us Count')
          .get(const GetOptions(source: Source.serverAndCache));

      if (snapshot.docs.isNotEmpty) {
        List<QueryDocumentSnapshot> allQuestions = snapshot.docs;
        allQuestions.shuffle();

        for (var doc in allQuestions) {
          var data = doc.data() as Map<String, dynamic>;
          // Use the 'text' field for the question.
          if (!shownQuestions.contains(data['text'])) {
            var fetchedQuestion =
                data['text'] ?? "What is the number of objects shown in the image?";
            // Parse the numberField to get the count.
            int fetchedCount =
                int.tryParse(data['numberField']?.toString() ?? "0") ?? 0;
            // Generate a list of asset image paths based on the numberField
            List<String> fetchedAssets = List.generate(
                fetchedCount, (_) => getRandomAsset());
            // For options, assume we display the 'description' string.
            var fetchedOptions =
            List<Map<String, dynamic>>.from(data['options'])
                .map((o) => {...o, 'selected': false})
                .toList();

            setState(() {
              question = fetchedQuestion;
              imageCount = fetchedCount;
              imageAssets = fetchedAssets;
              options = fetchedOptions;
              shownQuestions.add(fetchedQuestion);
              previousQuestions.add({
                'question': fetchedQuestion,
                'imageCount': fetchedCount,
                'imageAssets': fetchedAssets,
                'options': fetchedOptions,
              });
              currentQuestionIndex++;
            });
            return;
          }
        }
        // If all questions have been shown, clear the list and re-fetch
        setState(() {
          shownQuestions.clear();
        });
        fetchNewQuestion();
      }
    } catch (e) {
      print("Error fetching question: $e");
    }
  }

  void goToPreviousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
        var current = previousQuestions[currentQuestionIndex];
        question = current['question'];
        imageCount = current['imageCount'];
        imageAssets = List<String>.from(current['imageAssets']);
        options = List<Map<String, dynamic>>.from(current['options']);
      });
    }
  }

  void checkAnswer(bool isCorrect, int index) {
    if (options.any((o) => o['selected'] == true)) return;

    setState(() {
      if (isCorrect) score++;
      for (int i = 0; i < options.length; i++) {
        options[i]['selected'] = (i == index);
      }
      previousQuestions[currentQuestionIndex]['options'] = options;
    });
  }

  bool get isOptionSelected => options.any((o) => o['selected'] == true);

  void showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Instructions"),
        content: const Text(
          "1. Tap the option that correctly represents the number of images.\n"
              "2. A green border appears for correct answers.\n"
              "3. A red border appears for wrong answers.\n"
              "4. Your score increases only for correct answers.\n"
              "5. Use 'Previous' or 'Next' to navigate between questions.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it!"),
          ),
        ],
      ),
    );
  }

  Widget buildOptionCard(Map<String, dynamic> option, int index) {
    bool isSelected = option['selected'] == true;
    bool isCorrect = option['isCorrect'];

    return GestureDetector(
      onTap: isSelected ? null : () => checkAnswer(isCorrect, index),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                color: isCorrect ? Colors.green : Colors.red,
                width: 4,
              )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              // Display the description as the option text.
              child: Text(
                option['description'] ?? "",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Optionally, you can display additional description information.
          if (isSelected && option['title'] != null && option['title'] != "")
            Positioned(
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  option['title'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build a widget that displays a row of asset images.
// Build a widget that displays a row of asset images.
  Widget buildImagesRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: imageAssets.map((assetPath) {
        return Image.asset(
          assetPath,
          height: 40, // reduced from 60
          width: 40,  // reduced from 60
        );
      }).toList(),
    );
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
              "Let Us Count",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline,
                  color: Colors.white, size: 28),
              onPressed: () => showInstructions(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display the question text.
            Text(
              question.isNotEmpty ? question : "Loading question...",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 12),
            // Display the images row based on the numberField.
            if (imageAssets.isNotEmpty)
              Center(
                child: buildImagesRow(),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(), // disable scrolling
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: options.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.2,
                ),
                itemBuilder: (context, index) =>
                    buildOptionCard(options[index], index),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                "Your Score: $score",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentQuestionIndex > 0
                        ? Colors.orange
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onPressed:
                  currentQuestionIndex > 0 ? goToPreviousQuestion : null,
                  child: const Text(
                    "Previous",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    isOptionSelected ? Colors.green : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  onPressed:
                  isOptionSelected ? fetchNewQuestion : null,
                  child: const Text(
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
}
