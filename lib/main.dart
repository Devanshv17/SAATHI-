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
  
  // Load saved role
  final prefs = await SharedPreferences.getInstance();
  final String? role  = prefs.getString('role');

  runApp(
    ChangeNotifierProvider<LanguageNotifier>(
      create: (_) => LanguageNotifier(),
      child: FirebasePhoneAuthProvider(
        child: MyApp(role: role),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String? role;
  const MyApp({Key? key, this.role}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saathi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: AuthWrapper(role: role),
      routes: {
        '/register':        (context) => const RegisterPage(),
        '/login':           (context) => const LoginPage(),
        '/verify':          (context) => VerifyOtpPage(),
        '/login-otp':       (context) => const LoginOtpPage(),
        '/homepage':        (context) => const HomePage(),
        '/admin_homepage':  (context) => const AdminHomePage(),
        '/profile':         (context) => const ProfilePage(),
        '/about':           (_) => const AboutSaathiPage(),
        '/team':            (_) =>  const TeamPage(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final String? role;
  const AuthWrapper({Key? key, this.role}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasData && snapshot.data != null) {
           if (role == 'admin') return const AdminHomePage();
           return const HomePage();
        }
        
        return const LoginPage();
      }
    );
  }
}
