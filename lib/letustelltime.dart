import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_analog_clock/flutter_analog_clock.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Let Us Tell Time',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: const LetUsTellTimePage(),
    );
  }
}

class LetUsTellTimePage extends StatefulWidget {
  const LetUsTellTimePage({Key? key}) : super(key: key);

  @override
  _LetUsTellTimePageState createState() => _LetUsTellTimePageState();
}

class _LetUsTellTimePageState extends State<LetUsTellTimePage> {
  int score = 0;
  String question = "";
  List<Map<String, dynamic>> options = [];
  Set<String> shownQuestions = {};
  List<Map<String, dynamic>> previousQuestions = [];
  int currentQuestionIndex = -1;
  DateTime? clockTime;

  @override
  void initState() {
    super.initState();
    fetchNewQuestion();
  }

  /// Fetch a new question from Firestore if there are no previous questions to revisit.
  Future<void> fetchNewQuestion() async {
    // If we already loaded questions before, try to move forward in our history.
    if (currentQuestionIndex + 1 < previousQuestions.length) {
      setState(() {
        currentQuestionIndex++;
        var current = previousQuestions[currentQuestionIndex];
        question = current['question'];
        options = List<Map<String, dynamic>>.from(current['options']);
        clockTime = current['clockTime'];
      });
      return;
    }

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('Let us Tell Time')
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Shuffle the list of documents.
        List<QueryDocumentSnapshot> allQuestions = snapshot.docs;
        allQuestions.shuffle();

        for (var doc in allQuestions) {
          var data = doc.data() as Map<String, dynamic>;
          // Use the question text as a unique identifier.
          if (!shownQuestions.contains(data['text'])) {
            String fetchedQuestion = data['text'] ?? "What time is shown by the clock? 10:30";
            List<Map<String, dynamic>> fetchedOptions = List<Map<String, dynamic>>.from(data['options']);
            // Mark each option as not selected.
            fetchedOptions = fetchedOptions.map((option) {
              return {...option, 'selected': false};
            }).toList();

            // Try to extract a time in HH:mm format from the question.
            final timeMatch = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(fetchedQuestion);
            DateTime? parsedTime;
            if (timeMatch != null) {
              int hour = int.parse(timeMatch.group(1)!);
              int minute = int.parse(timeMatch.group(2)!);
              parsedTime = DateTime(2025, 1, 1, hour, minute);
            } else {
              // Fallback default time.
              parsedTime = DateTime(2025, 1, 1, 10, 30);
            }

            setState(() {
              question = fetchedQuestion;
              options = fetchedOptions;
              clockTime = parsedTime;
              shownQuestions.add(fetchedQuestion);
              previousQuestions.add({
                'question': fetchedQuestion,
                'options': fetchedOptions,
                'clockTime': parsedTime,
              });
              currentQuestionIndex++;
            });
            return;
          }
        }

        // If all questions have been shown, reset.
        setState(() {
          shownQuestions.clear();
        });
        fetchNewQuestion();
      }
    } catch (e) {
      print("Error fetching question: $e");
    }
  }

  /// Navigate to the previous question if available.
  void goToPreviousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
        var current = previousQuestions[currentQuestionIndex];
        question = current['question'];
        options = List<Map<String, dynamic>>.from(current['options']);
        clockTime = current['clockTime'];
      });
    }
  }

  /// Checks the answer by comparing the selected option's title with the correct time.
  void checkAnswer(int index) {
    // Prevent re-selection if an option is already selected.
    if (options.any((o) => o['selected'] == true)) return;

    // Format the clockTime as "HH:mm".
    String correctAnswer = "";
    if (clockTime != null) {
      correctAnswer = DateFormat("H:mm").format(clockTime!);
      // Also try "HH:mm" format if needed:
      String padded = DateFormat("HH:mm").format(clockTime!);
      // Use the padded version if the option title is two-digit based.
      if (options[index]['title'] == padded ||
          options[index]['title'] == correctAnswer) {
        // Correct answer.
      }
    }

    bool isOptionCorrect = (options[index]['title'] == correctAnswer ||
        options[index]['title'] == DateFormat("HH:mm").format(clockTime!));

    setState(() {
      for (int i = 0; i < options.length; i++) {
        options[i]['selected'] = i == index;
      }
      if (isOptionCorrect) {
        score++;
      }
      // Save updated options in the previousQuestions list.
      previousQuestions[currentQuestionIndex]['options'] = options;
    });
  }

  bool get isOptionSelected => options.any((o) => o['selected'] == true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        backgroundColor: Colors.blue.shade300,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Let Us Tell Time",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The question text widget has been removed.
            const SizedBox(height: 20),
            // Display the analog clock if clockTime is set.
            if (clockTime != null)
              Center(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 4,
                        color: Colors.black12,
                        offset: Offset(2, 2),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: AnalogClock(
                      dateTime: clockTime!,
                      dialColor: Colors.white,
                      hourHandColor: Colors.black,
                      minuteHandColor: Colors.black,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // Display answer options.
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                ),
                itemBuilder: (context, index) {
                  var option = options[index];
                  bool isSelected = option['selected'] == true;
                  // For feedback: if an option is selected, show a border (green if correct, red if not).
                  String correctAnswer = "";
                  if (clockTime != null) {
                    correctAnswer = DateFormat("H:mm").format(clockTime!);
                  }
                  bool isCorrect = (option['title'] == correctAnswer ||
                      option['title'] == DateFormat("HH:mm").format(clockTime!));
                  return GestureDetector(
                    onTap: isSelected ? null : () => checkAnswer(index),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(
                          color: isCorrect ? Colors.green : Colors.red,
                          width: 3,
                        )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            blurRadius: 3,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          option['title'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                "Your Score: $score",
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
            ),
            const SizedBox(height: 20),
            // Navigation buttons for Previous and Next.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  onPressed: currentQuestionIndex > 0 ? goToPreviousQuestion : null,
                  child: const Text("Previous",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    isOptionSelected ? Colors.green : Colors.grey,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  onPressed: isOptionSelected ? fetchNewQuestion : null,
                  child: const Text("Next",
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