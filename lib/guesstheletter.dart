import 'dart:ui'; // for ImageFilter
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'result.dart';

class GuessTheLetterPage extends StatefulWidget {
  final String gameTitle;
  final bool isHindi;
  const GuessTheLetterPage({
    Key? key,
    required this.gameTitle,
    required this.isHindi,
  }) : super(key: key);

  @override
  _GuessTheLetterPageState createState() => _GuessTheLetterPageState();
}

class _GuessTheLetterPageState extends State<GuessTheLetterPage> {
  String questionText = "";
  String currentDocId = "";
  List<Map<String, dynamic>> options = [];
  String? imageUrl;

  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;
  int currentQuestionIndex = 0;
  Map<String, dynamic> userAnswers = {};

  int? _selectedOptionIndex;
  bool _hasSubmitted = false;
  DateTime? _questionStartTime;
  DateTime? _gameStartTime;
  

  List<QueryDocumentSnapshot> allQuestions = [];

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
    final snap =
        await _dbRef.child("users/${user.uid}/games/${widget.gameTitle}").get();
    if (snap.exists && snap.value != null) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      setState(() {
        score = data['score'] ?? 0;
        correctCount = data['correctCount'] ?? 0;
        incorrectCount = data['incorrectCount'] ?? 0;
        currentQuestionIndex = data['currentQuestionIndex'] ?? 0;
        userAnswers = Map<String, dynamic>.from(data['answers'] ?? {});
      });
    }
  }

  Future<void> _saveGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _dbRef.child("users/${user.uid}/games/${widget.gameTitle}").update({
      "score": score,
      "correctCount": correctCount,
      "incorrectCount": incorrectCount,
      "currentQuestionIndex": currentQuestionIndex,
      "answers": userAnswers,
    });
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
  }

  void _loadQuestionFromIndex(int idx) {
    if (idx < 0 || idx >= allQuestions.length) return;
    final doc = allQuestions[idx];
    final data = doc.data() as Map<String, dynamic>;
    final saved = userAnswers[doc.id];

    setState(() {
      currentDocId = doc.id;
      questionText = data['text'] ?? "Question";
      imageUrl = data['imageUrl'] as String?;
      options = List<Map<String, dynamic>>.from(data['options'] as List? ?? []);
      _selectedOptionIndex =
          saved != null ? saved['selectedOptionIndex'] as int? : null;
      _hasSubmitted = saved != null;
      _questionStartTime = DateTime.now();
    });
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

  void _selectOption(int i) {
    if (_hasSubmitted) return;
    setState(() => _selectedOptionIndex = i);
  }

  void _submitAnswer() {
    if (_hasSubmitted || _selectedOptionIndex == null) return;
    final now = DateTime.now();
    final duration = _questionStartTime != null
        ? now.difference(_questionStartTime!)
        : Duration.zero;
    final i = _selectedOptionIndex!;
    final correct = options[i]['isCorrect'] as bool? ?? false;

    setState(() {
      _hasSubmitted = true;
      if (correct) {
        score++;
        correctCount++;
      } else {
        incorrectCount++;
      }
      userAnswers[currentDocId] = {
        'selectedOptionIndex': i,
        'isCorrect': correct,
        'timeTakenSeconds': duration.inSeconds,
      };
    });
    // update Firebase activity logs:
    _updateTodayActivity(correct);
    _updateMonthlyStats(correct);
    _updateStreakAndStats(correct);
    _saveGameState();
  }

  void _goToPreviousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
        _hasSubmitted = false;
      });
      _loadQuestionFromIndex(currentQuestionIndex);
    }
  }

  void _goToNextQuestion() {
    if (!_hasSubmitted && !userAnswers.containsKey(currentDocId)) return;
    if (currentQuestionIndex < allQuestions.length - 1) {
      setState(() {
        currentQuestionIndex++;
        _hasSubmitted = false;
      });
      _loadQuestionFromIndex(currentQuestionIndex);
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

  @override
  void dispose() {
    _saveGameState();
     _recordGameVisit();  
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        backgroundColor: Colors.blue.shade300,
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.gameTitle,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.info_outline, size: 28),
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(widget.isHindi ? "निर्देश" : "Instructions"),
                  content: Text(
                    widget.isHindi
                        ? "१. विकल्प चुनें (नीला बॉर्डर).\n"
                            "२. जमा करें पर टैप करें.\n"
                            "३. सही: हरा टिक; गलत: लाल क्रॉस.\n"
                            "४. Prev/Next.\n"
                            "५. प्रगति सेव."
                        : "1. Tap an option (blue border).\n"
                            "2. Tap Submit.\n"
                            "3. Correct: green tick; incorrect: red cross.\n"
                            "4. Use Previous/Next.\n"
                            "5. Progress is saved.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.isHindi ? "ठीक है" : "Got it!"),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              questionText,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (imageUrl != null) Image.network(imageUrl!, height: 100),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (ctx, i) => buildOptionCard(options[i], i),
            ),
            const SizedBox(height: 20),
            Text(
              widget.isHindi ? "अंक: $score" : "Score: $score",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isHindi
                  ? "सही: $correctCount | गलत: $incorrectCount"
                  : "Correct: $correctCount | Incorrect: $incorrectCount",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _goToPreviousQuestion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        currentQuestionIndex > 0 ? Colors.orange : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(widget.isHindi ? "पिछला" : "Previous",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: (_selectedOptionIndex != null && !_hasSubmitted)
                      ? _submitAnswer
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        (_selectedOptionIndex != null && !_hasSubmitted)
                            ? Colors.blue
                            : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(widget.isHindi ? "जमा करें" : "Submit",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: _hasSubmitted ? _goToNextQuestion : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasSubmitted ? Colors.green : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                  ),
                  child: Text(widget.isHindi ? "अगला" : "Next",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildOptionCard(Map<String, dynamic> option, int index) {
    final isSel = _selectedOptionIndex == index;
    final showRes = _hasSubmitted && isSel;
    final corr = option['isCorrect'] as bool? ?? false;

    return GestureDetector(
      onTap: () => _selectOption(index),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isSel && !_hasSubmitted
                  ? Border.all(color: Colors.blue, width: 4)
                  : showRes
                      ? Border.all(
                          color: corr ? Colors.green : Colors.red, width: 4)
                      : null,
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    spreadRadius: 1),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: Text(
                  option['title'] as String,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          if (showRes)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                corr ? Icons.check_circle : Icons.cancel,
                size: 50,
                color: corr ? Colors.green : Colors.red,
              ),
            ),
        ],
      ),
    );
  }
}
