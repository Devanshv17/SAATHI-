// lib/profile.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'language_notifier.dart';
import 'navbar.dart';
import 'menu_bar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _dbRef = FirebaseDatabase.instance.ref();
  late final String _uid;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
  }

  /// Deletes RTDB data, Auth user, signs out, and navigates to login
  Future<void> _performDeleteAccount() async {
    setState(() => _deleting = true);
    // 1. Remove user data from Realtime Database
    await _dbRef.child('users/$_uid').remove();

    // 2. Delete Firebase Auth user
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) await user.delete();
    } catch (_) {
      // ignore (requires recent login)
    }

    // 3. Sign out
    await FirebaseAuth.instance.signOut();

    // 4. Clear login flag
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', false);

    // 5. Navigate to login
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  Future<void> _showDeleteDialog() {
    final isHindi =
        Provider.of<LanguageNotifier>(context, listen: false).isHindi;
    final controller = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.warning, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                isHindi
                    ? 'क्या आप खाता हटाना चाहते हैं?'
                    : 'Are you sure you want to delete your account?',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isHindi
                    ? 'यह क्रिया स्थायी है। जारी रखने के लिए नीचे "delete" लिखें।'
                    : 'This action is permanent. Type "delete" below to confirm.',
                style: GoogleFonts.poppins(
                    fontSize: 16, color: Colors.black54, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'delete',
                  hintStyle: GoogleFonts.poppins(color: Colors.grey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
                style: GoogleFonts.poppins(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        isHindi ? 'रद्द करें' : 'Cancel',
                        style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (_, val, __) {
                        final isMatch =
                            val.text.trim().toLowerCase() == 'delete';
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: isMatch
                                ? Colors.redAccent
                                : Colors.redAccent.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          onPressed: isMatch
                              ? () {
                                  Navigator.of(ctx).pop();
                                  _performDeleteAccount();
                                }
                              : null,
                          child: Text(
                            isHindi ? 'हटाएं' : 'Delete',
                            style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;

    return Scaffold(
      appBar: NavBar(
        isHindi: isHindi,
        onToggleLanguage: (value) {
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(value);
          setState(() {});
        },
        showMenuButton: true,
      ),
      drawer: CustomMenuBar(isHindi: isHindi),
      body: FutureBuilder<DatabaseEvent>(
        future: _dbRef.child('users/$_uid').once(),
        builder: (context, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final data =
              snap.data!.snapshot.value as Map<dynamic, dynamic>? ?? {};
          final name = data['name'] ?? '';
          final age = data['age']?.toString() ?? '';
          final gender = data['gender'] ?? '';
          final school = data['school'] == true;
          final sclass = data['class'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Image.asset('assets/logo.png', height: 150),
                const SizedBox(height: 15),
                Text(
                  isHindi ? 'आपके खाते की जानकारी' : 'About Your Account',
                  style: GoogleFonts.poppins(
                      fontSize: 26, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 15),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.person, isHindi ? 'नाम' : 'Name',
                            name.toString()),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.calendar_today,
                            isHindi ? 'आयु' : 'Age', age.toString()),
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.wc, isHindi ? 'लिंग' : 'Gender',
                            gender.toString()),
                        if (school) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(
                              Icons.school,
                              isHindi ? 'स्कूल' : 'Goes to school',
                              isHindi ? 'हाँ' : 'Yes'),
                          const SizedBox(height: 12),
                          _buildInfoRow(Icons.class_,
                              isHindi ? 'कक्षा' : 'Class', sclass.toString()),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _deleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.delete, color: Colors.white),
                    label: Text(
                      isHindi ? 'मेरा खाता हटाएं' : 'Delete My Account',
                      style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white),
                    ),
                    onPressed: _deleting ? null : _showDeleteDialog,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 28, color: Colors.blueAccent),
        const SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(color: Colors.black, fontSize: 16),
              children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
