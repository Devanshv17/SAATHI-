import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saathi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: CircleAvatar(
              backgroundImage: AssetImage(
                  'assets/user.png'), // Add your user profile image
            ),
            onPressed: () {
              // Handle profile icon tap
              print("Profile icon tapped");
            },
          ),
        ],
        backgroundColor: Colors.blue, // Change the color if needed
        elevation: 0, // Removes shadow for a flat look
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              buildRow("Box 1", "Box 2"),
              SizedBox(height: 10), // Spacing between rows
              buildRow("Box 3", "Box 4"),
            ],
          ),
        ),
      ),
    );
  }
  Widget buildRow(String text1, String text2) {
    return Row(
      children: [
        Expanded(child: buildBox(text1)),
        SizedBox(width: 10), // Spacing between boxes
        Expanded(child: buildBox(text2)),
      ],
    );
  }

  Widget buildBox(String text) {
    return Container(
      height: 200, // Adjust height as needed
      decoration: BoxDecoration(
        color: Color(0xFFFFFDD0), // Creamish color
        border: Border.all(color: Colors.black, width: 2), // Black border
        borderRadius: BorderRadius.circular(10), // Rounded corners
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
