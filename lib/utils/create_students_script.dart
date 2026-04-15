import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateStudentsPage extends StatefulWidget {
  const CreateStudentsPage({Key? key}) : super(key: key);

  @override
  _CreateStudentsPageState createState() => _CreateStudentsPageState();
}

class _CreateStudentsPageState extends State<CreateStudentsPage> {
  bool _isWorking = false;
  String _status = 'Press the button to start creating 31 students.';
  double _progress = 0;
  
  final List<String> studentNames = [
    "Arushi", "Almeen Bano", "Aditya", "Aditya singh", "Afreen Bano", 
    "Anamika", "Ansh Yadav", "Anzel Rana", "Aryan", "Chhavi", 
    "Dev", "Devika", "Divyansh Gupta", "Hemant", "Khushboo", 
    "Mahima", "Mayank", "Mohammad Avesh", "Prince", "Raj", 
    "Raman", "Saniya Bano", "Shreshthi", "Shreyansh", "Shubh", 
    "Shubhi", "Sonamika", "Tanay Yadav", "Vansh Raj", "Vanshika", "Vivan","Extra1","Extra2","Extra3","Extra4","Extra5"
  ];

  Future<void> _createAccounts() async {
    setState(() {
      _isWorking = true;
      _status = 'Starting creation of ${studentNames.length} accounts...';
      _progress = 0;
    });
    
    // Attempting to remember original user state if logged in
    final originalUser = FirebaseAuth.instance.currentUser;
    int successCount = 0;

    for (int i = 0; i < studentNames.length; i++) {
        final name = studentNames[i];
        final emailBase = name.replaceAll(' ', '').toLowerCase();
        final email = '$emailBase@saathi.com';
        
        // Passwords must be at least 6 characters in Firebase
        String password = name;
        if (password.length < 6) {
           final pad = "123456";
           password = password + pad.substring(0, 6 - password.length);
        }
        
        setState(() {
          _status = 'Creating (${i+1}/${studentNames.length}):\nEmail: $email\nPassword: $password';
          _progress = (i + 1) / studentNames.length;
        });
        
        try {
            final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email, 
              password: password
            );
            final uid = userCred.user!.uid;
            
            await FirebaseDatabase.instance.ref('users/$uid').set({
                'name': name,
                'age': 8, // Using 8 as a typical average age
                'gender': 'Other',
                'school': true,
                'role': 'user',
                'createdViaAdminScript': true,
            });
            successCount++;
            await Future.delayed(const Duration(milliseconds: 500)); // avoid rate limits
        } on FirebaseAuthException catch (e) {
             print("Failed to create $email: ${e.message}");
             if (e.code == 'email-already-in-use') {
                 // Already created if script was run before
                 successCount++;
             }
        }
    }
    
    setState(() {
       _isWorking = false;
       _status = 'Finished! Successfully processed $successCount accounts.\nNote: Auth state has completely changed. Please restart app or log out.';
    });
    
    if (originalUser == null) {
      // make sure everything is cleared out
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       appBar: AppBar(
         title: const Text('Admin Script'),
         backgroundColor: Colors.teal,
       ),
       body: Center(
         child: Padding(
           padding: const EdgeInsets.all(24.0),
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               const Icon(Icons.group_add, size: 64, color: Colors.teal),
               const SizedBox(height: 20),
               Text(
                 'Student Accounts Generator', 
                 style: Theme.of(context).textTheme.headlineSmall,
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 10),
               Text(
                 'This will create 31 predefined students.\nShort names (like "Dev") will have passwords padded like "Dev123".\nE.g. almeenbano@saathi.com',
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.grey[700]),
               ),
               const SizedBox(height: 30),
               LinearProgressIndicator(value: _progress),
               const SizedBox(height: 20),
               Text(
                 _status, 
                 style: const TextStyle(fontSize: 16),
                 textAlign: TextAlign.center,
               ),
               const SizedBox(height: 40),
               SizedBox(
                 width: double.infinity,
                 height: 50,
                 child: ElevatedButton(
                   onPressed: _isWorking ? null : _createAccounts,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.teal,
                     foregroundColor: Colors.white,
                   ),
                   child: _isWorking 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Run Script', style: TextStyle(fontSize: 18)),
                 ),
               ),
             ],
           ),
         ),
       ),
    );
  }
}
