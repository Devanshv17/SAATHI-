import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'register.dart';
import 'login.dart';
import 'homepage.dart';
import 'admin_homepage.dart';
import 'package:provider/provider.dart';
import 'language_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Retrieve saved login state and role from SharedPreferences.
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool loggedIn = prefs.getBool('loggedIn') ?? false;
  String? role = prefs.getString('role');

  // Determine initial route based on login state and role.
  String initialRoute;
  if (loggedIn) {
    if (role == 'admin') {
      initialRoute = '/admin_homepage';
    } else {
      initialRoute = '/homepage';
    }
  } else {
    initialRoute = '/login';
  }

  runApp(
    ChangeNotifierProvider<LanguageNotifier>(
      create: (_) => LanguageNotifier(),
      child: MyApp(initialRoute: initialRoute),
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
        '/register': (context) => const RegisterPage(),
        '/login': (context) => const LoginPage(),
        '/homepage': (context) => const HomePage(),
        '/admin_homepage': (context) => const AdminHomePage(),
      },
    );
  }
}
