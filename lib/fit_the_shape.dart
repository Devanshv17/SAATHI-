import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FittheShapePage extends StatefulWidget {
  const FittheShapePage({Key? key}) : super(key: key);

  @override
  _FittheShapePageState createState() => _FittheShapePageState();
}

class _FittheShapePageState extends State<FittheShapePage> {
  int score = 0;
  String question = "";
  String? imageUrl;
  List<Map<String, dynamic>> options = [];
  Set<String> shownQuestions = {};
  List<Map<String, dynamic>> previousQuestions = [];
  int currentQuestionIndex = -1;

  @override
  void initState() {
    super.initState();
    fetchNewQuestion();
  }

  Future<void> fetchNewQuestion() async {
    // If navigating forward to a question already answered.
    if (currentQuestionIndex + 1 < previousQuestions.length) {
      setState(() {
        currentQuestionIndex++;
        var current = previousQuestions[currentQuestionIndex];
        question = current['question'];
        imageUrl = current['imageUrl'];
        options = List<Map<String, dynamic>>.from(current['options']);
      });
      return;
    }

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('Fit the Shape')
          .get(const GetOptions(source: Source.serverAndCache));

      if (snapshot.docs.isNotEmpty) {
        List<QueryDocumentSnapshot> allQuestions = snapshot.docs;
        allQuestions.shuffle();

        for (var doc in allQuestions) {
          var data = doc.data() as Map<String, dynamic>;
          if (!shownQuestions.contains(data['text'])) {
            var fetchedQuestion = data['text'] ?? "What is this?";
            var fetchedImageUrl = data['imageUrl'];
            var fetchedOptions = List<Map<String, dynamic>>.from(data['options'])
                .map((o) => {...o, 'selected': false})
                .toList();

            setState(() {
              question = fetchedQuestion;
              imageUrl = fetchedImageUrl;
              options = fetchedOptions;
              shownQuestions.add(fetchedQuestion);
              previousQuestions.add({
                'question': fetchedQuestion,
                'imageUrl': fetchedImageUrl,
                'options': fetchedOptions,
              });
              currentQuestionIndex++;
            });
            return;
          }
        }
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
        imageUrl = current['imageUrl'];
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
          "1. Tap the correct option.\n"
              "2. A green border appears for correct answers.\n"
              "3. A red border appears for wrong answers.\n"
              "4. Your score increases only for correct answers.\n"
              "5. Click 'Previous' or 'Next' to navigate.",
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
              child: Text(
                option['title'],
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (isSelected && option['description'] != null && option['description'] != "")
            Positioned(
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  option['description'],
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
              "Fit the Shape",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white, size: 28),
              onPressed: () => showInstructions(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0), // reduced padding
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.isNotEmpty ? question : "Loading question...",
              style: TextStyle(
                fontSize: 20, // reduced font size
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 8),
            if (imageUrl != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.network(
                    imageUrl!,
                    height: 120, // reduced image height
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), // disable scrolling
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8, // tighter spacing
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.2, // increased ratio for shorter vertical boxes
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
                    backgroundColor: currentQuestionIndex > 0 ? Colors.orange : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: currentQuestionIndex > 0 ? goToPreviousQuestion : null,
                  child: const Text(
                    "Previous",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOptionSelected ? Colors.green : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onPressed: isOptionSelected ? fetchNewQuestion : null,
                  child: const Text(
                    "Next",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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