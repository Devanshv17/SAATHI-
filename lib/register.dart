import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'language_notifier.dart';
import 'navbar.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _countryCodeController = TextEditingController(text: "+91");
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: NavBar(
        isHindi: isHindi,
        onToggleLanguage: (val) {
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(val);
        },
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
  
              // Logo above the card
              Image.asset(
                'assets/logo.png',
                height: 150,
              ),
               const SizedBox(height: 15),
              // Welcome text
              Text(
                isHindi ? 'स्वागत है' : 'Create a new Account',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isHindi
                    ? 'कृपया अपने फ़ोन नंबर से पंजीकरण करें'
                    : 'Please register with your phone number',
                style:
                    GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isHindi
                            ? 'अपना फ़ोन नंबर दर्ज करें'
                            : 'Enter Your Phone Number',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        child: Row(
                          children: [
                            Flexible(
                              flex: 3,
                              child: TextFormField(
                                controller: _countryCodeController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.flag),
                                  labelText: isHindi ? 'कोड' : 'Code',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                                  prefixIcon: const Icon(Icons.phone),
                                  labelText:
                                      isHindi ? 'मोबाइल नंबर' : 'Mobile Number',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              final fullPhone =
                                  "${_countryCodeController.text.trim()}${_phoneController.text.trim()}";
                              Navigator.pushNamed(context, '/verify',
                                  arguments: {'phone': fullPhone});
                            }
                          },
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                isHindi ? 'ओटीपी  भेजें' : 'Send OTP',
                                style: GoogleFonts.poppins(
                                    fontSize: 16, fontWeight: FontWeight.w500,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: Text(
                          isHindi
                              ? 'खाता है? लॉगिन'
                              : 'Already have an account? Login',
                          style: GoogleFonts.poppins(color: Colors.blueAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
