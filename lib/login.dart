import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'navbar.dart';
import 'package:provider/provider.dart';
import 'language_notifier.dart';
import 'package:translator_plus/translator_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // UI strings (default English)
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
    final isHindi =
        Provider.of<LanguageNotifier>(context, listen: false).isHindi;
    if (isHindi) {
      try {
        final results = await Future.wait([
          translator.translate('Email', to: 'hi'),
          translator.translate('Please enter an email', to: 'hi'),
          translator.translate('Password', to: 'hi'),
          translator.translate('Please enter a password', to: 'hi'),
          translator.translate('Login', to: 'hi'),
          translator.translate('Login', to: 'hi'),
        ]);
        setState(() {
          emailLabel = results[0].text;
          emailValidator = results[1].text;
          passwordLabel = results[2].text;
          passwordValidator = results[3].text;
          loginButtonText = results[4].text;
          appBarTitle = results[5].text;
        });
      } catch (e) {
        // Fallback to English if translation fails.
      }
    } else {
      setState(() {
        emailLabel = 'Email';
        emailValidator = 'Please enter an email';
        passwordLabel = 'Password';
        passwordValidator = 'Please enter a password';
        loginButtonText = 'Login';
        appBarTitle = 'Login';
      });
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Save login state in SharedPreferences.
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: emailLabel),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                    value!.isEmpty ? emailValidator : null,
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: passwordLabel),
                    obscureText: true,
                    validator: (value) =>
                    value!.isEmpty ? passwordValidator : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _login,
                    child: Text(loginButtonText),
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/register');
              },
              child: Text(isHindi
                  ? 'खाता नहीं है? पंजीकरण करें'
                  : "Don't have an account? Register"),
            ),
          ],
        ),
      ),
    );
  }
}
