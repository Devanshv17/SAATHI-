import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'register.dart';
import 'login.dart';
import 'homepage.dart';
import 'package:provider/provider.dart';
import 'language_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Check saved login state from SharedPreferences.
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool loggedIn = prefs.getBool('loggedIn') ?? false;

  runApp(
    ChangeNotifierProvider<LanguageNotifier>(
      create: (_) => LanguageNotifier(),
      child: MyApp(loggedIn: loggedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool loggedIn;
  const MyApp({Key? key, required this.loggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saathi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: loggedIn ? '/homepage' : '/register',
      routes: {
        '/register': (context) => const RegisterPage(),
        '/login': (context) => const LoginPage(),
        '/homepage': (context) => const HomePage(),
      },
    );
  }
}
