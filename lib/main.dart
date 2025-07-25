// main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_phone_auth_handler/firebase_phone_auth_handler.dart';
import 'firebase_options.dart';      
import 'language_notifier.dart';
import 'register.dart';
import 'login.dart';
import 'verify_otp.dart';
import 'homepage.dart';
import 'admin_homepage.dart';
import 'login_otp.dart';
import 'profile.dart';
import 'team.dart';
import 'about_saathi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await FirebaseAuth.instance.authStateChanges().first;
  // Load saved login state and role
  final prefs = await SharedPreferences.getInstance();
  final bool loggedIn = prefs.getBool('loggedIn') ?? false;
  final String? role  = prefs.getString('role');

  // Choose initial route
  String initialRoute;
  if (loggedIn) {
    initialRoute = (role == 'admin') ? '/admin_homepage' : '/homepage';
  } else {
    initialRoute = '/login';
  }

  runApp(
    ChangeNotifierProvider<LanguageNotifier>(
      create: (_) => LanguageNotifier(),
      child: FirebasePhoneAuthProvider(
        child: MyApp(initialRoute: initialRoute),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({Key? key, required this.initialRoute}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saathi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: initialRoute,
      routes: {
        '/register':        (context) => const RegisterPage(),
        '/login':           (context) => const LoginPage(),
        '/verify':          (context) => VerifyOtpPage(),
        '/login-otp':       (context) => const LoginOtpPage(),
        '/homepage':        (context) => const HomePage(),
        '/admin_homepage':  (context) => const AdminHomePage(),
        '/profile': (context) => const ProfilePage(),
        '/about': (_) => const AboutSaathiPage(),
        '/team': (_) =>  const TeamPage(),
      },
    );
  }
}
