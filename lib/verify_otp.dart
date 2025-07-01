import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_phone_auth_handler/firebase_phone_auth_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'navbar.dart';
import 'language_notifier.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';

class VerifyOtpPage extends StatefulWidget {
  const VerifyOtpPage({Key? key}) : super(key: key);
  @override
  _VerifyOtpPageState createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  late String phone;
  StreamController<ErrorAnimationType> _errorController = StreamController();
  bool _otpInvalid = false, _showDetailsForm = false;
  String _currentPin = "";

  // details form
  final _detailsFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String? _gender;
  bool _goToSchool = false;
  final _classController = TextEditingController();

  Timer? _resendTimer;
  int _resendSeconds = 60;
  late TapGestureRecognizer _tapGestureRecognizer;

  @override
  void initState() {
    super.initState();
    _tapGestureRecognizer = TapGestureRecognizer()
      ..onTap = () => _openLink(
          'https://docs.google.com/document/d/1NbMeLWRfKDAzxsAiboI1dccPBOxn-KZw39eLVfXKbhU/edit?usp=sharing');
    _startResendCountdown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _errorController.close();
    _tapGestureRecognizer.dispose();
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

  void _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }

  String get _enteredOtp => _currentPin;

  Future<void> _verifyOtp(FirebasePhoneAuthController ctrl) async {
    if (_enteredOtp.length < 6) return;
    final ok = await ctrl.verifyOtp(_enteredOtp);
    if (!ok) {
      _errorController.add(ErrorAnimationType.shake);
      setState(() => _otpInvalid = true);
    } else {
      setState(() {
        _otpInvalid = false;
        _showDetailsForm = true;
      });
    }
  }

  Future<void> _submitDetails() async {
    if (!_detailsFormKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;

    final userRef = FirebaseDatabase.instance.ref('users/$uid');
    await userRef.set({
      'name': _nameController.text.trim(),
      'age': int.parse(_ageController.text),
      'gender': _gender ?? '',
      'school': _goToSchool,
      if (_goToSchool) 'class': _classController.text.trim(),
      'phone': phone,
    });

    final phoneIndexRef = FirebaseDatabase.instance
        .ref('phone_to_uid/${Uri.encodeComponent(phone)}');
    await phoneIndexRef.set(uid);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', true);
    await prefs.setString('role', 'user');

    Navigator.pushNamedAndRemoveUntil(context, '/homepage', (_) => false);
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
      builder: (ctx, controller) {
        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.grey[50],
          appBar: NavBar(
            isHindi: isHindi,
            onToggleLanguage: (v) =>
                Provider.of<LanguageNotifier>(context, listen: false)
                    .toggleLanguage(v),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _showDetailsForm
                  ? _buildDetailsForm(isHindi)
                  : _buildOtpForm(isHindi, controller),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOtpForm(bool isHindi, FirebasePhoneAuthController ctrl) {
    return Column(
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
              ? 'भेजा गया 6-अंकी कोड दर्ज करें'
              : 'Enter the 6-digit code sent to',
          style: GoogleFonts.poppins(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        Text(
          phone,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
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
          textStyle:
              GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w500),
          onChanged: (val) {
            setState(() {
              _currentPin = val;
              _otpInvalid = false;
            });
          },
          onCompleted: (_) => _verifyOtp(ctrl),
        ),
        if (_otpInvalid) ...[
          const SizedBox(height: 12),
          Text(
            isHindi
                ? 'गलत ओटीपी पुनः प्रयास करें।'
                : 'Wrong OTP. Please try again.',
            style: GoogleFonts.poppins(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => _verifyOtp(ctrl),
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
                  isHindi ? 'OTP सत्यापित करें' : 'Verify OTP',
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
                    ctrl.sendOTP();
                    _startResendCountdown();
                  },
                  child: Text(
                    isHindi ? 'OTP पुनः भेजें' : 'Resend OTP',
                    style: GoogleFonts.poppins(color: Colors.blueAccent),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDetailsForm(bool isHindi) {
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isHindi ? 'मूल विवरण' : 'Basic Details',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          _buildField(_nameController, isHindi ? 'नाम' : 'Name', Icons.person),
          const SizedBox(height: 16),
          _buildField(
              _ageController, isHindi ? 'आयु' : 'Age', Icons.calendar_today,
              isNumber: true),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.wc),
              labelText: isHindi ? 'लिंग' : 'Gender',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            dropdownColor: Colors.white,
            icon: const Icon(Icons.arrow_drop_down,
                size: 28, color: Colors.blueAccent),
            items: ['Male', 'Female', 'Other']
                .map((g) => DropdownMenuItem(
                    value: g, child: Text(isHindi ? _translateGender(g) : g)))
                .toList(),
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: Text(
                isHindi ? 'क्या आप स्कूल जाते हैं?' : 'Do you go to school?',
                style: GoogleFonts.poppins()),
            value: _goToSchool,
            onChanged: (v) => setState(() => _goToSchool = v!),
          ),
          if (_goToSchool) ...[
            const SizedBox(height: 8),
            _buildField(
                _classController, isHindi ? 'कक्षा' : 'Class', Icons.school),
          ],
          const SizedBox(height: 15),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.poppins(
                      fontSize: 16, color: Colors.grey[700]),
                  children: [
                    TextSpan(
                      text: isHindi
                          ? '“खाता बनाएँ” पर क्लिक करने पर, आप हमारी '
                          : 'On clicking Create Account, you are agreeing to our ',
                    ),
                    TextSpan(
                      text: isHindi
                          ? 'शर्तें और गोपनीयता नीति'
                          : 'Terms and Privacy Policy',
                      style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline),
                      recognizer: _tapGestureRecognizer,
                    ),
                    TextSpan(text: isHindi ? ' से सहमत होते हैं।' : '.'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _submitDetails,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: EdgeInsets.zero,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF00C6FF), Color(0xFF0072FF)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    isHindi ? 'खाता बनाएँ' : 'Create Account',
                    style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _translateGender(String g) {
    switch (g) {
      case 'Male':
        return 'पुरुष';
      case 'Female':
        return 'महिला';
      default:
        return 'अन्य';
    }
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon,
      {bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }
}
