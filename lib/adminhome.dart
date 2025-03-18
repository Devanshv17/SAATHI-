import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AdminDashboard(),
  ));
}

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String? selectedCategory;
  String questionText = "";
  String questionImageUrl = "";
  List<AnswerOption> answerOptions = [];
  String? correctAnswer;

  @override
  void initState() {
    super.initState();
    answerOptions.add(AnswerOption());
  }

  void addAnswerOption() {
    setState(() {
      answerOptions.add(AnswerOption());
    });
  }

  void removeAnswerOption(int index) {
    setState(() {
      answerOptions.removeAt(index);
    });
  }

  Future<void> saveQuestion() async {
    if (selectedCategory == null || questionText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Please select a category and enter a question.")),
      );
      return;
    }

    try {
      CollectionReference questionsCollection =
          FirebaseFirestore.instance.collection(selectedCategory!);

      Map<String, dynamic> questionData = {
        'text': questionText,
        'imageUrl':
            selectedCategory == "Guess the Letter" ? questionImageUrl : null,
        'options': answerOptions.map((option) => option.toMap()).toList(),
        'correctAnswer': correctAnswer,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (selectedCategory == "Compare") {
        questionData['compareImage1'] = answerOptions[0].imageUrl;
        questionData['compareImage2'] = answerOptions[1].imageUrl;
      }

      await questionsCollection.add(questionData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Question saved successfully!")),
      );

      // Reset form after saving
      setState(() {
        selectedCategory = null;
        questionText = "";
        questionImageUrl = "";
        correctAnswer = null;
        answerOptions = [AnswerOption()];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving question: $e")),
      );
    }
  }

  Widget buildQuestionForm() {
    if (selectedCategory == null) return Container();

    switch (selectedCategory) {
      case "Name Picture Matching":
        return buildNamePictureMatchingForm();
      case "Guess the Letter":
        return buildGuessTheLetterForm();
      case "Compare":
        return buildCompareForm();
      default:
        return buildDefaultForm();
    }
  }

  Widget buildNamePictureMatchingForm() {
    return Column(
      children: [
        buildTextField("Enter Question", (value) => questionText = value),
        ...answerOptions.map((option) => AnswerOptionWidget(
              option: option,
              onRemove: () => removeAnswerOption(answerOptions.indexOf(option)),
              onCorrectSelect: (value) => setState(() => correctAnswer = value),
            )),
        buildAddOptionButton(),
      ],
    );
  }

  Widget buildGuessTheLetterForm() {
    return Column(
      children: [
        buildTextField("Enter Question", (value) => questionText = value),
        buildTextField("Enter Image URL", (value) => questionImageUrl = value),
        ...answerOptions.map((option) => AnswerOptionWidget(
            option: option,
            onRemove: () => removeAnswerOption(answerOptions.indexOf(option)))),
        buildAddOptionButton(),
      ],
    );
  }

  Widget buildCompareForm() {
    return Column(
      children: [
        buildTextField("Enter First Image URL",
            (value) => answerOptions[0].imageUrl = value),
        buildTextField("Enter Second Image URL",
            (value) => answerOptions[1].imageUrl = value),
      ],
    );
  }

  Widget buildDefaultForm() {
    return Column(
      children: [
        buildTextField("Enter Question", (value) => questionText = value),
        ...answerOptions.map((option) => AnswerOptionWidget(
            option: option,
            onRemove: () => removeAnswerOption(answerOptions.indexOf(option)))),
        buildAddOptionButton(),
      ],
    );
  }

  Widget buildTextField(String label, Function(String) onChanged) {
    return TextField(
      onChanged: onChanged,
      decoration:
          InputDecoration(labelText: label, border: OutlineInputBorder()),
    );
  }

  Widget buildAddOptionButton() {
    return ElevatedButton.icon(
      onPressed: addAnswerOption,
      icon: Icon(Icons.add),
      label: Text("Add Option"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFCE4EC),
      appBar: AppBar(
          title: Text("Add a Question"), backgroundColor: Colors.blue.shade300),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Select Category:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: selectedCategory,
                isExpanded: true,
                hint: Text("Choose Category"),
                items: [
                  "Name Picture Matching",
                  "Guess the Letter",
                  "Compare",
                  "Let us Count",
                  "Number Name Matching",
                  "Name Number Matching",
                  "Let us Tell Time",
                  "Alphabet Knowledge"
                ]
                    .map((type) =>
                        DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                    answerOptions = [AnswerOption()];
                  });
                },
              ),
              SizedBox(height: 16),
              buildQuestionForm(),
              SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: saveQuestion,
                  child: Text("Save",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF078FFE),
                      padding:
                          EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnswerOption {
  String title = "";
  String description = "";
  String imageUrl = "";

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'imageUrl': imageUrl.isNotEmpty ? imageUrl : null
    };
  }
}

class AnswerOptionWidget extends StatelessWidget {
  final AnswerOption option;
  final VoidCallback onRemove;
  final Function(String)? onCorrectSelect;

  AnswerOptionWidget(
      {required this.option, required this.onRemove, this.onCorrectSelect});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          TextField(
              onChanged: (value) => option.title = value,
              decoration: InputDecoration(labelText: "Title")),
          TextField(
              onChanged: (value) => option.description = value,
              decoration: InputDecoration(labelText: "Description")),
          TextField(
              onChanged: (value) => option.imageUrl = value,
              decoration: InputDecoration(labelText: "Image URL")),
          IconButton(icon: Icon(Icons.delete), onPressed: onRemove),
        ],
      ),
    );
  }
}
