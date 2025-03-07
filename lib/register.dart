import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'navbar.dart';
import 'package:provider/provider.dart';
import 'language_notifier.dart';
import 'package:translator_plus/translator_plus.dart';

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
  String emailLabel = 'Email';
  String passwordLabel = 'Password';
  String emailValidator = 'Please enter an email';
  String passwordValidator = 'Password must be at least 6 characters';
  String registerButtonText = 'Register';
  String appBarTitle = 'Register';

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
          translator.translate('Register', to: 'hi'),
          translator.translate('Register', to: 'hi'),
        ]);
        setState(() {
          emailLabel = results[0].text;
          emailValidator = results[1].text;
          passwordLabel = results[2].text;
          passwordValidator = results[3].text;
          registerButtonText = results[4].text;
          appBarTitle = results[5].text;
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
      });
    }
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        // Save login state.
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('loggedIn', true);
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
                    value!.length < 6 ? passwordValidator : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _register,
                    child: Text(registerButtonText),
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
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Text(isHindi
                  ? 'पहले से खाता है? लॉगिन'
                  : "Already have an account? Login"),
            ),
          ],
        ),
      ),
    );
  }
}
