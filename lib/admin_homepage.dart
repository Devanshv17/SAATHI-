import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:translator_plus/translator_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'navbar.dart';
import 'menu_bar.dart';
import 'language_notifier.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({Key? key}) : super(key: key);

  @override
  _AdminHomePageState createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final GoogleTranslator translator = GoogleTranslator();
  String appBarTitle = 'Admin Panel';

  // Admin Dashboard variables
  String? selectedCategory;
  String questionText = "";
  String questionImageUrl = "";
  List<AnswerOption> answerOptions = [];
  String? correctAnswer;

  @override
  void initState() {
    super.initState();
    answerOptions.add(AnswerOption());
    _updateTranslations();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final isHindi =
        Provider.of<LanguageNotifier>(context, listen: false).isHindi;
    if (isHindi) {
      try {
        final result = await translator.translate('Admin Panel', to: 'hi');
        setState(() {
          appBarTitle = result.text;
        });
      } catch (e) {
        setState(() {
          appBarTitle = 'Admin Panel';
        });
      }
    } else {
      setState(() {
        appBarTitle = 'Admin Panel';
      });
    }
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
        SnackBar(content: Text("Please select a category and enter a question.")),
      );
      return;
    }

    try {
      CollectionReference questionsCollection =
      FirebaseFirestore.instance.collection(selectedCategory!);

      Map<String, dynamic> questionData = {
        'text': questionText,
        'imageUrl': selectedCategory == "Guess the Letter" ? questionImageUrl : null,
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

  /// This function uses ImagePicker to choose an image from the gallery,
  /// uploads it to Imgur, and returns the URL.
  Future<String?> _chooseAndUploadImage() async {
    const clientId = '72c6c45319d3658';
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedImage =
      await picker.pickImage(source: ImageSource.gallery);
      if (pickedImage == null) return null;

      final fileBytes = await pickedImage.readAsBytes();
      final base64Image = base64Encode(fileBytes);

      final response = await http.post(
        Uri.parse('https://api.imgur.com/3/image'),
        headers: {'Authorization': 'Client-ID $clientId'},
        body: {'image': base64Image},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['link'];
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      print('Error uploading image: $e');
      return null;
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
        // Replace text field for image URL with an image chooser button.
        ElevatedButton.icon(
          onPressed: () async {
            final url = await _chooseAndUploadImage();
            if (url != null) {
              setState(() {
                questionImageUrl = url;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Image uploaded successfully!")));
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Image upload failed.")));
            }
          },
          icon: Icon(Icons.photo),
          label: Text(questionImageUrl.isEmpty ? "Choose Image" : "Change Image"),
        ),
        // Show image preview if available.
        if (questionImageUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Image.network(
              questionImageUrl,
              height: 150,
            ),
          ),
        ...answerOptions.map((option) => AnswerOptionWidget(
            option: option,
            onRemove: () => removeAnswerOption(answerOptions.indexOf(option)))),
        buildAddOptionButton(),
      ],
    );
  }

  Widget buildCompareForm() {
    if (answerOptions.length < 2) {
      addAnswerOption();
    }
    return Column(
      children: [
        buildTextField("Enter First Image URL", (value) => answerOptions[0].imageUrl = value),
        buildTextField("Enter Second Image URL", (value) => answerOptions[1].imageUrl = value),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        onChanged: onChanged,
        decoration:
        InputDecoration(labelText: label, border: OutlineInputBorder()),
      ),
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
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;
    return Scaffold(
      appBar: NavBar(
        title: appBarTitle,
        isHindi: isHindi,
        onToggleLanguage: (value) {
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(value);
          _updateTranslations();
        },
        showMenuButton: true,
      ),
      drawer: CustomMenuBar(),
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
      'imageUrl': imageUrl.isNotEmpty ? imageUrl : null,
    };
  }
}

/// Updated AnswerOptionWidget as a stateful widget with image picker logic.
class AnswerOptionWidget extends StatefulWidget {
  final AnswerOption option;
  final VoidCallback onRemove;
  final Function(String)? onCorrectSelect;

  const AnswerOptionWidget({
    Key? key,
    required this.option,
    required this.onRemove,
    this.onCorrectSelect,
  }) : super(key: key);

  @override
  _AnswerOptionWidgetState createState() => _AnswerOptionWidgetState();
}

class _AnswerOptionWidgetState extends State<AnswerOptionWidget> {
  /// Helper function to choose an image and upload to Imgur.
  Future<void> _chooseAndUploadImage() async {
    const clientId = '72c6c45319d3658';
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedImage =
      await picker.pickImage(source: ImageSource.gallery);
      if (pickedImage == null) return;

      final fileBytes = await pickedImage.readAsBytes();
      final base64Image = base64Encode(fileBytes);

      final response = await http.post(
        Uri.parse('https://api.imgur.com/3/image'),
        headers: {'Authorization': 'Client-ID $clientId'},
        body: {'image': base64Image},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          widget.option.imageUrl = data['data']['link'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Option image uploaded successfully!")));
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      print('Error uploading option image: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Option image upload failed.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TextField(
              onChanged: (value) => widget.option.title = value,
              decoration: InputDecoration(labelText: "Title"),
            ),
            SizedBox(height: 8),
            TextField(
              onChanged: (value) => widget.option.description = value,
              decoration: InputDecoration(labelText: "Description"),
            ),
            SizedBox(height: 8),
            // Replace the image URL TextField with an image picker button and preview.
            ElevatedButton.icon(
              onPressed: _chooseAndUploadImage,
              icon: Icon(Icons.photo),
              label: Text(widget.option.imageUrl.isEmpty
                  ? "Choose Option Image"
                  : "Change Option Image"),
            ),
            if (widget.option.imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Image.network(
                  widget.option.imageUrl,
                  height: 100,
                ),
              ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(icon: Icon(Icons.delete), onPressed: widget.onRemove),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
