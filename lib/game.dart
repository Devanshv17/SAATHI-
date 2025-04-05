import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GamePage extends StatefulWidget {
  final String gameTitle;

  const GamePage({Key? key, required this.gameTitle}) : super(key: key);

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  int score = 0;
  String question = "";
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
    if (currentQuestionIndex + 1 < previousQuestions.length) {
      setState(() {
        currentQuestionIndex++;
        var current = previousQuestions[currentQuestionIndex];
        question = current['question'];
        options = List<Map<String, dynamic>>.from(current['options']);
      });
      return;
    }

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('Name Picture Matching')
          .get();

      if (snapshot.docs.isNotEmpty) {
        List<QueryDocumentSnapshot> allQuestions = snapshot.docs;
        allQuestions.shuffle();

        for (var doc in allQuestions) {
          var data = doc.data() as Map<String, dynamic>;
          if (!shownQuestions.contains(data['text'])) {
            var fetchedQuestion = data['text'] ?? "What is this?";
            var fetchedOptions =
                List<Map<String, dynamic>>.from(data['options']);

            setState(() {
              question = fetchedQuestion;
              options = fetchedOptions;
              shownQuestions.add(question);
              previousQuestions.add({
                'question': question,
                'options': fetchedOptions
                    .map((o) => {...o, 'selected': false})
                    .toList(),
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
        title: Text("Instructions"),
        content: Text(
          "1. Tap the correct image.\n"
          "2. A green tick appears for correct answers.\n"
          "3. A red cross appears and image blurs for wrong answers.\n"
          "4. Your score increases only for correct answers.\n"
          "5. Click 'Previous' or 'Next' to navigate.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Got it!"),
          ),
        ],
      ),
    );
  }

  Widget getIconOverlay(bool isCorrect, bool isSelected) {
    if (!isSelected) return SizedBox.shrink();
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: Icon(
          isCorrect ? Icons.check : Icons.close,
          color: isCorrect ? Colors.green : Colors.red,
          size: 80,
        ),
      ),
    );
  }

  Widget buildOptionImage(Map<String, dynamic> option, int index) {
    bool isSelected = option['selected'] == true;
    bool isCorrect = option['isCorrect'];

    return GestureDetector(
      onTap: isSelected ? null : () => checkAnswer(isCorrect, index),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: isSelected && !isCorrect ? 0.4 : 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: isSelected
                    ? Border.all(
                        color: isCorrect ? Colors.green : Colors.red,
                        width: 6,
                      )
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(option['imageUrl'], fit: BoxFit.cover),
              ),
            ),
          ),
          getIconOverlay(isCorrect, isSelected),
          if (isSelected && isCorrect)
            Positioned(
              bottom: 10,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  option['description'],
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
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
            Text(widget.gameTitle,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            IconButton(
              icon: Icon(Icons.info_outline, color: Colors.white, size: 28),
              onPressed: () => showInstructions(context),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question.isNotEmpty ? question : "Loading question...",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800]),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.only(bottom: 20),
                itemCount: options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                ),
                itemBuilder: (context, index) =>
                    buildOptionImage(options[index], index),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                "Your Score: $score",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  onPressed:
                      currentQuestionIndex > 0 ? goToPreviousQuestion : null,
                  child: Text("Previous",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isOptionSelected ? Colors.green : Colors.grey,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  onPressed: isOptionSelected ? fetchNewQuestion : null,
                  child: Text("Next",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
