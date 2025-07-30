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
  final StreamController<ErrorAnimationType> _errorController = StreamController();
  bool _otpInvalid = false, _showDetailsForm = false;
  String _currentPin = "";

  bool _isVerifying = false;
  // ADD THIS: Flag to ensure OTP is sent only once
  bool _hasOtpBeenSent = false;

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
    _nameController.dispose();
    _ageController.dispose();
    _classController.dispose();
    _errorController.close();
    _tapGestureRecognizer.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
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

  void _openLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  String get _enteredOtp => _currentPin;

  Future<void> _verifyOtp(FirebasePhoneAuthController ctrl) async {
    if (_enteredOtp.length < 6 || _isVerifying) return;

    setState(() {
      _isVerifying = true;
      _otpInvalid = false;
    });

    final ok = await ctrl.verifyOtp(_enteredOtp);
    if (!mounted) return;

    if (!ok) {
      _errorController.add(ErrorAnimationType.shake);
      setState(() {
        _otpInvalid = true;
        _isVerifying = false;
      });
    } else {
      setState(() {
        _isVerifying = false;
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

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/homepage', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;
    return FirebasePhoneAuthHandler(
      phoneNumber: phone,
      signOutOnSuccessfulVerification: false,
      // CHANGE THIS: to false to control sending manually
      sendOtpOnInitialize: false,
      otpExpirationDuration: const Duration(minutes: 10),
      autoRetrievalTimeOutDuration: Duration.zero,
      builder: (ctx, controller) {
        // ADD THIS: Logic to send OTP only once
        if (!_hasOtpBeenSent) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              controller.sendOTP();
              setState(() {
                _hasOtpBeenSent = true;
              });
            }
          });
        }

        return Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Color.fromARGB(255, 245, 255, 255),
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
                style: GoogleFonts.trocchi(
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
          style: GoogleFonts.trocchi(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        Text(
          phone,
          style: GoogleFonts.trocchi(fontSize: 18, fontWeight: FontWeight.w600),
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
            activeColor: Colors.cyan,
            selectedColor: Colors.teal,
            inactiveColor: Colors.grey,
          ),
          cursorColor: Colors.black,
          enableActiveFill: true,
          errorAnimationController: _errorController,
          keyboardType: TextInputType.number,
          textStyle:
          GoogleFonts.trocchi(fontSize: 24, fontWeight: FontWeight.w500),
          onChanged: (val) {
            setState(() {
              _currentPin = val;
              if (_otpInvalid) {
                _otpInvalid = false; // Reset error when user types
              }
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
            style: GoogleFonts.trocchi(color: Colors.redAccent),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          // CHANGE THIS: To show loading indicator on the button
          child: ElevatedButton(
            onPressed: _isVerifying ? null : () => _verifyOtp(ctrl),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: EdgeInsets.zero,
            ),
            child: _isVerifying
                ? const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.white),
            )
                : Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color.fromARGB(255, 101, 221, 209),
                    Color.fromARGB(255, 101, 65, 239)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  isHindi ? 'OTP सत्यापित करें' : 'Verify OTP',
                  style: GoogleFonts.trocchi(
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
            style: GoogleFonts.trocchi(),
          )
              : TextButton(
            // CHANGE THIS: Add safety check
            onPressed: () {
              if (_isVerifying) return;
              ctrl.sendOTP();
              _startResendCountdown();
            },
            child: Text(
              isHindi ? 'OTP पुनः भेजें' : 'Resend OTP',
              style: GoogleFonts.trocchi(color: Color.fromARGB(255, 101, 65, 239)),
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
              style: GoogleFonts.trocchi(
                  fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          _buildField(_nameController, isHindi ? 'नाम' : 'Name', Icons.person),
          const SizedBox(height: 16),
          _buildField(
              _ageController, isHindi ? 'आयु' : 'Age', Icons.calendar_today,
              isNumber: true),
          const SizedBox(height: 16),
          // CHANGE THIS: Added validator
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
                size: 28, color: Colors.teal),
            items: ['Male', 'Female', 'Other']
                .map((g) => DropdownMenuItem(
                value: g, child: Text(isHindi ? _translateGender(g) : g)))
                .toList(),
            onChanged: (v) => setState(() => _gender = v),
            validator: (v) => (v == null || v.isEmpty)
                ? (isHindi ? 'यह आवश्यक है' : 'Required')
                : null,
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: Text(
                isHindi ? 'क्या आप स्कूल जाते हैं?' : 'Do you go to school?',
                style: GoogleFonts.trocchi()),
            value: _goToSchool,
            onChanged: (v) => setState(() => _goToSchool = v!),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
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
                  style: GoogleFonts.trocchi(
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
                          color:
                          Color.fromARGB(255, 101, 65, 239),
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
                      colors: [Color.fromARGB(255, 101, 221, 209),
                        Color.fromARGB(255, 101, 65, 239)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    isHindi ? 'खाता बनाएँ' : 'Create Account',
                    style: GoogleFonts.trocchi(
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
    // CHANGE THIS: Added language-aware validation
    final isHindi = Provider.of<LanguageNotifier>(context, listen: false).isHindi;
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) {
          return isHindi ? 'यह आवश्यक है' : 'Required';
        }
        if (isNumber && int.tryParse(v) == null) {
          return isHindi ? 'अमान्य संख्या' : 'Invalid number';
        }
        return null;
      },
    );
  }
}