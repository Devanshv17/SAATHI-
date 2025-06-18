// register.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translator_plus/translator_plus.dart';
import 'language_notifier.dart';
import 'navbar.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final GoogleTranslator _translator = GoogleTranslator();

  // Localized strings
  String phoneLabel     = 'Phone number';
  String phoneValidator = 'Enter a valid phone number';
  String continueText   = 'Continue';
  String appBarTitle    = 'Register';

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
          _translator.translate('Phone number', to: 'hi'),
          _translator.translate('Enter a valid phone number', to: 'hi'),
          _translator.translate('Continue', to: 'hi'),
          _translator.translate('Register', to: 'hi'),
        ]);
        setState(() {
          phoneLabel     = results[0].text;
          phoneValidator = results[1].text;
          continueText   = results[2].text;
          appBarTitle    = results[3].text;
        });
      } catch (_) { /* fallback */ }
    } else {
      setState(() {
        phoneLabel     = 'Phone number';
        phoneValidator = 'Enter a valid phone number';
        continueText   = 'Continue';
        appBarTitle    = 'Register';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;

    return Scaffold(
      appBar: NavBar(
        title: appBarTitle,
        isHindi: isHindi,
        onToggleLanguage: (val) {
          Provider.of<LanguageNotifier>(context, listen: false).toggleLanguage(val);
          _updateTranslations();
        },
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20).copyWith(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SizedBox(height: 80),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: phoneLabel),
                    validator: (v) => (v == null || v.length < 10) ? phoneValidator : null,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pushNamed(
                            context,
                            '/verify',
                            arguments: {
                              'phone': _phoneController.text.trim(),
                              'isLogin': false,
                            },
                          );
                        }
                      },
                      child: Text(continueText),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: Text(
                      isHindi
                          ? 'खाता है? लॉगिन'
                          : 'Already have an account? Login',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
