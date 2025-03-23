import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Saves a question in the corresponding Firestore collection.
  /// The correct answer tracking is stored within each option (via 'isCorrect').
  /// For "Compare", two number fields are stored as 'compareNumber1' and 'compareNumber2'.
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
    if (category.isEmpty || questionText.isEmpty) {
      throw Exception("Category and question text cannot be empty");
    }

    try {
      CollectionReference questionsCollection = _firestore.collection(category);

      Map<String, dynamic> questionData = {
        'text': questionText,
        'imageUrl': questionImageUrl ?? null,
        'options': answerOptions,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (category == "Compare") {
        questionData['compareNumber1'] = compareNumber1;
        questionData['compareNumber2'] = compareNumber2;
      } else if (category == "Let us Count") {
        questionData['numberField'] = letUsCountNumber;
      }

      await questionsCollection.add(questionData);
      print("Question saved successfully in collection: $category");
    } catch (e) {
      print("Error saving question: $e");
      throw Exception("Error saving question: $e");
    }
  }
}
