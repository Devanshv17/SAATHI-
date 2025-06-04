import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Saves a question in the corresponding Firestore collection.
  /// For "Compare", two number fields are stored as 'compareNumber1' and 'compareNumber2'
  /// and a default text is generated combining the two numbers.
  /// For "Let us Count", the number field is stored as 'numberField'.
  Future<void> saveQuestion({
    required String category,
    required String questionText,
    String? questionImageUrl,
    required List<Map<String, dynamic>> answerOptions,
    String? compareNumber1,
    String? compareNumber2,
    String? letUsCountNumber,
  }) async {
    if (category.isEmpty) {
      throw Exception("Category cannot be empty");
    }

    Map<String, dynamic> questionData = {
      'timestamp': FieldValue.serverTimestamp(),
      'options': answerOptions,
      'imageUrl': questionImageUrl,
    };

    if (category == "Compare" || category=="तुलना") {
      if (compareNumber1 == null ||
          compareNumber1.isEmpty ||
          compareNumber2 == null ||
          compareNumber2.isEmpty) {
        throw Exception("Both numbers are required for a Compare question.");
      }
      // Generate a default text using the compare numbers.
      questionData['text'] = "$compareNumber1 vs $compareNumber2";
      questionData['compareNumber1'] = compareNumber1;
      questionData['compareNumber2'] = compareNumber2;
    } else if (category == "Let us Count" || category=="चलो गिनें") {
      if (letUsCountNumber == null || letUsCountNumber.isEmpty) {
        throw Exception("Number field is required for Let us Count question.");
      }
      if (questionText.isEmpty) {
        throw Exception("Question text is required.");
      }
      questionData['text'] = questionText;
      questionData['numberField'] = letUsCountNumber;
    } else {
      if (questionText.isEmpty) {
        throw Exception("Question text cannot be empty");
      }
      questionData['text'] = questionText;
    }

    try {
      CollectionReference questionsCollection = _firestore.collection(category);
      await questionsCollection.add(questionData);
      print("Question saved successfully in collection: $category");
    } catch (e) {
      print("Error saving question: $e");
      throw Exception("Error saving question: $e");
    }
  }
}
