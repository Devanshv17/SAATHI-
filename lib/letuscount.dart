import 'package:flutter/material.dart';

class LetUsCountPage extends StatelessWidget {
  // Declare the image URL internally
  final String imageUrl = 'https://example.com/sample_image.png'; // Replace with your actual URL

  LetUsCountPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Define a button style with rounded corners (10 pixels) matching the image frame.
    final buttonStyle = ElevatedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Let Us Count"),
        backgroundColor: Colors.blue.shade300,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0), // Fixed vertical padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "Image:",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: imageUrl.isNotEmpty
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  )
                      : Center(
                    child: Icon(Icons.image, size: 80, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Select the correct option:",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                // Use LayoutBuilder to compute horizontal gap automatically.
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Total width available in the grid.
                    double totalWidth = constraints.maxWidth;
                    // Set button percentage (e.g., 0.4 for 40% of total width).
                    double buttonPercentage = 0.4;
                    // Calculate button size.
                    double buttonSize = totalWidth * buttonPercentage;
                    // Calculate gap: remaining width divided equally into three gaps.
                    double gap = (totalWidth - (2 * buttonSize)) / 3;

                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10, // Fixed vertical spacing.
                      crossAxisSpacing: gap,
                      padding: EdgeInsets.symmetric(horizontal: gap),
                      children: [
                        SizedBox(
                          width: buttonSize,
                          height: buttonSize,
                          child: ElevatedButton(
                            style: buttonStyle,
                            onPressed: () {
                              // Option 1 logic here.
                            },
                            child: const Text("Option 1"),
                          ),
                        ),
                        SizedBox(
                          width: buttonSize,
                          height: buttonSize,
                          child: ElevatedButton(
                            style: buttonStyle,
                            onPressed: () {
                              // Option 2 logic here.
                            },
                            child: const Text("Option 2"),
                          ),
                        ),
                        SizedBox(
                          width: buttonSize,
                          height: buttonSize,
                          child: ElevatedButton(
                            style: buttonStyle,
                            onPressed: () {
                              // Option 3 logic here.
                            },
                            child: const Text("Option 3"),
                          ),
                        ),
                        SizedBox(
                          width: buttonSize,
                          height: buttonSize,
                          child: ElevatedButton(
                            style: buttonStyle,
                            onPressed: () {
                              // Option 4 logic here.
                            },
                            child: const Text("Option 4"),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
