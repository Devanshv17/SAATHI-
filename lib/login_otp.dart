// login_otp.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_phone_auth_handler/firebase_phone_auth_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'language_notifier.dart';
import 'navbar.dart';

class LoginOtpPage extends StatefulWidget {
  const LoginOtpPage({Key? key}) : super(key: key);
  @override
  _LoginOtpPageState createState() => _LoginOtpPageState();
}

class _LoginOtpPageState extends State<LoginOtpPage> {
  late String phone;
  final _otpControllers = List.generate(6, (_) => TextEditingController());
  bool _otpInvalid = false;
  Timer? _resendTimer;
  int _resendSeconds = 60;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0)
        t.cancel();
      else
        setState(() => _resendSeconds--);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    phone = args['phone'] as String;
  }

  String get _enteredOtp => _otpControllers.map((c) => c.text).join();

  Future<void> _verifyOtp(FirebasePhoneAuthController ctrl) async {
    if (_enteredOtp.length < 6) return;
    final ok = await ctrl.verifyOtp(_enteredOtp);
    if (!ok)
      setState(() => _otpInvalid = true);
    else {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/homepage',
        (_) => false,
        arguments: {'uid': uid},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;

    return FirebasePhoneAuthHandler(
      phoneNumber: phone,
      signOutOnSuccessfulVerification: false,
      sendOtpOnInitialize: true,
      otpExpirationDuration: const Duration(seconds: 60),
      autoRetrievalTimeOutDuration: const Duration(seconds: 60),
      builder: (context, controller) {
        return Scaffold(
          backgroundColor: Colors.grey[50],
           appBar: NavBar(
            isHindi: isHindi,
            onToggleLanguage: (val) =>
                Provider.of<LanguageNotifier>(context, listen: false)
                    .toggleLanguage(val),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                // Logo + title
                Center(
                  child: Column(
                    children: [
                      Image.asset('assets/logo.png', height:150),
                      const SizedBox(height: 12),
                      Text(
                        isHindi ? 'ओटीपी की पुष्टि करें' : 'OTP Verification',
                        style: GoogleFonts.poppins(
                            fontSize: 24, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  isHindi
                      ? 'भेजा गया 6‑अंकी कोड दर्ज करें'
                      : 'Enter the 6‑digit code sent to',
                  style: GoogleFonts.poppins(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                Text(
                  phone,
                  style: GoogleFonts.poppins(
                      fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: List.generate(6, (i) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextField(
                          controller: _otpControllers[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          style: GoogleFonts.poppins(
                              fontSize: 24, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (v) {
                            if (v.isNotEmpty)
                              FocusScope.of(context).nextFocus();
                            else
                              FocusScope.of(context).previousFocus();
                          },
                        ),
                      ),
                    );
                  }),
                ),
                if (_otpInvalid) ...[
                  const SizedBox(height: 12),
                  Text(
                    isHindi
                        ? 'गलत OTP। पुनः प्रयास करें।'
                        : 'Wrong OTP. Please try again.',
                    style: GoogleFonts.poppins(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () => _verifyOtp(controller),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          isHindi ? 'ओटीपी की पुष्टि करें' : 'Verify OTP',
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: _resendSeconds > 0
                      ? Text(
                          isHindi
                              ? 'OTP फिर से भेजें में $_resendSeconds सेकंड'
                              : 'Resend OTP in $_resendSeconds s',
                          style: GoogleFonts.poppins(),
                        )
                      : TextButton(
                          onPressed: controller.sendOTP,
                          child: Text(
                            isHindi ? 'OTP पुनः भेजें' : 'Resend OTP',
                            style:
                                GoogleFonts.poppins(color: Colors.blueAccent),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
