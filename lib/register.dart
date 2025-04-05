import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'navbar.dart';
import 'package:provider/provider.dart';
import 'language_notifier.dart';
import 'package:translator_plus/translator_plus.dart';
import 'package:firebase_database/firebase_database.dart'; // Import for realtime database

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleTranslator translator = GoogleTranslator();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _errorMessage = '';

  // UI strings (default English)
  String welcomeText = 'Welcome!';
  String emailLabel = 'Email';
  String passwordLabel = 'Password';
  String emailValidator = 'Please enter an email';
  String passwordValidator = 'Password must be at least 6 characters';
  String registerButtonText = 'Register';
  String appBarTitle = 'Register';
  String alreadyHaveAccountText = 'Already have an account? Login';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final isHindi =
        Provider.of<LanguageNotifier>(context, listen: false).isHindi;
    if (isHindi) {
      try {
        final results = await Future.wait([
          translator.translate('Email', to: 'hi'),
          translator.translate('Please enter an email', to: 'hi'),
          translator.translate('Password', to: 'hi'),
          translator.translate('Password must be at least 6 characters', to: 'hi'),
          translator.translate('Register', to: 'hi'), // for register button
          translator.translate('Register', to: 'hi'), // for app bar title
          translator.translate('Welcome!', to: 'hi'),
          translator.translate('Already have an account? Login', to: 'hi'),
        ]);
        setState(() {
          emailLabel = results[0].text;
          emailValidator = results[1].text;
          passwordLabel = results[2].text;
          passwordValidator = results[3].text;
          registerButtonText = results[4].text;
          appBarTitle = results[5].text;
          welcomeText = results[6].text;
          alreadyHaveAccountText = results[7].text;
        });
      } catch (e) {
        // If translation fails, fallback to English.
      }
    } else {
      setState(() {
        emailLabel = 'Email';
        emailValidator = 'Please enter an email';
        passwordLabel = 'Password';
        passwordValidator = 'Password must be at least 6 characters';
        registerButtonText = 'Register';
        appBarTitle = 'Register';
        welcomeText = 'Welcome!';
        alreadyHaveAccountText = 'Already have an account? Login';
      });
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Create the user.
        UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Get the user UID.
        final String uid = userCredential.user!.uid;

        // Initialize default game scores for multiple game types.
        Map<String, dynamic> initialGames = {
          "Name Picture Matching": {"score": 0, "answers": []},
          "Guess the Letter": {"score": 0, "answers": []},
          "Compare": {"score": 0, "answers": []},
          "Let us Count": {"score": 0, "answers": []},
          "Number Name Matching": {"score": 0, "answers": []},
          "Name Number Matching": {"score": 0, "answers": []},
          "Let us Tell Time": {"score": 0, "answers": []},
          "Alphabet Knowledge": {"score": 0, "answers": []},
          // Add more games here if needed.
        };

        // Save the default role "user" and initialized game scores in the Firebase Realtime Database.
        DatabaseReference ref =
        FirebaseDatabase.instance.ref("users/$uid");
        await ref.set({
          "role": "user",
          "games": initialGames,
        });

        // Save register state.
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('loggedIn', true);

        // Navigate to HomePage.
        Navigator.pushReplacementNamed(context, '/homepage');
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;
    return Scaffold(
      appBar: NavBar(
        title: appBarTitle,
        isHindi: isHindi,
        onToggleLanguage: (value) {
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(value);
          _updateTranslations();
        },
      ),
      body: SingleChildScrollView(
        // Adding bottom padding ensures the content can scroll above the keyboard.
        padding: EdgeInsets.symmetric(horizontal: 20).copyWith(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 80), // Extra top spacing

            // Centered Welcome Text using welcomeText variable
            Text(
              welcomeText,
              style:
              const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40), // Space below welcome text

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Email Field
                  _buildTextField(_emailController, emailLabel),
                  const SizedBox(height: 20),

                  // Password Field
                  _buildTextField(_passwordController, passwordLabel,
                      obscureText: true),
                  const SizedBox(height: 30),

                  // Register Button
                  _buildButton(registerButtonText, _register),

                  const SizedBox(height: 50), // Extra spacing before Login Button

                  // Login Button (Navigate to Login Page)
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: Text(
                      alreadyHaveAccountText,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                  // Error Message
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 60), // More space before Need Help?

            // Need Help Button
            Center(
              child: TextButton(
                onPressed: () {
                  // Implement help action (e.g., show a dialog)
                },
                child: Text(
                  isHindi ? 'मदद चाहिए?' : 'Need Help?',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 20), // Bottom padding
          ],
        ),
      ),
    );
  }

  // Function to build a text field (box style)
  Widget _buildTextField(TextEditingController controller, String labelText,
      {bool obscureText = false}) {
    return SizedBox(
      width: 280, // Reduced width
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: labelText,
              border: InputBorder.none,
            ),
            obscureText: obscureText,
            validator: (value) =>
            value!.isEmpty ? 'This field is required' : null,
          ),
        ),
      ),
    );
  }

  // Function to build a button (box style)
  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: 280,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 5,
            ),
          ],
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
