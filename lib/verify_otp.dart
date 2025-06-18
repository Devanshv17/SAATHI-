// verify_otp.dart

import 'package:flutter/material.dart';
import 'package:firebase_phone_auth_handler/firebase_phone_auth_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';

class VerifyOtpPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args    = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final phone   = args['phone']   as String;
    final isLogin = args['isLogin'] as bool;

    return FirebasePhoneAuthHandler(
      phoneNumber:                     phone,
      signOutOnSuccessfulVerification: false,
      sendOtpOnInitialize:             true,
      autoRetrievalTimeOutDuration:    const Duration(seconds: 60),
      otpExpirationDuration:           const Duration(seconds: 60),

      builder: (context, controller) {
        return Scaffold(
          appBar: AppBar(title: Text(isLogin ? 'Login' : 'Register')),
          body: Center(
            child: controller.isSendingCode
                ? const CircularProgressIndicator()
                : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('OTP sent to $phone'),
                  if (controller.codeSent) ...[
                    TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Enter OTP'),
                      onSubmitted: (code) async {
                        final success = await controller.verifyOtp(code);
                        if (success) {
                          // Pull the signed-in user
                          final user = FirebaseAuth.instance.currentUser!;
                          final uid  = user.uid;
                          final ref  = FirebaseDatabase.instance.ref('users/$uid');

                          if (!isLogin) {
                            // New user: set default role & games
                            final initialGames = {
                              'Name Picture Matching': {'score': 0, 'answers': []},
                              'Guess the Letter'      : {'score': 0, 'answers': []},
                              // … add the rest …
                            };
                            await ref.set({
                              'role': 'user',
                              'games': initialGames,
                            });
                          }

                          // Save prefs
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('loggedIn', true);
                          if (isLogin) {
                            final snap = await FirebaseDatabase.instance
                                .ref('users/$uid/role')
                                .get();
                            final role = snap.value?.toString() ?? 'user';
                            await prefs.setString('role', role);
                          } else {
                            await prefs.setString('role', 'user');
                          }

                          // Navigate
                          final roleStored = prefs.getString('role');
                          if (isLogin && roleStored == 'admin') {
                            Navigator.pushNamedAndRemoveUntil(
                                context, '/admin_homepage', (_) => false);
                          } else {
                            Navigator.pushNamedAndRemoveUntil(
                                context, '/homepage', (_) => false);
                          }
                        }
                      },
                    ),
                  ],
                  if (controller.isListeningForOtpAutoRetrieve)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text('Waiting for SMS...'),
                    ),
                  if (controller.isOtpExpired)
                    TextButton(
                      onPressed: controller.sendOTP,
                      child: const Text('Resend OTP'),
                    ),
                ],
              ),
            ),
          ),
        );
      },

      onLoginFailed: (e, _) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      },
      onError: (err, _) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Something went wrong')));
      },
      onLoginSuccess: (_, __) {},
    );
  }
}
