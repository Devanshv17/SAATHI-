import 'package:flutter/material.dart';

class ComparePage extends StatelessWidget {
  final int a;
  final int b;

  const ComparePage({Key? key, required this.a, required this.b}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Compare"),
        backgroundColor: Colors.blue.shade300,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Instructions
            Text(
              "Instructions:",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "1. Compare the number of shapes.\n"
                  "2. Select the correct relation.\n"
                  "3. Tap 'Skip' to move forward.",
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Row containing two fixed-size grids
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShapeGrid(a, 'assets/circle.png'), // Grid of Circles
                _buildShapeGrid(b, 'assets/triangle.png'), // Grid of Triangles
              ],
            ),
            const SizedBox(height: 40),

            // Question
            Text(
              "The number of circles is ____ the number of triangles.",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Buttons for >, <, =
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: () {}, child: const Text(">")),
                ElevatedButton(onPressed: () {}, child: const Text("<")),
                ElevatedButton(onPressed: () {}, child: const Text("=")),
              ],
            ),

            const SizedBox(height: 80),

            // Skip Button
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Navigate back
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text("Skip", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Function to build a fixed-size grid for shapes
  Widget _buildShapeGrid(int count, String assetPath) {
    return Container(
      width: 150, // Fixed width
      height: 150, // Fixed height
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2), // Box border
        borderRadius: BorderRadius.circular(15), // Rounded edges
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5,
            spreadRadius: 1,
            offset: Offset(2, 2),
          )
        ],
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: count,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // 3 shapes per row
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
        ),
        itemBuilder: (context, index) {
          return Image.asset(assetPath, width: 40, height: 40);
        },
      ),
    );
  }
}



