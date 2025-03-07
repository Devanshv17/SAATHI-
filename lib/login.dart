import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:translator_plus/translator_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'language_notifier.dart';
import 'navbar.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleTranslator translator = GoogleTranslator();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String _errorMessage = '';

  // UI Strings
  String welcomeText = 'Welcome!';
  String emailLabel = 'Email';
  String passwordLabel = 'Password';
  String emailValidator = 'Please enter an email';
  String passwordValidator = 'Please enter a password';
  String loginButtonText = 'Login';
  String appBarTitle = 'Login';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final isHindi = Provider.of<LanguageNotifier>(context, listen: false).isHindi;
    if (isHindi) {
      try {
        final results = await Future.wait([
          translator.translate('Email', to: 'hi'),
          translator.translate('Please enter an email', to: 'hi'),
          translator.translate('Password', to: 'hi'),
          translator.translate('Please enter a password', to: 'hi'),
          translator.translate('Login', to: 'hi'),
          translator.translate('Login', to: 'hi'),
          translator.translate('Welcome!', to: 'hi'),
        ]);
        setState(() {
          emailLabel = results[0].text;
          emailValidator = results[1].text;
          passwordLabel = results[2].text;
          passwordValidator = results[3].text;
          loginButtonText = results[4].text;
          appBarTitle = results[5].text;
          welcomeText = results[6].text;
        });
      } catch (e) {
        // Fallback to English if translation fails
      }
    } else {
      setState(() {
        emailLabel = 'Email';
        emailValidator = 'Please enter an email';
        passwordLabel = 'Password';
        passwordValidator = 'Please enter a password';
        loginButtonText = 'Login';
        appBarTitle = 'Login';
        welcomeText = 'Welcome!';
      });
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('loggedIn', true);

        final uid = userCredential.user!.uid;
        DatabaseReference roleRef =
        FirebaseDatabase.instance.ref("users/$uid/role");
        DataSnapshot snapshot = await roleRef.get();
        final role = snapshot.value?.toString() ?? "user";

        await prefs.setString('role', role);

        if (role == "admin") {
          Navigator.pushReplacementNamed(context, '/admin_homepage');
        } else {
          Navigator.pushReplacementNamed(context, '/homepage');
        }
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
      // Let the keyboard overlay the page without resizing the layout.
      resizeToAvoidBottomInset: true,
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
        // Adding bottom padding using viewInsets ensures scrolling space when the keyboard is open.
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
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40), // Space below welcome text

            Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Email Field
                  _buildTextField(_emailController, emailLabel),
                  const SizedBox(height: 20),

                  // Password Field
                  _buildTextField(_passwordController, passwordLabel,
                      obscureText: true),
                  const SizedBox(height: 30),

                  // Login Button
                  _buildButton(loginButtonText, _login),

                  const SizedBox(height: 50), // Extra spacing before Register Button

                  // Register Button
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/register');
                    },
                    child: Text(
                      isHindi
                          ? 'खाता नहीं है? पंजीकरण करें'
                          : "Don't have an account? Register",
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),

                  // Error Message
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _errorMessage,
                        style:
                        const TextStyle(color: Colors.red, fontSize: 14),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
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
