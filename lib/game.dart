// unchanged imports
import 'dart:ui'; // for ImageFilter
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart';

class GamePage extends StatefulWidget {
  final String gameTitle;
  final bool isHindi;

  const GamePage({Key? key, required this.gameTitle, required this.isHindi})
      : super(key: key);

  @override
  _GamePageState createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  String questionText = "";
  String currentDocId = "";
  List<Map<String, dynamic>> options = [];

  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;
  Map<String, dynamic> userAnswers = {};

  List<QueryDocumentSnapshot> allQuestions = [];
  int currentQuestionIndex = 0;

  int? _selectedOptionIndex;
  bool _hasSubmitted = false;
  bool _isCorrectSubmission = false;

  DateTime? _questionStartTime;
  DateTime? _gameStartTime;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _gameStartTime = DateTime.now(); 
    _loadGameState().then((_) => _fetchQuestions());
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

  Future<void> _recordGameVisit() async {
    final user = _auth.currentUser;
    final start = _gameStartTime;
    if (user == null || start == null) return;

    final now = DateTime.now();
    final seconds = now.difference(start).inSeconds;
    final dateKey = now.toIso8601String().substring(0, 10); // “YYYY-MM-DD”

    // Path in your Realtime DB:
    final path =
        "users/${user.uid}/games/${widget.gameTitle}/gameVisits/$dateKey";

    // 1) Read previous total (or zero)
    final snap = await _dbRef.child(path).get();
    final prev = (snap.exists && snap.value is int) ? snap.value as int : 0;

    // 2) Write updated total
    await _dbRef.child(path).set(prev + seconds);
  }


  Future<void> _fetchQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(widget.gameTitle)
          .orderBy('timestamp')
          .get();

      setState(() {
        allQuestions = snapshot.docs;
      });

      if (currentQuestionIndex >= allQuestions.length) {
        _navigateToResult();
      } else {
        _loadQuestionFromIndex(currentQuestionIndex);
      }
    } catch (e) {
      print("Error fetching questions: $e");
    }
  }

  void _loadQuestionFromIndex(int index) {
    if (index < 0 || index >= allQuestions.length) return;
    final doc = allQuestions[index];
    final data = doc.data() as Map<String, dynamic>;

    bool alreadyAnswered = userAnswers.containsKey(doc.id);
    int? savedIndex;
    bool savedCorrect = false;
    if (alreadyAnswered) {
      final saved = userAnswers[doc.id];
      savedIndex = saved['selectedOptionIndex'] as int?;
      savedCorrect = saved['isCorrect'] as bool? ?? false;
    }

    setState(() {
      currentQuestionIndex = index;
      currentDocId = doc.id;
      questionText = data['text'] ?? "Question";
      options = List<Map<String, dynamic>>.from(data['options'] ?? []);
      _questionStartTime = DateTime.now(); // start timer
      if (alreadyAnswered && savedIndex != null) {
        _selectedOptionIndex = savedIndex;
        _hasSubmitted = true;
        _isCorrectSubmission = savedCorrect;
      } else {
        _selectedOptionIndex = null;
        _hasSubmitted = false;
        _isCorrectSubmission = false;
      }
    });
  }

  void _goToPreviousQuestion() {
    if (currentQuestionIndex > 0) {
      _loadQuestionFromIndex(currentQuestionIndex - 1);
      _saveGameState();
    }
  }

  void _goToNextQuestion() {
    if (currentQuestionIndex < allQuestions.length - 1) {
      _loadQuestionFromIndex(currentQuestionIndex + 1);
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
/// 1. Update `/users/{uid}/today_activity`
  Future<void> _updateTodayActivity(bool isCorrect) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final dateKey = now.toIso8601String().substring(0, 10); // "YYYY-MM-DD"
    final ref = _dbRef.child('users/$uid/today_activity');

    // read old
    final snap = await ref.get();
    Map old =
        snap.exists && snap.value is Map ? Map.from(snap.value as Map) : {};
    final oldDate = old['date'] as String? ?? '';
    int oldCorrect = oldDate == dateKey ? (old['correct'] as int? ?? 0) : 0;
    int oldIncorrect = oldDate == dateKey ? (old['incorrect'] as int? ?? 0) : 0;

    // compute new
    final newCorrect = oldCorrect + (isCorrect ? 1 : 0);
    final newIncorrect = oldIncorrect + (isCorrect ? 0 : 1);

    // write back
    await ref.set({
      'date': dateKey,
      'correct': newCorrect,
      'incorrect': newIncorrect,
    });
  }


Future<void> _updateStreakAndStats(bool isCorrect) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final yesterday = today.subtract(Duration(days: 1));
    final yesterdayStr = yesterday.toIso8601String().substring(0, 10);

    final streakRef = _dbRef.child('users/$uid/streak');
    final scoreRef = _dbRef.child('users/$uid/score');
    final attemptedRef = _dbRef.child('users/$uid/totalAttempted');

    // 🔁 1. Handle Streak
    final streakSnap = await streakRef.get();
    String lastDate = '';
    int streakCount = 0;
    if (streakSnap.exists) {
      final data = Map<String, dynamic>.from(streakSnap.value as Map);
      lastDate = data['date'] ?? '';
      streakCount = data['count'] ?? 0;
    }

    if (lastDate == todayStr) {
      // Already played today, don't change streak
    } else if (lastDate == yesterdayStr) {
      streakCount += 1;
    } else {
      streakCount = 1; // broken streak or first time
    }

    // ✅ Save streak
    await streakRef.set({
      'date': todayStr,
      'count': streakCount,
    });

    // 🧠 2. Handle Score
    if (isCorrect) {
      final scoreSnap = await scoreRef.get();
      int prevScore = (scoreSnap.exists && scoreSnap.value is int)
          ? scoreSnap.value as int
          : 0;
      await scoreRef.set(prevScore + 1);
    }

    // 📊 3. Handle Total Attempted
    final attemptSnap = await attemptedRef.get();
    int prevAttempt = (attemptSnap.exists && attemptSnap.value is int)
        ? attemptSnap.value as int
        : 0;
    await attemptedRef.set(prevAttempt + 1);
  }

  /// 3. Update `/users/{uid}/monthlyStats`
  Future<void> _updateMonthlyStats(bool isCorrect) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final dateKey = now.toIso8601String().substring(0, 10);
    final monthKey = dateKey.substring(0, 7); // "YYYY-MM"
    final refMonth = _dbRef.child('users/$uid/monthlyStats');

    // If month has rolled over, remove last month’s data
    final snapMonth = await refMonth.get();
    if (snapMonth.exists && snapMonth.value is Map) {
      final anyKey = (snapMonth.value as Map).keys.first as String;
      if (!anyKey.startsWith(monthKey)) {
        // clear all last month
        await refMonth.remove();
      }
    }

    // increment today’s entry
    final snapToday = await refMonth.child(dateKey).get();
    int oldC = snapToday.exists && snapToday.value is Map
        ? (snapToday.child('correct').value as int? ?? 0)
        : 0;
    int oldI = snapToday.exists && snapToday.value is Map
        ? (snapToday.child('incorrect').value as int? ?? 0)
        : 0;

    await refMonth.child(dateKey).set({
      'correct': oldC + (isCorrect ? 1 : 0),
      'incorrect': oldI + (isCorrect ? 0 : 1),
    });
  }

  void _selectOption(int index) {
    if (_hasSubmitted || userAnswers.containsKey(currentDocId)) return;
    setState(() {
      _selectedOptionIndex = index;
    });
  }

  void _submitAnswer() {
    if (_hasSubmitted || _selectedOptionIndex == null) return;
    final now = DateTime.now();
    final duration = _questionStartTime != null
        ? now.difference(_questionStartTime!)
        : Duration.zero;
    bool isCorrect = options[_selectedOptionIndex!]['isCorrect'] == true;

    setState(() {
      _hasSubmitted = true;
      _isCorrectSubmission = isCorrect;
      if (isCorrect) {
        score++;
        correctCount++;
      } else {
        incorrectCount++;
      }
      userAnswers[currentDocId] = {
        "selectedOptionIndex": _selectedOptionIndex,
        "isCorrect": isCorrect,
        "timeTakenSeconds": duration.inSeconds, // store time taken
      };
    });
// update Firebase activity logs:
    _updateTodayActivity(isCorrect);

    _updateMonthlyStats(isCorrect);
    _updateStreakAndStats(isCorrect);
    _saveGameState();
  }

  void showInstructions(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(widget.isHindi ? "निर्देश" : "Instructions"),
        content: Text(widget.isHindi
            ? "१. विकल्प चुनने के लिए टैप करें (नीले बॉर्डर).\n"
                "२. अपनी पसंद लॉक करने के लिए जमा करें पर टैप करें.\n"
                "३. सही उत्तर: हरा टिक; गलत उत्तर: लाल क्रॉस .\n"
                "४. आगे/पीछे जाने के लिए अगला/पिछला उपयोग करें.\n"
                "५. आपकी प्रगति सेव हो जाती है."
            : "1. Tap an option to select (blue border).\n"
                "2. Tap Submit to lock in your choice.\n"
                "3. Correct: green tick ; incorrect: red cross .\n"
                "4. Use Previous/Next to navigate.\n"
                "5. Progress is saved."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isHindi ? "ठीक है" : "Got it!"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _saveGameState();
    _recordGameVisit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canGoPrevious = currentQuestionIndex > 0;
    final canSubmit = !_hasSubmitted &&
        _selectedOptionIndex != null &&
        !userAnswers.containsKey(currentDocId);
    final canGoNext = _hasSubmitted || userAnswers.containsKey(currentDocId);

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
              icon: Icon(Icons.info_outline, color: Colors.white),
              onPressed: () => showInstructions(context),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            Text(
              questionText.isNotEmpty
                  ? questionText
                  : widget.isHindi
                      ? "प्रश्न लोड हो रहा है..."
                      : "Loading question...",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                itemCount: options.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 15,
                  crossAxisSpacing: 15,
                ),
                itemBuilder: (_, index) {
                  bool isSelected = _selectedOptionIndex == index;
                  bool showResult = _hasSubmitted && isSelected;
                  bool isCorrect = options[index]['isCorrect'] == true;
                  return GestureDetector(
                    onTap: () => _selectOption(index),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: isSelected && !_hasSubmitted
                                ? Border.all(color: Colors.blue, width: 4)
                                : showResult
                                    ? Border.all(
                                        color: isCorrect
                                            ? Colors.green
                                            : Colors.red,
                                        width: 6)
                                    : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                blurRadius: 5,
                                spreadRadius: 2,
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.network(
                                    options[index]['imageUrl'],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                if (showResult)
                                  Positioned.fill(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 1, sigmaY: 1),
                                      child: Container(
                                          color: Colors.black.withOpacity(0.2)),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (showResult)
                          Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                              size: 80,
                              color: isCorrect ? Colors.green : Colors.red),
                      ],
                    ),
                  );
                },
              ),
            ),

            
            const SizedBox(height: 15),
            Column(
              children: [
                Text(widget.isHindi ? "अंक: $score" : "Score: $score",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(
                    widget.isHindi
                        ? "सही: $correctCount | गलत: $incorrectCount"
                        : "Correct: $correctCount | Incorrect: $incorrectCount",
                    style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: canGoPrevious ? _goToPreviousQuestion : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          canGoPrevious ? Colors.orange : Colors.grey),
                  child: Text(widget.isHindi ? "पिछला" : "Previous",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: canSubmit ? _submitAnswer : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: canSubmit ? Colors.blue : Colors.grey),
                  child: Text(widget.isHindi ? "जमा करें" : "Submit",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: canGoNext ? _goToNextQuestion : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: canGoNext ? Colors.green : Colors.grey),
                  child: Text(widget.isHindi ? "अगला" : "Next",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
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
