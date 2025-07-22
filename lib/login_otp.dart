// login_otp.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_phone_auth_handler/firebase_phone_auth_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'language_notifier.dart';
import 'navbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginOtpPage extends StatefulWidget {
  const LoginOtpPage({Key? key}) : super(key: key);

  @override
  _LoginOtpPageState createState() => _LoginOtpPageState();
}

class _LoginOtpPageState extends State<LoginOtpPage> {
  bool _isVerifying = false;
  late String phone;
  bool _otpInvalid = false;
  Timer? _resendTimer;
  int _resendSeconds = 60;

  String _currentPin = '';
  final StreamController<ErrorAnimationType> _errorController =
      StreamController<ErrorAnimationType>.broadcast();

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _errorController.close();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) {
        t.cancel();
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    phone = args['phone'] as String;
  }

  Future<void> _verifyOtp(FirebasePhoneAuthController ctrl) async {
    if (_currentPin.length < 6 || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _otpInvalid = false; // Immediately hide previous error
    });

    final ok = await ctrl.verifyOtp(_currentPin);
    if (!mounted) return;

    if (!ok) {
      setState(() => _otpInvalid = true);
      _errorController.add(ErrorAnimationType.shake);
    } else {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('loggedIn', true);
      await prefs.setString('role', 'user');

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/homepage',
              (_) => false,
          arguments: {'uid': uid},
        );
      }
    }

    if (mounted) {
      setState(() => _isVerifying = false);
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
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      Image.asset('assets/logo.png', height: 150),
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
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  autoFocus: true,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(12),
                    fieldHeight: 60,
                    fieldWidth: 48,
                    activeFillColor: Colors.white,
                    selectedFillColor: Colors.white,
                    inactiveFillColor: Colors.white,
                    activeColor: Colors.blueAccent,
                    selectedColor: Colors.blue,
                    inactiveColor: Colors.grey,
                  ),
                  cursorColor: Colors.black,
                  enableActiveFill: true,
                  errorAnimationController: _errorController,
                  keyboardType: TextInputType.number,
                  textStyle: GoogleFonts.poppins(
                      fontSize: 24, fontWeight: FontWeight.w500),
                  onChanged: (val) {
                    setState(() {
                      _currentPin = val;
                      _otpInvalid = false;
                    });
                  },
                  onCompleted: (_) => _verifyOtp(controller),
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
                    onPressed: () => _verifyOtp(controller),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: EdgeInsets.zero,
                    ),
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
                          onPressed: () {
                            controller.sendOTP();
                            _startResendCountdown();
                          },
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
