import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LetUsCountPage extends StatefulWidget {
  const LetUsCountPage({Key? key}) : super(key: key);

  @override
  _LetUsCountPageState createState() => _LetUsCountPageState();
}

class _LetUsCountPageState extends State<LetUsCountPage> {
  String question = "";
  List<String> images = [];
  int numberField = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchQuestion();
  }

  Future<void> fetchQuestion() async {
    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('Let us Count')
          .get(const GetOptions(source: Source.serverAndCache));

      if (snapshot.docs.isNotEmpty) {
        var data = snapshot.docs.first.data();

        setState(() {
          question = data['text'] ?? "How many objects do you see?";
          numberField = int.tryParse(data['numberField'].toString()) ?? 0;
          images = List<Map<String, dynamic>>.from(data['options'])
              .map((option) => option['imageUrl']?.toString() ?? '')
              .where((url) => url.isNotEmpty)
              .take(numberField)
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching question: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Let Us Count"),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: images.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        images[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
