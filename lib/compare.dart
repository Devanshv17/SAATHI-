import 'dart:ui'; // for ImageFilter
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart'; // Import your ResultPage

class ComparePage extends StatefulWidget {
  final String gameTitle;
  final bool isHindi;

  const ComparePage({
    Key? key,
    required this.gameTitle,
    required this.isHindi,
  }) : super(key: key);

  @override
  _ComparePageState createState() => _ComparePageState();
}

class _ComparePageState extends State<ComparePage> {
  // Full question documents fetched from Firestore
  List<QueryDocumentSnapshot> allQuestions = [];
  String currentDocId = '';

  // Current progress counters
  int currentIndex = 0;
  int score = 0;
  int correctCount = 0;
  int incorrectCount = 0;

  // Map<docId, answerData>
  // answerData: { selectedOptionIndex, isCorrect, timeTakenSeconds }
  Map<String, Map<String, dynamic>> userAnswers = {};

  // Current question options & UI state
  List<CompareOption> options = [];
  int? _selectedOptionIndex;
  bool _hasSubmitted = false;
  DateTime? _questionStartTime;
  // Add this alongside your other fields:
  DateTime? _gameStartTime;


  bool isLoading = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Assets for shapes
  final List<String> shapeAssets = [
    'assets/triangle.png',
    'assets/circle.png',
    'assets/book.png',
    'assets/pencil.png',
  ];
  final Random _random = Random();

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
    if (!snap.exists || snap.value == null) return;

    final data = Map<String, dynamic>.from(snap.value as Map);
    setState(() {
      score = data['score'] ?? 0;
      correctCount = data['correctCount'] ?? 0;
      incorrectCount = data['incorrectCount'] ?? 0;
      currentIndex = data['currentIndex'] ?? 0;
      final saved = Map<String, dynamic>.from(data['answers'] ?? {});
      userAnswers =
          saved.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
    });
  }

  Future<void> _saveGameState() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _dbRef.child("users/${user.uid}/games/${widget.gameTitle}").update({
      "score": score,
      "correctCount": correctCount,
      "incorrectCount": incorrectCount,
      "currentIndex": currentIndex,
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
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(widget.gameTitle)
          .orderBy('timestamp')
          .get();
      allQuestions = snapshot.docs;

      if (allQuestions.isEmpty) {
        setState(() => isLoading = false);
        return;
      }
      if (currentIndex >= allQuestions.length) {
        _navigateToResult();
        return;
      }
      _loadQuestionFromIndex(currentIndex);
    } catch (e) {
      print('Error fetching questions: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _loadQuestionFromIndex(int idx) {
    final doc = allQuestions[idx];
    final data = doc.data() as Map<String, dynamic>;
    final saved = userAnswers[doc.id];

    setState(() {
      currentDocId = doc.id;
      options = (data['options'] as List<dynamic>?)
              ?.map((opt) => CompareOption.fromMap(opt))
              .toList() ??
          [];
      _selectedOptionIndex = saved?['selectedOptionIndex'] as int?;
      _hasSubmitted = saved != null;
      _questionStartTime = DateTime.now();
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
    final selected = _selectedOptionIndex!;
    final isCorrect = options[selected].isCorrect;

    setState(() {
      _hasSubmitted = true;
      if (isCorrect) {
        score++;
        correctCount++;
      } else {
        incorrectCount++;
      }
      userAnswers[currentDocId] = {
        'selectedOptionIndex': selected,
        'isCorrect': isCorrect,
        'timeTakenSeconds': duration.inSeconds,
      };
    });
    _saveGameState();
  }

  void _goToNextQuestion() {
    if (!_hasSubmitted && !userAnswers.containsKey(currentDocId)) return;
    if (currentIndex < allQuestions.length - 1) {
      setState(() {
        currentIndex++;
        _hasSubmitted = false;
        _selectedOptionIndex = null;
      });
      _loadQuestionFromIndex(currentIndex);
    } else {
      _navigateToResult();
    }
  }

  void _goToPreviousQuestion() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
        _hasSubmitted = false;
        _selectedOptionIndex = null;
      });
      _loadQuestionFromIndex(currentIndex);
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
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (allQuestions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No Compare questions available.')),
      );
    }

    final data = allQuestions[currentIndex].data() as Map<String, dynamic>;
    final num1 = int.tryParse(data['compareNumber1']?.toString() ?? '') ?? 0;
    final num2 = int.tryParse(data['compareNumber2']?.toString() ?? '') ?? 0;

    // Generate shape grids
    final leftAssets = List<String>.generate(
        num1, (_) => shapeAssets[_random.nextInt(shapeAssets.length)]);
    final rightAssets = List<String>.generate(
        num2, (_) => shapeAssets[_random.nextInt(shapeAssets.length)]);

    return Scaffold(
      backgroundColor: Colors.lightBlue[50],
      appBar: AppBar(
        title: Text(widget.gameTitle,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.isHindi
                    ? 'सही चिन्ह चुनें:'
                    : 'Choose the correct sign:',
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _buildShapeGrid(leftAssets)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildShapeGrid(rightAssets)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.isHindi
                    ? 'अ                          ब'
                    : 'A                          B',
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              Column(
                children: List.generate(options.length, (i) {
                  final opt = options[i];
                  final isSel = _selectedOptionIndex == i;
                  final show = _hasSubmitted && isSel;
                  final ok = opt.isCorrect;
                  Color border = Colors.grey;
                  if (isSel && !_hasSubmitted) border = Colors.blue;
                  if (show) border = ok ? Colors.green : Colors.red;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OptionTile(
                      text: opt.title,
                      borderColor: border,
                      overlayIcon: show
                          ? Icon(ok ? Icons.check_circle : Icons.cancel,
                              color: ok ? Colors.green : Colors.red, size: 50)
                          : null,
                      onTap: () => _selectOption(i),
                      isHindi: widget.isHindi,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 15),
              Text(
                widget.isHindi ? 'अंक: $score' : 'Score: $score',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                widget.isHindi
                    ? 'सही: $correctCount | गलत: $incorrectCount'
                    : 'Correct: $correctCount | Incorrect: $incorrectCount',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: currentIndex > 0 ? _goToPreviousQuestion : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            currentIndex > 0 ? Colors.orange : Colors.grey),
                    child: Text(widget.isHindi ? 'पिछला' : 'Previous',
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
                                : Colors.grey),
                    child: Text(widget.isHindi ? 'जमा करें' : 'Submit',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    onPressed: _hasSubmitted ? _goToNextQuestion : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _hasSubmitted ? Colors.green : Colors.grey),
                    child: Text(widget.isHindi ? 'अगला' : 'Next',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInstructionsDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(widget.isHindi ? 'निर्देश' : 'Instructions'),
        content: Text(
          widget.isHindi
              ? '१. आकृतियों की तुलना करें।\n२. विकल्प चुनें।\n३. जमा करें पर टैप करें।\n४. सही/गलत टिक देखें।\n५. प्रगति सहेजी जाती है।'
              : '1. Compare shapes.\n2. Tap option.\n3. Tap Submit.\n4. See correct/incorrect.\n5. Progress is saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.isHindi ? 'ठीक है' : 'Got it!'),
          ),
        ],
      ),
    );
  }

  Widget _buildShapeGrid(List<String> assets) {
    return Container(
      padding: const EdgeInsets.all(8),
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
          ),
        ],
      ),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: assets
            .map((path) => Image.asset(path, width: 40, height: 40))
            .toList(),
      ),
    );
  }
}

// OptionTile widget
class OptionTile extends StatelessWidget {
  final String text;
  final Color borderColor;
  final Widget? overlayIcon;
  final VoidCallback? onTap;
  final bool isHindi;

  const OptionTile({
    Key? key,
    required this.text,
    required this.borderColor,
    this.overlayIcon,
    this.onTap,
    required this.isHindi,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: borderColor, width: 4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isHindi ? 'अ   $text   ब' : 'A   $text   B',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          if (overlayIcon != null)
            Positioned(
              right: 10,
              top: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                  child: overlayIcon!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// CompareOption model
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
