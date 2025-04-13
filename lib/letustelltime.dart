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
            String fetchedQuestion =
                data['text'] ?? "What time is shown by the clock? 10:30";
            List<Map<String, dynamic>> fetchedOptions =
            List<Map<String, dynamic>>.from(data['options']);
            // Mark each option as not selected.
            fetchedOptions = fetchedOptions.map((option) {
              return {...option, 'selected': false};
            }).toList();

            // Try to extract a time in HH:mm format from the question.
            final timeMatch =
            RegExp(r'(\d{1,2}):(\d{2})').firstMatch(fetchedQuestion);
            DateTime? parsedTime;
            if (timeMatch != null) {
              int hour = int.parse(timeMatch.group(1)!);
              int minute = int.parse(timeMatch.group(2)!);
              // Ensure seconds are zero.
              parsedTime = DateTime(2025, 1, 1, hour, minute, 0);
            } else {
              // Fallback default time.
              parsedTime = DateTime(2025, 1, 1, 10, 30, 0);
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

    // Format the clockTime as "H:mm".
    String correctAnswer = "";
    if (clockTime != null) {
      correctAnswer = DateFormat("H:mm").format(clockTime!);
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

  // New helper method to build an option card with smaller dimensions.
  Widget buildOptionCard(Map<String, dynamic> option, int index) {
    bool isSelected = option['selected'] == true;
    // Determine correct answer using the static clockTime.
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
              fontSize: 18, // reduced font size for a smaller option
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
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
          children: const [
            Text(
              "Let Us Tell Time",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0), // reduced padding
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
                    // Using a unique key ensures that the clock widget rebuilds
                    // with the new static time for every question.
                    child: AnalogClock(
                      key: ValueKey(clockTime),
                      dateTime: clockTime!,
                      // If you have an option (e.g., isLive) to disable live updates,
                      // set it here. Otherwise, the provided time remains static.
                      dialColor: Colors.white,
                      hourHandColor: Colors.black,
                      minuteHandColor: Colors.black,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            // Display answer options in a smaller grid.
            Expanded(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(), // disable scrolling for options
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: options.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,    // tighter spacing vertically
                  crossAxisSpacing: 8,   // tighter spacing horizontally
                  childAspectRatio: 1.2, // adjust ratio to keep options shorter
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
            // Navigation buttons for Previous and Next.
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
