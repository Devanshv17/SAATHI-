import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_notifier.dart';
import 'navbar.dart';
import 'widgets/voice_icon.dart';
import 'widgets/gradient_button.dart';
import 'theme/app_colors.dart';
import 'utils/responsive.dart';
import 'theme/text_styles.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _countryCodeController = TextEditingController(text: '+91');
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _checking = false;
  bool _isEmailLogin = false;

  String get _fullPhone =>
      '${_countryCodeController.text.trim()}${_phoneController.text.trim()}';

  Future<void> _onSendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _fullPhone;
    setState(() => _checking = true);

    // Check if phone exists in phone_to_uid index
    final key = Uri.encodeComponent(phone);
    final snap = await FirebaseDatabase.instance.ref('phone_to_uid/$key').get();

    setState(() => _checking = false);

    if (!snap.exists) {
      // Phone number not registered
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageNotifier>(context, listen: false).isHindi
                ? 'फोन नंबर उपलब्ध नहीं है'
                : 'Phone number does not exist',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } else {
      // Registered user — proceed to OTP page
      Navigator.pushNamed(
        context,
        '/login-otp', // your existing OTP handling route
        arguments: {'phone': phone},
      );
    }
  }

  Future<void> _onEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _checking = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('loggedIn', true);
      await prefs.setString('role', 'user');

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/homepage', (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Login failed'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error logging in'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _countryCodeController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: NavBar(
        isHindi: isHindi,
        onToggleLanguage: (val) =>
            Provider.of<LanguageNotifier>(context, listen: false)
                .toggleLanguage(val),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Responsive.maxFormWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Image.asset('assets/logo.png', height: 150),
              const SizedBox(height: 15),
              // Welcome text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Column(
                      children: [
                        Text(
                          isHindi ? 'स्वागत है' : 'Welcome Back',
                          style: AppTextStyles.header,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isHindi
                              ? 'कृपया अपने फ़ोन नंबर से लॉगिन करें'
                              : 'Please login with your phone number',
                          style: AppTextStyles.body,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  VoiceIcon(
                    text: isHindi
                        ? 'स्वागत है. कृपया अपने फ़ोन नंबर से लॉगिन करें'
                        : 'Welcome Back. Please login with your phone number',
                    isHindi: isHindi,
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Input Card
              Card(
                color: AppColors.cardBackground,
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ChoiceChip(
                              label: Text(isHindi ? 'फ़ोन' : 'Phone'),
                              selected: !_isEmailLogin,
                              onSelected: (val) => setState(() => _isEmailLogin = false),
                              selectedColor: AppColors.primary.withOpacity(0.2),
                            ),
                            const SizedBox(width: 16),
                            ChoiceChip(
                              label: Text(isHindi ? 'ईमेल' : 'Email'),
                              selected: _isEmailLogin,
                              onSelected: (val) => setState(() => _isEmailLogin = true),
                              selectedColor: AppColors.primary.withOpacity(0.2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              isHindi
                                  ? (_isEmailLogin ? 'अपना ईमेल दर्ज करें' : 'अपना फ़ोन नंबर दर्ज करें')
                                  : (_isEmailLogin ? 'Enter Your Email' : 'Enter Your Phone Number'),
                              style: AppTextStyles.subHeader,
                            ),
                            const SizedBox(width: 10),
                            VoiceIcon(
                              text: isHindi
                                  ? (_isEmailLogin ? 'अपना ईमेल दर्ज करें' : 'अपना फ़ोन नंबर दर्ज करें')
                                  : (_isEmailLogin ? 'Enter Your Email' : 'Enter Your Phone Number'),
                              isHindi: isHindi,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_isEmailLogin) ...[
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.email, color: AppColors.primary),
                              labelText: isHindi ? 'ईमेल' : 'Email Address',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? (isHindi ? 'मान्य ईमेल दर्ज करें' : 'Enter valid email')
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock, color: AppColors.primary),
                              labelText: isHindi ? 'पासवर्ड' : 'Password',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            validator: (v) => (v == null || v.isEmpty)
                                ? (isHindi ? 'पासवर्ड दर्ज करें' : 'Enter password')
                                : null,
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Flexible(
                                flex: 3,
                                child: TextFormField(
                                  controller: _countryCodeController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.flag, color: AppColors.primary,),
                                    labelText: isHindi ? 'कोड' : 'Code',
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? (isHindi ? 'कोड दर्ज करें' : 'Enter code')
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Flexible(
                                flex: 5,
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.phone, color: AppColors.primary,),
                                    labelText:
                                        isHindi ? 'मोबाइल नंबर' : 'Mobile Number',
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  validator: (v) => (v == null || v.length < 10)
                                      ? (isHindi
                                          ? 'मान्य नंबर दर्ज करें'
                                          : 'Enter valid number')
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 32),
                        GradientButton(
                          text: _isEmailLogin 
                            ? (isHindi ? 'प्रवेश करें' : 'Login') 
                            : (isHindi ? 'ओटीपी भेजें' : 'Send OTP'),
                          onPressed: _checking ? null : (_isEmailLogin ? _onEmailLogin : _onSendOtp),
                          isLoading: _checking,
                        ),
                        const SizedBox(height: 16),
                        // Register link
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                              context, '/register'),
                          child: Text(
                            isHindi
                                ? 'खाता नहीं है? रजिस्टर करें'
                                : "Don't have an account? Register",
                            style: AppTextStyles.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
