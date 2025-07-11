// lib/profile.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'language_notifier.dart';
import 'navbar.dart';
import 'menu_bar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // for formatting weekdays
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';



class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _dbRef = FirebaseDatabase.instance.ref();
  late final String _uid;
  int todayPoints = 0;
  int totalPoints = 0;
  int streakCount = 0;
  bool statsLoading = true;
  int _goal = 50;
  int _totalCorrect = 0;
  int _totalIncorrect = 0;
  int totalQuestions = 0;
  int totalAttempted = 0;
/// Holds each game’s accuracy
  List<_GameAccuracy> _gameAccuracies = [];
  bool _loadingGameAcc = true;

  List<_GameBubbleData> _bubbles = [];
  bool _loadingBubbles = true;
Map<String, dynamic> monthlyStats = {};



  Map<String, int> _weeklyScores = {}; // e.g. {Sun: 10, Mon: 20, ...}
  final List<String> _gameNames = [
     'Name Picture Matching',
    'Guess the Letter',
    'Compare',
    'Let us Count',
    'Number Name Matching',
    'Name Number Matching',
    'Let us Tell Time',
    'Alphabet Knowledge',
    'Left Middle Right',
    'Shape Knowledge',
    'नाम चित्र मिलान',
    'अक्षर ज्ञान',
    'तुलना',
    'चलो गिनें',
    'संख्या नाम मिलान',
    'नाम संख्या मिलान',
    'चलो समय बताएँ',
    'वर्णमाला ज्ञान',
    'बाएँ दाएँ मध्य',
    'आकार ज्ञान',
  ];



  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
    _loadDashboardStats();
    _loadWeeklyData();
    _loadAccuracyData();
  _loadGameAccuracies();
  _loadBubbleData();
   
  }





Future<void> _loadBubbleData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final userGamesSnap =
        await FirebaseDatabase.instance.ref('users/$uid/games').get();
    final Map<String, dynamic> userStats =
        userGamesSnap.exists && userGamesSnap.value is Map
            ? Map<String, dynamic>.from(userGamesSnap.value as Map)
            : {};

    // 👉 1. Fetch totalAttempted from RTDB
    final totalAttemptedSnap =
        await FirebaseDatabase.instance.ref('users/$uid/totalAttempted').get();
    final totalAttemptedValue =
        totalAttemptedSnap.exists ? (totalAttemptedSnap.value as int? ?? 0) : 0;

    // 2. Firestore counts
    final countFutures = _gameNames.map((game) {
      return FirebaseFirestore.instance.collection(game).count().get();
    }).toList();

    final snapshots = await Future.wait(countFutures);

    List<_GameBubbleData> list = [];
    for (var i = 0; i < _gameNames.length; i++) {
      final game = _gameNames[i];
      final total = snapshots[i].count ?? 0;

      final stats = userStats[game] as Map? ?? {};
      final correct = (stats['correctCount'] as int?) ?? 0;
      final incorrect = (stats['incorrectCount'] as int?) ?? 0;
      final attempted = correct + incorrect;

      list.add(_GameBubbleData(game, attempted, total, correct, incorrect));
    }

    // 👉 3. Sum total questions
    final totalQuestionsValue = snapshots.fold<int>(
      0,
      (sum, snap) => sum + (snap.count ?? 0),
    );

    // 👉 4. Save everything
    setState(() {
      _bubbles = list;
      _loadingBubbles = false;
      totalQuestions = totalQuestionsValue;
      totalAttempted = totalAttemptedValue;
    });
  }



Future<void> _loadGameAccuracies() async {
    final snap = await _dbRef.child('users/$_uid/games').get();
    final List<_GameAccuracy> list = [];
    if (snap.exists && snap.value is Map) {
      final games = Map<String, dynamic>.from(snap.value as Map);
      games.forEach((gameName, raw) {
        final m = raw as Map<dynamic, dynamic>;
        final c = (m['correctCount'] as int?) ?? 0;
        final i = (m['incorrectCount'] as int?) ?? 0;
        list.add(_GameAccuracy(name: gameName, correct: c, incorrect: i));
      });
    }
    setState(() {
      _gameAccuracies = list;
      _loadingGameAcc = false;
    });
  }

Future<void> _loadDashboardStats() async {
    final uid = _uid;
    final today = DateTime.now();
    final todayStr = today.toIso8601String().substring(0, 10);
    final yesterdayStr = today
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    // 1️⃣ Today's Points
    final todaySnap = await _dbRef.child('users/$uid/today_activity').get();
    final tp =
        (todaySnap.exists && (todaySnap.value as Map)['date'] == todayStr)
            ? ((todaySnap.child('correct').value as int?) ?? 0)
            : 0;

    // 2️⃣ Total Points (fetch from users/{uid}/score)
    final scoreSnap = await _dbRef.child('users/$uid/score').get();
    final tpTotal = (scoreSnap.exists && scoreSnap.value is int)
        ? scoreSnap.value as int
        : 0;

    // 3️⃣ Streak Calculation (read users/{uid}/streak)
    final streakSnap = await _dbRef.child('users/$uid/streak').get();
    int newStreakCount = 0;
    if (streakSnap.exists && streakSnap.value is Map) {
      final streakData = Map<String, dynamic>.from(streakSnap.value as Map);
      final lastDate = streakData['date'] ?? '';
      final count = streakData['count'] ?? 0;

      if (lastDate == todayStr || lastDate == yesterdayStr) {
        newStreakCount = count;
      } else {
        newStreakCount = 0; // 🧠 not updating Firebase, only local reset
      }
    }

    // 4️⃣ Monthly Stats
    final monthlySnap = await _dbRef.child('users/$uid/monthlyStats').get();
    if (monthlySnap.exists && monthlySnap.value is Map) {
      monthlyStats = Map<String, dynamic>.from(monthlySnap.value as Map);
    }

    setState(() {
      todayPoints = tp;
      totalPoints = tpTotal;
      streakCount = newStreakCount;
      statsLoading = false;
    });
  }


Future<void> _loadAccuracyData() async {
    final snap = await _dbRef.child('users/$_uid/games').get();
    int corr = 0, inc = 0;
    if (snap.exists && snap.value is Map) {
      (snap.value as Map).forEach((_, gameData) {
        final m = gameData as Map;
        corr += (m['correctCount'] as int?) ?? 0;
        inc += (m['incorrectCount'] as int?) ?? 0;
      });
    }
    setState(() {
      _totalCorrect = corr;
      _totalIncorrect = inc;
    });
  }


Future<void> _loadWeeklyData() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final days = List.generate(7, (i) => startOfWeek.add(Duration(days: i)));

    final snap = await _dbRef.child('users/$_uid/monthlyStats').get();
    final goalSnap = await _dbRef.child('users/$_uid/dailyGoal').get();

    Map<String, int> scoreMap = {};
    for (var day in days) {
      String key = DateFormat('yyyy-MM-dd').format(day);
      String label = DateFormat.E().format(day); // Mon, Tue, etc.
      final dayData = snap.child(key).value as Map?;
      int correct = dayData != null ? (dayData['correct'] ?? 0) : 0;
      scoreMap[label] = correct;
    }

    setState(() {
      _weeklyScores = scoreMap;
      _goal = goalSnap.exists ? goalSnap.value as int : 50;
    });
  }


  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;

    return Scaffold(
      appBar: NavBar(
        isHindi: isHindi,
        onToggleLanguage: (val) {
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(val);
          setState(() {});
        },
        showMenuButton: true,
      ),
      drawer: CustomMenuBar(isHindi: isHindi),
      body: FutureBuilder<DatabaseEvent>(
        future: _dbRef.child('users/$_uid').once(),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final data =
              snap.data!.snapshot.value as Map<dynamic, dynamic>? ?? {};

          final name = data['name'] as String? ?? '';
          final age = data['age'] != null ? (data['age'].toString()) : '';
          final gender = data['gender'] as String? ?? '';
          final school = data['school'] == true;
          final sclass = data['class'] as String? ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Image.asset('assets/logo.png', height: 140),

                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    isHindi ? 'व्यक्तिगत जानकारी' : ' Personal Information',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                ),
                Card(
                  elevation: 5,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  shadowColor: Colors.blue.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                            Icons.person, isHindi ? 'नाम' : 'Name', name),
                        _buildInfoRow(
                            Icons.calendar_month, isHindi ? 'आयु' : 'Age', age),
                        _buildInfoRow(Icons.transgender,
                            isHindi ? 'लिंग' : 'Gender', gender),
                        _buildInfoRow(
                            Icons.school,
                            isHindi ? 'स्कूल जाते हैं' : 'Goes to School',
                            school ? (isHindi ? 'हाँ' : 'Yes') : ''),
                        _buildInfoRow(
                            Icons.class_, isHindi ? 'कक्षा' : 'Class', sclass),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: Text(
                    isHindi ? 'प्रोफ़ाइल संपादित करें' : 'Edit Profile',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  onPressed: () => _showEditDialog(
                      context, name, age, gender, school, sclass),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    elevation: 8,
                  ),
                ),
                // ── Dashboard Stats Row ─────────────────────────────────


                 const SizedBox(height: 20),
             Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    isHindi ? 'मेरे अंक' : 'My Scores',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                ),



                if (statsLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard(isHindi?'आज':'⚡ Today', todayPoints,isHindi?'अंक':'points'),
                      _buildStatCard(isHindi?'🔥 स्ट्रिक':'🔥 Streak', streakCount, isHindi?'दिन':'days'),
                      _buildStatCard(isHindi?'🏆 कुल':'🏆 Total', totalPoints, isHindi?'अंक':'points'),
                    ],
                  ),
const SizedBox(height: 10),
                  buildProgressBadgeCard(isHindi,totalAttempted, totalQuestions),

                const SizedBox(height: 20),
               Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    isHindi ? 'साप्ताहिक प्रगति' : ' Weekly Progress',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

             buildWeeklyLineChart(isHindi: isHindi),

                const SizedBox(height: 20),
                 Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    isHindi ? 'कुल सटीकता' : 'Total Accuracy',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                ),
                _buildAccuracyDonut(isHindi: isHindi),
                const SizedBox(height: 20),
                  Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    isHindi ? 'खेल सटीकता' : 'Game Accuracy',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                ),

Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: _buildGameProgressBars(isHindi: isHindi),
),

      const SizedBox(height: 40),
         Padding(
                  padding: const EdgeInsets.only(bottom: 50),
                  child: Text(
                    isHindi ? 'खेल प्रगति' : ' Game Progress',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                ),
                 const SizedBox(height: 30),

            _buildBubbleGrid(isHindi: isHindi),
        const SizedBox(height: 30),
            Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    isHindi ? 'मासिक प्रगति' : 'Monthly Progress',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade800,
                    ),
                  ),
                ),
                
           _buildMonthlyHeatmap(isHindi: isHindi),

const SizedBox(height: 30),


              ],
            ),
          );
        },
      ),
    );
  }

Widget buildWeeklyLineChart({required bool isHindi}) {
    final days = _weeklyScores.keys.toList();
    final values = _weeklyScores.values.toList();

    double minY = values.isEmpty
        ? 0
        : (values.reduce((a, b) => a < b ? a : b)).toDouble();
    double maxY = values.isEmpty
        ? 100
        : (values.reduce((a, b) => a > b ? a : b)).toDouble();
    maxY = (maxY < _goal ? _goal.toDouble() : maxY) + 20;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 240,
                child: LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      verticalInterval: 1,
                      horizontalInterval: null, // Let fl_chart auto-choose
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      ),
                      getDrawingVerticalLine: (value) => FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, _) {
                            if (value.toInt() < days.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  days[value.toInt()],
                                  style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 35,
                          getTitlesWidget: (value, _) => Text(
                            value.toInt().toString(),
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                      ),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          values.length,
                          (i) => FlSpot(i.toDouble(), values[i].toDouble()),
                        ),
                        isCurved: true,
                        gradient: LinearGradient(
                          colors: [Colors.cyan, Colors.teal],
                        ),
                        barWidth: 4,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: Colors.teal,
                            strokeColor: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      // Goal Line
                      LineChartBarData(
                        spots: List.generate(
                          values.length,
                          (i) => FlSpot(i.toDouble(), _goal.toDouble()),
                        ),
                        isCurved: false,
                        color: Colors.orange,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dashArray: [6, 4],
                        dotData: FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            isHindi
                ? '🎯 अपना दैनिक लक्ष्य निर्धारित करें'
                : '🎯 Set Your Daily Goal',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.orange,
            inactiveTrackColor: Colors.orange.withOpacity(0.3),
            thumbColor: Colors.deepOrange,
            overlayColor: Colors.orange.withOpacity(0.2),
          ),
          child: Slider(
            min: 0,
            max: 200,
            divisions: 20,
            label: _goal.toString(),
            value: _goal.toDouble(),
            onChanged: (val) async {
              setState(() => _goal = val.toInt());
              await _dbRef.child('users/$_uid/dailyGoal').set(_goal);
            },
          ),
        ),
      ],
    );
  }


Widget buildProgressBadgeCard(
      bool isHindi,int totalAttempted, int totalQuestions) {
    // Badge based on % attempted
    double percent = totalQuestions > 0 ? totalAttempted / totalQuestions : 0;
    String badge;
    if (percent >= 0.90) {
      badge  = isHindi?'🏆 किंवदंती':'🏆 Legend';
    } else if (percent >= 0.75) {
      badge = isHindi?'🥇 विशेषज्ञ': '🥇 Expert';
    } else if (percent >= 0.50) {
      badge = isHindi?'🥈 मध्यवर्ती':'🥈 Intermediate';
    } else if (percent >= 0.25) {
      badge = isHindi?'🥉 प्रारंभिक':'🥉 Beginner';
    } else {
      badge = isHindi?'🎯 नवशिक्शु':'🎯 Novice';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 4,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      
      child: Stack(
        children: [
          // 🎯 Background (archery board style)
          Positioned(
            right: -40,
            top: -40,
            child: Opacity(
              opacity: 0.15,
              child: Image.asset(
                'assets/archery.png', 
                height: 160,
                width: 160,
              ),
            ),
          ),

          // Actual Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Row(
                children: [
Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: percent.clamp(0.0, 1.0),
                            strokeWidth: 6,
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.green),
                          ),
                        ),
                        Icon(
                          Icons.shield,
                          color: Colors.blue[700],
                          size: 36,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        isHindi?"$totalAttempted / $totalQuestions प्रयास किए गए": "$totalAttempted / $totalQuestions attempted",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        isHindi?"${(percent * 100).toStringAsFixed(1)}% पूरा हुआ":"${(percent * 100).toStringAsFixed(1)}% completed",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }




  Widget _buildBubbleGrid({required bool isHindi}) {
    if (_loadingBubbles) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_bubbles.isEmpty) {
      return Center(child: Text('No games played yet'));
    }

    return Column(
      children: [
        const SizedBox(height: 25),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.9, // space for label
          ),
          itemCount: _bubbles.length,
          itemBuilder: (ctx, i) => _buildBubble(_bubbles[i], isHindi: isHindi),
        ),
      ],
    );
  }


Widget _buildBubble(_GameBubbleData g, {required bool isHindi}) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  g.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),

                _getBadge(g.ratio, isHindi: isHindi), // ⭐ Badge

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     Text(isHindi ? 'कुल प्रश्न:' : 'Total Questions:',
                        style: TextStyle(fontSize: 15)),
                    Text('${g.total}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isHindi ? 'प्रयास किए गए:' : 'Attempted:', style: TextStyle(fontSize: 15)),
                    Text('${g.attempted}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isHindi ? 'सही:' : 'Correct:', style: TextStyle(fontSize: 15)),
                    Text('${g.correct}',
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isHindi ? 'गलत:' : 'Incorrect:', style: TextStyle(fontSize: 15)),
                    Text('${g.incorrect}',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(100, 100),
            painter: BubblePainter(g.ratio),
            child: Center(
              child: Text(
                '${(g.ratio * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 31),
          SizedBox(
            width: 100,
            child: Text(
              g.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }


  
Widget _buildMonthlyHeatmap({required bool isHindi}) {
  // Parse your monthlyStats (Map<String, dynamic>) into a DateTime→int map
  final Map<DateTime, int> heatData = {};
  monthlyStats.forEach((dateStr, stat) {
    final date = DateTime.tryParse(dateStr);
    if (date != null) {
      final attempted = (stat['correct'] ?? 0) + (stat['incorrect'] ?? 0);
      heatData[date] = attempted;
    }
  });

  final now = DateTime.now();
  final firstDay = DateTime(now.year, now.month, 1);
  final lastDay = DateTime(now.year, now.month + 1, 0);
  final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  // Build column‑wise lists
  final Map<int, List<Widget>> dayColumns = { for (int i = 0; i < 7; i++) i: [] };
  for (int d = 1; d <= lastDay.day; d++) {
    final date = DateTime(now.year, now.month, d);
    final wd = date.weekday % 7;
    final attempted = heatData[date] ?? 0;
    final opacity = attempted == 0
        ? 0.1
        : (attempted / 12).clamp(0.2, 1.0);
    final color = attempted == 0
        ? Colors.grey.shade300
        : Colors.green.withOpacity(opacity);

    dayColumns[wd]!.add(
      GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            barrierColor: Colors.black26,
            builder: (_) => Dialog(
              backgroundColor: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('EEE, MMM d').format(date),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isHindi ? '$attempted प्रश्न${attempted == 1 ? '' : 'ों'} का प्रयास किया गया' : '$attempted question${attempted == 1 ? '' : 's'} attempted',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            '$d',
            style: const TextStyle(
                fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          '${DateFormat('MMMM yyyy').format(now)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(7, (i) {
            return Expanded(
              child: Column(
                children: [
                  Text(
                    daysOfWeek[i],
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  ...dayColumns[i]!,
                ],
              ),
            );
          }),
        ),
      ),
    ],
  );
}


    



Widget _getBadge(double ratio, {required bool isHindi}) {
    String label;
    Color color;
    IconData icon;

    if (ratio < 0.5) {
      label =  isHindi ? 'शुरुआती' : 'Beginner';
      color = Colors.redAccent;
      icon = Icons.flag_rounded; // 🏳️ Clear start flag
    } else if (ratio < 0.8) {
      label = isHindi ? 'मध्यम' : 'Intermediate';
      color = Colors.orangeAccent;
      icon = Icons.emoji_events_rounded; // 🥉 Trophy
    } else {
      label = isHindi ? 'विशेषज्ञ' :'Expert';
      color = Colors.green;
      icon = Icons.military_tech_rounded; // 🥇 Medal
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 48,
          color: color,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }


Widget _buildGameProgressBars({required bool isHindi}) {
    if (_loadingGameAcc) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_gameAccuracies.isEmpty) {
      return Center(
        child: Text(isHindi ? 'कोई गेम डेटा नहीं है' : 'No game data yet',
            style: GoogleFonts.poppins(color: Colors.grey)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _gameAccuracies.map((g) {
        final percent = (g.accuracy * 100).toStringAsFixed(0);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Game Name and Accuracy %
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    g.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: g.accuracy >= 0.75
                          ? Colors.green.shade100
                          : g.accuracy >= 0.5
                              ? Colors.yellow.shade100
                              : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$percent%',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: g.accuracy >= 0.75
                            ? Colors.green.shade800
                            : g.accuracy >= 0.5
                                ? Colors.orange.shade800
                                : Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Progress bar with gradient
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: g.accuracy,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    g.accuracy >= 0.75
                        ? Colors.green
                        : g.accuracy >= 0.5
                            ? Colors.orange
                            : Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

Widget _buildAccuracyDonut({required bool isHindi}) {

  
    final total = _totalCorrect + _totalIncorrect;
    final correctPct = total == 0 ? 0.0 : _totalCorrect / total;
    final incorrectPct = total == 0 ? 0.0 : _totalIncorrect / total;

    if (total==0) {
      return Center(
        child: Text(isHindi?'कोई गेम डेटा नहीं है':'No game data yet',
            style: GoogleFonts.poppins(color: Colors.grey)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Donut Chart
            SizedBox(
              width: 140,
              height: 140,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                  sections: [
                    PieChartSectionData(
                      value: correctPct * 100,
                      color: Colors.green,
                      title: '${(correctPct * 100).toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: incorrectPct * 100,
                      color: Colors.red,
                      title: '${(incorrectPct * 100).toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 24),

            // Badge + Counts
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const CircleAvatar(radius: 6, backgroundColor: Colors.green),
                  const SizedBox(width: 8),
                  Text(isHindi ? 'सही' : 'Correct',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Text('$_totalCorrect',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  const CircleAvatar(radius: 6, backgroundColor: Colors.red),
                  const SizedBox(width: 8),
                  Text(isHindi ? 'गलत' : 'Incorrect',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Text('$_totalIncorrect',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red)),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }



// 🔧 Helper to build legend rows
  Widget _buildLegendItem({
    required Color color,
    required String label,
    required int value,
  }) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(width: 10),
        Text('$value',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }




  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(color: Colors.black87, fontSize: 16),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: value.isEmpty ? '-' : value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    String name,
    String age,
    String gender,
    bool school,
    String sclass,
  ) {
    final isHindi =
        Provider.of<LanguageNotifier>(context, listen: false).isHindi;
    final nameController = TextEditingController(text: name);
    final ageController = TextEditingController(text: age);
    final classController = TextEditingController(text: sclass);

    String selectedGender = gender;
    bool goesToSchool = school;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (c, setLocalState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 20,
              backgroundColor: Colors.white,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Row(
                      children: [
                        const Icon(Icons.edit, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Text(
                          isHindi ? 'प्रोफ़ाइल संपादित करें' : 'Edit Profile',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),


// ────────────────────────────────────────────────────────

                    // Subtitle
                    // Name
                    _buildTextField(
                      controller: nameController,
                      label: isHindi ? 'नाम *' : 'Name *',
                      icon: Icons.person,
                    ),
                    const SizedBox(height: 14),

                    // Age
                    _buildTextField(
                      controller: ageController,
                      label: isHindi ? 'आयु *' : 'Age *',
                      icon: Icons.calendar_today,
                      isNumber: true,
                    ),
                    const SizedBox(height: 14),

                    // Gender Dropdown
                    _buildStyledDropdown(
                      selectedGender,
                      (val) => setLocalState(() => selectedGender = val ?? ''),
                      isHindi: isHindi,
                    ),
                    const SizedBox(height: 14),

                    // School Checkbox
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: goesToSchool,
                      onChanged: (val) =>
                          setLocalState(() => goesToSchool = val ?? false),
                      activeColor: Colors.deepPurple,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        isHindi ? 'स्कूल जाते हैं' : 'Goes to School',
                        style: GoogleFonts.poppins(fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Class
                    _buildTextField(
                      controller: classController,
                      label: isHindi ? 'कक्षा' : 'Class',
                      icon: Icons.class_,
                      isNumber: true,
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: Text(
                            isHindi ? 'रद्द करें' : 'Cancel',
                            style: GoogleFonts.poppins(
                                color: Colors.grey.shade700),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            isHindi ? 'सहेजें' : 'Save',
                            style: GoogleFonts.poppins(color: Colors.white),
                          ),
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty ||
                                ageController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isHindi
                                        ? 'नाम और आयु आवश्यक हैं'
                                        : 'Name and Age are required',
                                  ),
                                ),
                              );
                              return;
                            }
                            await _dbRef.child('users/$_uid').update({
                              'name': nameController.text.trim(),
                              'age': int.parse(ageController.text.trim()),
                              'gender': selectedGender,
                              'school': goesToSchool,
                              'class': classController.text.trim(),
                            });
                            Navigator.pop(ctx);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
Widget _buildStatCard(String title, int value, String unit) {
    return Expanded(
      child: Card(
        color: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('$value',
                  style: GoogleFonts.poppins(
                      fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(unit,
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  // Helper: Styled TextField
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple),
        ),
      ),
    );
  }

  // Helper: Styled Dropdown
  Widget _buildStyledDropdown(
      String selectedValue, ValueChanged<String?> onChanged,
      {required bool isHindi}) {
    return DropdownButtonFormField<String>(
      value: selectedValue.isEmpty ||
              !['Male', 'Female', 'Other'].contains(selectedValue)
          ? ''
          : selectedValue,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: isHindi ? 'लिंग' : 'Gender',
        prefixIcon: const Icon(Icons.transgender),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple),
        ),
      ),
      items: [
        DropdownMenuItem(
            value: '', child: Text(isHindi ? 'चयन नहीं' : 'Not specified')),
        DropdownMenuItem(
            value: 'Male', child: Text(isHindi ? 'पुरुष' : 'Male')),
        DropdownMenuItem(
            value: 'Female', child: Text(isHindi ? 'महिला' : 'Female')),
        DropdownMenuItem(
            value: 'Other', child: Text(isHindi ? 'अन्य' : 'Other')),
      ],
      style: GoogleFonts.poppins(fontSize: 15, color: Colors.black87),
      icon: const Icon(Icons.arrow_drop_down),
      dropdownColor: Colors.white,
    );
  }
}


class _GameAccuracy {
  final String name;
  final int correct, incorrect;
  final double accuracy; // 0.0–1.0

  _GameAccuracy({
    required this.name,
    required this.correct,
    required this.incorrect,
  }) : accuracy =
            (correct + incorrect) == 0 ? 0.0 : correct / (correct + incorrect);
}

class _GameBubbleData {
  final String name;
  final int attempted;
  final int total;
  final int correct;
  final int incorrect;
  double get ratio => total == 0 ? 0 : attempted / total;

  _GameBubbleData(
      this.name, this.attempted, this.total, this.correct, this.incorrect);
}

class BubblePainter extends CustomPainter {
  final double ratio; // 0.0 – 1.0

  BubblePainter(this.ratio);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1) Draw grey background circle
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 2) Draw green fill arc from bottom center counter‑clockwise
    final fillPaint = Paint()
      ..color = Colors.green.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    // Convert ratio to sweep angle in radians
    final sweep = 2 * math.pi * ratio;
    // Start from bottom (-pi/2 is top, so 3*pi/2 is bottom)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3 * math.pi / 2, // start at bottom
      sweep, // sweep angle
      true, // use center
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BubblePainter old) => old.ratio != ratio;
}
