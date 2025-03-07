import 'package:flutter/material.dart';

class GamePage extends StatelessWidget {
  final String gameTitle;

  const GamePage({Key? key, required this.gameTitle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(gameTitle),
        backgroundColor: Colors.blue.shade300,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Instructions:",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "1. Read the question carefully.\n"
              "2. Tap on the correct image to answer.\n"
              "3. Try to score maximum points!",
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Text(
              "Question: What is shown in the image?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Wrap GridView in Expanded to avoid overflow
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  Image.asset('assets/image.png', fit: BoxFit.cover),
                  Image.asset('assets/image.png', fit: BoxFit.cover),
                  Image.asset('assets/image.png', fit: BoxFit.cover),
                  Image.asset('assets/image.png', fit: BoxFit.cover),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text("Your Score: 0", style: TextStyle(fontSize: 20)),
            Text("Maximum Score: 10", style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }
}
