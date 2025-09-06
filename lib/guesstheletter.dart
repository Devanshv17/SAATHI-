import 'dart:async';
import 'dart:ui'; // for ImageFilter
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'result.dart';
import 'ai.dart';
import 'video_lesson.dart';

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
  // --- Firebase Instances ---
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  late final AiService _aiService;

  // --- State Management ---
  bool _isLoading = true;
  bool _isPretestMode = false;
  bool _pretestCompleted = false;
  bool _showPretestIntro = false;
  bool _showPretestResults = false;

  Map<String, dynamic> _gameState = {};
  List<Map<String, dynamic>> _questions = [];
  int _currentQuestionIndex = 0;
  Map<String, dynamic> _userAnswers = {};
  int? _pendingSelectedIndex;
  bool _hasSubmitted = false;
  DateTime? _questionStartTime;
  DateTime? _gameStartTime;
  Map<String, Map<String, dynamic>> _pretestResultSummary = {};

  @override
  void initState() {
    super.initState();
    _aiService = AiService();
    _gameStartTime = DateTime.now();
    _initializeGame();
  }

  @override
  void dispose() {
    if (_pretestCompleted) {
      _saveMainGameState();
      _recordGameVisit();
    }
    super.dispose();
  }

  // --- Safe casting helper functions ---
  Map<String, dynamic>? _deepCastMap(Map? data) {
    if (data == null) return null;
    return Map<String, dynamic>.from(data.map((key, value) {
      var newKey = key.toString();
      var newValue = value;
      if (value is Map) {
        newValue = _deepCastMap(value);
      } else if (value is List) {
        newValue = _deepCastList(value);
      }
      return MapEntry(newKey, newValue);
    }));
  }

  List<dynamic>? _deepCastList(List? data) {
    if (data == null) return null;
    return data.map((item) {
      if (item is Map) {
        return _deepCastMap(item);
      } else if (item is List) {
        return _deepCastList(item);
      }
      return item;
    }).toList();
  }

  // --- Core Game Orchestrator ---
  Future<void> _initializeGame() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final snap =
        await _dbRef.child("users/${user.uid}/games/${widget.gameTitle}").get();
    if (snap.exists) {
      _gameState = _deepCastMap(snap.value as Map) ?? {};
      _pretestCompleted = _gameState['pretestCompleted'] ?? false;
    } else {
      _gameState = {};
      _pretestCompleted = false;
    }
    if (_pretestCompleted) {
      setState(() => _isPretestMode = false);
      await _setupMainGame();
    } else {
      setState(() => _isPretestMode = true);
      await _setupPretest();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  // --- Pre-test Logic ---
  Future<void> _setupPretest() async {
    final pretestState = _deepCastMap(_gameState['pretest']);
    var savedQuestionIdsDynamic = _deepCastList(pretestState?['questionIds']);

    if (savedQuestionIdsDynamic != null && savedQuestionIdsDynamic.isNotEmpty) {
      List<Map<String, dynamic>> savedQuestionIds = savedQuestionIdsDynamic
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      _userAnswers = _deepCastMap(pretestState?['answers']) ?? {};
      _currentQuestionIndex = pretestState?['currentQuestionIndex'] ?? 0;
      await _loadPretestQuestions(savedQuestionIds);
    } else {
      setState(() => _showPretestIntro = true);
    }
  }

  Future<void> _generateAndLoadPretest() async {
    setState(() => _isLoading = true);
    try {
      Future<List<String>> getIds(String col, int count) async {
        final snap = await _firestore.collection(col).limit(count).get();
        return snap.docs.map((d) => d.id).toList();
      }

      final l1Ids = await getIds('${widget.gameTitle} L1', 4);
      final l2Ids = await getIds('${widget.gameTitle} L2', 4);
      final l3Ids = await getIds('${widget.gameTitle} L3', 2);
      final allIds = [...l1Ids, ...l2Ids, ...l3Ids]..shuffle();

      final questionIds = allIds.map((id) {
        if (l1Ids.contains(id)) return {'id': id, 'level': 'L1'};
        if (l2Ids.contains(id)) return {'id': id, 'level': 'L2'};
        return {'id': id, 'level': 'L3'};
      }).toList();

      final initialPretestState = {
        'questionIds': questionIds,
        'levelScores': {
          'L1': {'correct': 0, 'incorrect': 0},
          'L2': {'correct': 0, 'incorrect': 0},
          'L3': {'correct': 0, 'incorrect': 0}
        },
        'answers': {},
        'currentQuestionIndex': 0
      };
      await _dbRef
          .child(
              "users/${_auth.currentUser!.uid}/games/${widget.gameTitle}/pretest")
          .set(initialPretestState);
      _gameState['pretest'] = initialPretestState;
      await _loadPretestQuestions(questionIds);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPretestQuestions(
      List<Map<String, dynamic>> questionIds) async {
    final Map<String, List<String>> idsByLevel = {};
    for (var qInfo in questionIds) {
      idsByLevel.putIfAbsent(qInfo['level'], () => []).add(qInfo['id']);
    }
    final Map<String, DocumentSnapshot> docsById = {};
    for (var entry in idsByLevel.entries) {
      if (entry.value.isNotEmpty) {
        final snapshot = await _firestore
            .collection('${widget.gameTitle} ${entry.key}')
            .where(FieldPath.documentId, whereIn: entry.value)
            .get();
        for (var doc in snapshot.docs) {
          docsById[doc.id] = doc;
        }
      }
    }
    _questions = questionIds
        .map((qInfo) {
          final doc = docsById[qInfo['id']];
          if (doc != null && doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, 'level': qInfo['level'], 'data': data};
          }
          return null;
        })
        .where((q) => q != null)
        .cast<Map<String, dynamic>>()
        .toList();
    _initQuestionState();
  }

  Future<void> _calculateAndSavePretestResults() async {
    setState(() => _isLoading = true);
    final levelScores = _deepCastMap(_gameState['pretest']['levelScores'])!;
    final l1c = (levelScores['L1']?['correct'] ?? 0) as int;
    final l2c = (levelScores['L2']?['correct'] ?? 0) as int;
    final l3c = (levelScores['L3']?['correct'] ?? 0) as int;
    final l1p = (l1c / 4.0 * 100) >= 75;
    final l2p = (l2c / 4.0 * 100) >= 75;
    final l3p = (l3c / 2.0 * 100) >= 100;

    _pretestResultSummary = {
      'L1': {
        'score': (l1c / 4.0 * 100),
        'passed': l1p,
        'correct': l1c,
        'total': 4
      },
      'L2': {
        'score': (l2c / 4.0 * 100),
        'passed': l2p,
        'correct': l2c,
        'total': 4
      },
      'L3': {
        'score': (l3c / 2.0 * 100),
        'passed': l3p,
        'correct': l3c,
        'total': 2
      },
    };
    List<String> levelsToShow = [];
    if (!l1p) levelsToShow.add('L1');
    if (!l2p) levelsToShow.add('L2');
    if (!l3p) levelsToShow.add('L3');
    final Map<String, dynamic> levelProgress = {
      for (var level in levelsToShow) level: {'currentQuestionIndex': 0}
    };
    final updates = {
      'pretestCompleted': true,
      'main_game/levelsToShow': levelsToShow,
      'main_game/currentLevelIndex': 0,
      'main_game/levelProgress': levelProgress,
      'main_game/answers': {},
      'main_game/correctCount': 0,
      'main_game/incorrectCount': 0,
      'main_game/score': 0
    };
    await _dbRef
        .child("users/${_auth.currentUser!.uid}/games/${widget.gameTitle}")
        .update(updates);
    setState(() {
      _pretestCompleted = true;
      _showPretestResults = true;
      _isLoading = false;
    });
  }

  void _startMainGame() {
    setState(() {
      _isLoading = true;
      _showPretestResults = false;
      _isPretestMode = false;
      _questions = [];
      _currentQuestionIndex = 0;
    });
    _initializeGame();
  }

  // --- Main Game Logic ---
  Future<void> _setupMainGame() async {
    final mainGameData = _deepCastMap(_gameState['main_game']);
    _userAnswers = _deepCastMap(mainGameData?['answers']) ?? {};
    await _loadCurrentLevelQuestions();
  }

  Future<void> _loadCurrentLevelQuestions() async {
    final mainGameData = _deepCastMap(_gameState['main_game']) ?? {};
    final levelsToShow =
        (mainGameData['levelsToShow'] as List?)?.cast<String>() ?? [];
    final currentLevelIdx = mainGameData['currentLevelIndex'] as int? ?? 0;
    if (levelsToShow.isEmpty || currentLevelIdx >= levelsToShow.length) {
      _questions = [];
      return;
    }
    final currentLevelName = levelsToShow[currentLevelIdx];
    final snapshot = await _firestore
        .collection('${widget.gameTitle} $currentLevelName')
        .orderBy('timestamp')
        .get();
    _questions = snapshot.docs
        .map((doc) =>
            {'id': doc.id, 'level': currentLevelName, 'data': doc.data()})
        .toList();
    final levelProgress = _deepCastMap(mainGameData['levelProgress']) ?? {};
    final progressInCurrentLevel =
        _deepCastMap(levelProgress[currentLevelName]) ?? {};
    _currentQuestionIndex =
        (progressInCurrentLevel['currentQuestionIndex'] as int?) ?? 0;
    _initQuestionState();
  }

  // --- Shared Logic & State Updates ---
  void _initQuestionState() {
    if (_questions.isEmpty || _currentQuestionIndex >= _questions.length) {
      if (mounted) setState(() {});
      return;
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final qId = currentQuestion['id'] as String;

    if (_userAnswers.containsKey(qId)) {
      final saved = _userAnswers[qId] as Map<String, dynamic>;
      _pendingSelectedIndex = saved['selectedOptionIndex'] as int?;
      _hasSubmitted = true;
    } else {
      _pendingSelectedIndex = null;
      _hasSubmitted = false;
    }
    _questionStartTime = DateTime.now();
    if (mounted) setState(() {});
  }

  void _selectOption(int idx) {
    if (!_hasSubmitted) setState(() => _pendingSelectedIndex = idx);
  }

  Future<void> _submitAnswer() async {
    if (_pendingSelectedIndex == null || _hasSubmitted) return;
    final qId = _questions[_currentQuestionIndex]['id'] as String;
    final data =
        _questions[_currentQuestionIndex]['data'] as Map<String, dynamic>;
    final options = data['options'] as List<dynamic>;
    final isCorrect = options[_pendingSelectedIndex!]['isCorrect'] as bool;

    _userAnswers[qId] = {
      'selectedOptionIndex': _pendingSelectedIndex,
      'isCorrect': isCorrect,
      'timeTakenSeconds':
          DateTime.now().difference(_questionStartTime!).inSeconds
    };

    if (_isPretestMode) {
      await _updatePretestState(
          isCorrect, _questions[_currentQuestionIndex]['level']);
    } else {
      await _updateMainGameState(isCorrect);
    }
    setState(() {
      _hasSubmitted = true;
    });
  }

  Future<void> _updatePretestState(bool isCorrect, String level) async {
    final pretestState = _deepCastMap(_gameState['pretest'])!;
    final levelScores =
        pretestState['levelScores'][level] as Map<String, dynamic>;
    if (isCorrect) {
      levelScores['correct'] = (levelScores['correct'] as int? ?? 0) + 1;
    } else {
      levelScores['incorrect'] = (levelScores['incorrect'] as int? ?? 0) + 1;
    }
    _gameState['pretest'] = pretestState;
    pretestState['currentQuestionIndex'] = _currentQuestionIndex;
    pretestState['answers'] = _userAnswers;
    await _dbRef
        .child(
            "users/${_auth.currentUser!.uid}/games/${widget.gameTitle}/pretest")
        .set(pretestState);
  }

  Future<void> _updateMainGameState(bool isCorrect) async {
    final mainGameData = _deepCastMap(_gameState['main_game']) ?? {};
    if (isCorrect) {
      mainGameData['correctCount'] =
          (mainGameData['correctCount'] as int? ?? 0) + 1;
      mainGameData['score'] = (mainGameData['score'] as int? ?? 0) + 1;
    } else {
      mainGameData['incorrectCount'] =
          (mainGameData['incorrectCount'] as int? ?? 0) + 1;
    }
    _gameState['main_game'] = mainGameData;
    await _updateTodayActivity(isCorrect);
    await _updateUserOverallStats(isCorrect);
    await _saveMainGameState();
  }

  Future<void> _saveMainGameState() async {
    final user = _auth.currentUser;
    if (user == null ||
        _questions.isEmpty ||
        _currentQuestionIndex >= _questions.length) return;
    final mainGameData = _deepCastMap(_gameState['main_game']) ?? {};
    final currentLevel = _questions[_currentQuestionIndex]['level'] as String;
    final levelProgress = _deepCastMap(mainGameData['levelProgress']) ?? {};
    levelProgress[currentLevel] = {
      'currentQuestionIndex': _currentQuestionIndex
    };
    mainGameData['answers'] = _userAnswers;
    mainGameData['levelProgress'] = levelProgress;
    await _dbRef
        .child("users/${user.uid}/games/${widget.gameTitle}/main_game")
        .update(mainGameData);
  }

  Future<void> _recordGameVisit() async {
    final user = _auth.currentUser;
    final start = _gameStartTime;
    if (user == null || start == null) return;
    final seconds = DateTime.now().difference(start).inSeconds;
    final dateKey = DateTime.now().toIso8601String().substring(0, 10);
    final path =
        "users/${user.uid}/games/${widget.gameTitle}/main_game/gameVisits/$dateKey";
    final snap = await _dbRef.child(path).get();
    final prev = (snap.exists && snap.value is int) ? snap.value as int : 0;
    await _dbRef.child(path).set(prev + seconds);
  }

  Future<void> _updateTodayActivity(bool isCorrect) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final dateKey = DateTime.now().toIso8601String().substring(0, 10);
    final ref = _dbRef.child("users/${user.uid}/today_activity");

    final snap = await ref.get();
    Map<String, dynamic> todayActivity = {};
    if (snap.exists) {
      todayActivity = _deepCastMap(snap.value as Map) ?? {};
    }

    int correct = 0;
    int incorrect = 0;

    if (todayActivity['date'] == dateKey) {
      correct = todayActivity['correct'] ?? 0;
      incorrect = todayActivity['incorrect'] ?? 0;
    }

    if (isCorrect) {
      correct++;
    } else {
      incorrect++;
    }

    await ref.set({
      'date': dateKey,
      'correct': correct,
      'incorrect': incorrect,
    });
  }

  Future<void> _updateUserOverallStats(bool isCorrect) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final dateKey = DateTime.now().toIso8601String().substring(0, 10);
    final updates = <String, Object>{};
    final inc = ServerValue.increment(1);
    updates["users/${user.uid}/totalAttempted"] = inc;
     updates["users/${user.uid}/score"] =
        ServerValue.increment(isCorrect ? 1 : 0);


    updates["users/${user.uid}/monthlyStats/$dateKey/correct"] =
        ServerValue.increment(isCorrect ? 1 : 0);
    updates["users/${user.uid}/monthlyStats/$dateKey/incorrect"] =
        ServerValue.increment(isCorrect ? 0 : 1);

    final streakSnap = await _dbRef.child("users/${user.uid}/streak").get();
    if (isCorrect) {
      if (streakSnap.exists) {
        final streakData = Map<String, dynamic>.from(streakSnap.value as Map);
        if (streakData['date'] != dateKey) {
          updates["users/${user.uid}/streak/count"] = inc;
          updates["users/${user.uid}/streak/date"] = dateKey;
        }
      } else {
        updates["users/${user.uid}/streak"] = {'count': 1, 'date': dateKey};
      }
    }
    if (updates.isNotEmpty) await _dbRef.update(updates);
  }

  void _nextQuestion() async {
    if (_isPretestMode) {
      if (_currentQuestionIndex >= _questions.length - 1) {
        _calculateAndSavePretestResults();
      } else {
        setState(() => _currentQuestionIndex++);
        _initQuestionState();
      }
      return;
    }
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() => _currentQuestionIndex++);
      _initQuestionState();
    } else {
      final mainGameData = _deepCastMap(_gameState['main_game']) ?? {};
      final levelsToShow =
          (mainGameData['levelsToShow'] as List?)?.cast<String>() ?? [];
      int currentLevelIdx = mainGameData['currentLevelIndex'] as int? ?? 0;
      currentLevelIdx++;
      if (currentLevelIdx < levelsToShow.length) {
        setState(() => _isLoading = true);
        mainGameData['currentLevelIndex'] = currentLevelIdx;
        _gameState['main_game'] = mainGameData;
        await _dbRef
            .child(
                "users/${_auth.currentUser!.uid}/games/${widget.gameTitle}/main_game/currentLevelIndex")
            .set(currentLevelIdx);
        await _loadCurrentLevelQuestions();
        setState(() => _isLoading = false);
      } else {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => ResultPage(
                    gameTitle: widget.gameTitle,
                    score: mainGameData['score'] ?? 0,
                    correctCount: mainGameData['correctCount'] ?? 0,
                    incorrectCount: mainGameData['incorrectCount'] ?? 0,
                    isHindi: widget.isHindi)));
      }
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() => _currentQuestionIndex--);
      _initQuestionState();
    }
  }

  // --- AI Feature ---
  Future<void> _analyzeWithAI() async {
    if (_pendingSelectedIndex == null) return;

    final currentQuestionData =
        _questions[_currentQuestionIndex]['data'] as Map<String, dynamic>;
    final questionText = currentQuestionData['text'] as String? ?? "";
    final imageUrl = currentQuestionData['imageUrl'] as String?;
    final options = (currentQuestionData['options'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final optionTitles = options.map((o) => o['title'] as String).toList();
    final correctTitle = optionTitles[
        options.indexWhere((o) => o['isCorrect'] as bool? ?? false)];
    final userTitle = optionTitles[_pendingSelectedIndex!];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(widget.isHindi ? 'कृपया प्रतीक्षा करें' : 'Please wait'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(widget.isHindi
                ? 'AI उत्तर का विश्लेषण कर रहा है...'
                : 'AI is analyzing your answer...'),
          ],
        ),
      ),
    );

    try {
      final fb = await _aiService.getFeedback(
        question: questionText,
        options: optionTitles,
        correctAnswer: correctTitle,
        userAnswer: userTitle,
      );
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VideoLesson(
              fromPage: 'guesstheletter',
              question: questionText,
              correctOption: correctTitle,
              attemptedOption: userTitle,
              imageUrl: imageUrl,
              script: fb['explanation'] ?? fb.toString(),
              isHindi: widget.isHindi,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('AI feedback failed: $e')));
    }
  }

  // --- UI Widgets ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_showPretestIntro) return _buildPretestIntro();
    if (_showPretestResults) return _buildPretestResults();
    if (_questions.isEmpty && _pretestCompleted)
      return Scaffold(
          appBar: AppBar(title: Text(widget.gameTitle)),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("🎉", style: TextStyle(fontSize: 50)),
                        const SizedBox(height: 20),
                        Text(
                            widget.isHindi
                                ? "शानदार! आपने सभी स्तर पार कर लिए हैं।"
                                : "Congratulations! You have passed all levels.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(widget.isHindi ? "वापस" : "Go Back"))
                      ]))));
    if (_questions.isEmpty)
      return const Scaffold(body: Center(child: Text("No questions found.")));
    return _buildGameUI();
  }

  Widget _buildGameUI() {
    final mainGameData = _deepCastMap(_gameState['main_game']) ?? {};
    final pretestState = _deepCastMap(_gameState['pretest']);
    final currentQuestionData =
        _questions[_currentQuestionIndex]['data'] as Map<String, dynamic>;
    final questionText = currentQuestionData['text'] as String? ?? "";
    final imageUrl = currentQuestionData['imageUrl'] as String?;
    final options = (currentQuestionData['options'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final titleText = _isPretestMode
        ? '${widget.gameTitle} (Pre-test)'
        : '${widget.gameTitle} - ${_questions[_currentQuestionIndex]['level']}'
            .toUpperCase();

    int currentScore = 0;
    int currentCorrect = 0;
    int currentIncorrect = 0;

    if (_isPretestMode) {
      currentCorrect = pretestState?['levelScores']?.values.fold(
              0,
              (sum, level) =>
                  sum + ((_deepCastMap(level)?['correct'] as int?) ?? 0)) ??
          0;
      currentIncorrect = pretestState?['levelScores']?.values.fold(
              0,
              (sum, level) =>
                  sum + ((_deepCastMap(level)?['incorrect'] as int?) ?? 0)) ??
          0;
      currentScore = currentCorrect;
    } else {
      currentScore = mainGameData['score'] ?? 0;
      currentCorrect = mainGameData['correctCount'] ?? 0;
      currentIncorrect = mainGameData['incorrectCount'] ?? 0;
    }

    final isCurrentAnswerCorrect = _hasSubmitted &&
        _pendingSelectedIndex != null &&
        (options[_pendingSelectedIndex!]['isCorrect'] as bool);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 255, 255),
      appBar: AppBar(
        title: Flexible(
            child: Text(titleText,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
                overflow: TextOverflow.ellipsis)),
        backgroundColor: const Color.fromARGB(255, 101, 65, 239),
        automaticallyImplyLeading: !_isPretestMode,
        actions: [
          IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: _showInstructionsDialog)
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(questionText,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (imageUrl != null)
              Image.network(imageUrl,
                  height: 100,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.image_not_supported)),
            const SizedBox(height: 15),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.2),
              itemBuilder: (_, index) => buildOptionCard(options[index], index),
            ),
            const SizedBox(height: 20),
            if (_hasSubmitted && !isCurrentAnswerCorrect)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ElevatedButton.icon(
                  onPressed: _analyzeWithAI,
                  icon: const Icon(Icons.lightbulb_outline),
                  label: Text(widget.isHindi
                      ? 'AI से सही उत्तर जानें'
                      : 'Know the correct answer using AI'),
                ),
              ),
            Column(children: [
              Text(
                  widget.isHindi
                      ? "अंक: $currentScore"
                      : "Score: $currentScore",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                  widget.isHindi
                      ? "सही: $currentCorrect | गलत: $currentIncorrect"
                      : "Correct: $currentCorrect | Incorrect: $currentIncorrect",
                  style: const TextStyle(fontSize: 16)),
            ]),
            const SizedBox(height: 15),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton(
                  onPressed:
                      _currentQuestionIndex > 0 ? _previousQuestion : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _currentQuestionIndex > 0
                          ? Colors.orange
                          : Colors.grey),
                  child: Text(widget.isHindi ? "पिछला" : "Previous",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              ElevatedButton(
                  onPressed: (_pendingSelectedIndex != null && !_hasSubmitted)
                      ? _submitAnswer
                      : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (_pendingSelectedIndex != null && !_hasSubmitted)
                              ? Colors.blue
                              : Colors.grey),
                  child: Text(widget.isHindi ? "जमा करें" : "Submit",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
              ElevatedButton(
                  onPressed: _hasSubmitted ? _nextQuestion : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _hasSubmitted ? Colors.green : Colors.grey),
                  child: Text(widget.isHindi ? "अगला" : "Next",
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget buildOptionCard(Map<String, dynamic> option, int index) {
    final isSel = _pendingSelectedIndex == index;
    final showRes = _hasSubmitted && isSel;
    final corr = option['isCorrect'] as bool? ?? false;

    return GestureDetector(
      onTap: () => _selectOption(index),
      child: Stack(
        alignment: Alignment.center,
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
                    spreadRadius: 1)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Center(
                  child: Text(option['title'] as String,
                      style: const TextStyle(
                          fontSize: 25, fontWeight: FontWeight.bold))),
            ),
          ),
          if (showRes)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(corr ? Icons.check_circle : Icons.cancel,
                  size: 50, color: corr ? Colors.green : Colors.red),
            ),
        ],
      ),
    );
  }

  Widget _buildPretestIntro() {
    return Scaffold(
        backgroundColor: const Color.fromARGB(255, 245, 255, 255),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                          widget.isHindi
                              ? "एक छोटी परीक्षा"
                              : "A Quick Pre-test",
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Text(
                          widget.isHindi
                              ? "हम आपकी वर्तमान समझ का आकलन करने के लिए 10 प्रश्नों की एक छोटी परीक्षा लेंगे।"
                              : "We will conduct a short 10-question test to assess your current understanding.",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 40),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 15)),
                          onPressed: () {
                            if (mounted)
                              setState(() => _showPretestIntro = false);
                            _generateAndLoadPretest();
                          },
                          child: Text(widget.isHindi ? "शुरू करें" : "Start",
                              style: const TextStyle(fontSize: 20)))
                    ]))));
  }

  Widget _buildPretestResults() {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 245, 255, 255),
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.isHindi ? "परीक्षा परिणाम" : "Pre-test Results",
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple)),
                    const SizedBox(height: 25),
                    ..._pretestResultSummary.entries.map((entry) {
                      final level = entry.key;
                      final data = entry.value;
                      return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                              leading: Icon(
                                  data['passed']
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: data['passed']
                                      ? Colors.green
                                      : Colors.red,
                                  size: 40),
                              title: Text("Level $level",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(widget.isHindi
                                  ? "स्कोर: ${data['correct']}/${data['total']} (${data['score'].toStringAsFixed(0)}%)"
                                  : "Score: ${data['correct']}/${data['total']} (${data['score'].toStringAsFixed(0)}%)"),
                              trailing: Text(
                                  data['passed']
                                      ? (widget.isHindi ? "पास" : "Passed")
                                      : (widget.isHindi
                                          ? "फिर से प्रयास करें"
                                          : "Try Again"),
                                  style: TextStyle(
                                      color: data['passed']
                                          ? Colors.green
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold))));
                    }).toList(),
                    const SizedBox(height: 30),
                    Text(
                        widget.isHindi
                            ? "अब असली खेल शुरू करते हैं..."
                            : "Starting the main game now...",
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey.shade700)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 15)),
                        onPressed: _startMainGame,
                        child: Text(
                            widget.isHindi ? "खेल में जाएं" : "Move to Game",
                            style: const TextStyle(fontSize: 20)))
                  ]))),
    );
  }

  void _showInstructionsDialog() {
    showDialog(
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
    );
  }
}
