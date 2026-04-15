// lib/about_saathi.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'language_notifier.dart';
import 'navbar.dart';
import 'menu_bar.dart';
import 'utils/responsive.dart';

class AboutSaathiPage extends StatefulWidget {
  const AboutSaathiPage({Key? key}) : super(key: key);

  @override
  _AboutSaathiPageState createState() => _AboutSaathiPageState();
}

class _AboutSaathiPageState extends State<AboutSaathiPage> {
  final _dbRef = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;
  bool _deleting = false;

  String get _uid => _auth.currentUser!.uid;
  String? _phone; // we'll fetch this on init

  @override
  void initState() {
    super.initState();
    _loadPhone();
  }

  Future<void> _loadPhone() async {
    final snap = await _dbRef.child('users/$_uid/phone').get();
    if (snap.exists) setState(() => _phone = snap.value as String);
  }

Future<void> _performDeleteAccount() async {
    setState(() => _deleting = true);

    final user = _auth.currentUser;
    final uid = user?.uid;
    final phone = _phone;

    if (uid != null && phone != null) {
      final key = Uri.encodeComponent(phone);

      // 1. Copy user data to `deleted_uids/{uid}`
      final userDataSnap = await _dbRef.child('users/$uid').get();
      if (userDataSnap.exists) {
        final userData = userDataSnap.value;
        await _dbRef.child('deleted_uids/$uid').set({
          'phone': phone,
          'archivedAt': DateTime.now().toIso8601String(),
          'data': userData,
        });
      }

      // 2. Remove from `phone_to_uid`
      await _dbRef.child('phone_to_uid/$key').remove();

      // 3. Remove user data from `users/`
      await _dbRef.child('users/$uid').remove();
    }

    // 4. Delete Auth user
    try {
      if (user != null) await user.delete();
    } catch (_) {
      // Likely needs re-authentication
    }

    // 5. Sign out
    await _auth.signOut();

    // 6. Clear local prefs
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('loggedIn', false);

    // 7. Navigate to login
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }


  Future<void> _showDeleteDialog() {
    final isHindi =
        Provider.of<LanguageNotifier>(context, listen: false).isHindi;
    final controller = TextEditingController();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.warning, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              Text(
                isHindi
                    ? 'क्या आप खाता हटाना चाहते हैं?'
                    : 'Are you sure you want to delete your account?',
                style: GoogleFonts.trocchi(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color.fromARGB(255, 101, 65, 239)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                isHindi
                    ? 'यह क्रिया स्थायी है। जारी रखने के लिए नीचे "delete" लिखें।'
                    : 'This action is permanent. Type "delete" below to confirm.',
                style: GoogleFonts.trocchi(
                    fontSize: 16, color: Color.fromARGB(255, 101, 65, 239), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'delete',
                  hintStyle: GoogleFonts.trocchi(color: Colors.grey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
                style: GoogleFonts.trocchi(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(
                        isHindi ? 'रद्द करें' : 'Cancel',
                        style: GoogleFonts.trocchi(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color.fromARGB(255, 101, 65, 239)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (_, val, __) {
                        final isMatch =
                            val.text.trim().toLowerCase() == 'delete';
                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: isMatch
                                ? Colors.redAccent
                                : Colors.redAccent.withOpacity(0.6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 4,
                          ),
                          onPressed: isMatch
                              ? () {
                                  Navigator.of(ctx).pop();
                                  _performDeleteAccount();
                                }
                              : null,
                          child: Text(
                            isHindi ? 'हटाएं' : 'Delete',
                            style: GoogleFonts.trocchi(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;

    return Scaffold(
      backgroundColor: Color.fromARGB(255, 245, 255, 255),
      appBar: NavBar(
        isHindi: isHindi,
        onToggleLanguage: (_) {
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(!isHindi);
          setState(() {});
        },
        showMenuButton: true,
      ),
      drawer: CustomMenuBar(isHindi: isHindi),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Responsive.maxContentWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
            child: Column(
          children: [
            Image.asset('assets/logo.png', height: 150),
            const SizedBox(height: 15),
           
           RichText(
              textAlign: TextAlign.justify,
              text: TextSpan(
                style: GoogleFonts.trocchi(
                    fontSize: 16, color: Colors.black, height: 1.5),
                children: [
                  TextSpan(
                    text:
                        isHindi ? 'साथी के बारे में\n' : 'About Saathi\n',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(

                    text: isHindi
                        ? 'साथी एक मोबाइल ऐप है जो पूर्व-प्राथमिक बच्चों के लिए शिक्षा को सुलभ, आकर्षक और समावेशी बनाने हेतु डिज़ाइन किया गया है। यह ऐप मज़ेदार खेलों और इंटरएक्टिव गतिविधियों के माध्यम से बुनियादी साक्षरता, गणित और सामान्य ज्ञान सिखाने में मदद करता है। साथी का उद्देश्य तकनीक और रचनात्मक शिक्षण विधियों के माध्यम से शिक्षा की खाई को पाटना है।\n\n'
                        : 'SAATHI is a gamified mobile learning platform designed to make foundational education accessible, engaging, and inclusive for pre-primary childrens. Developed with a deep understanding of the challenges faced by pre-primary kids, SAATHI aims to bridge the educational divide using technology and creative pedagogy.\n\n',

                  ),
                  TextSpan(
                    text:
                        isHindi ? '🎯 हमारा उद्देश्य\n' : '🎯 Our Objective\n',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'उन बच्चों को सशक्त बनाना जिनके पास पारंपरिक शिक्षा तक पहुंच नहीं है, एक मजेदार, मोबाइल-आधारित, और नि:शुल्क लर्निंग प्लेटफॉर्म के माध्यम से। ऐप स्थानीय भाषाओं, विज़ुअल स्टोरीटेलिंग और गेम-आधारित गतिविधियों के माध्यम से पढ़ाई को सरल बनाता है।\n\n'
                        : 'To empower children with limited access to formal education by offering a free, fun, and interactive learning experience through a mobile-first approach. SAATHI simplifies essential subjects and concepts using local languages, visual storytelling, and game-based activities.\n\n',
                  ),
                  TextSpan(
                    text: isHindi
                        ? '📱 साथी को खास क्या बनाता है?\n\n'
                        : '📱 What Makes SAATHI Unique?\n\n',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 101, 65, 239)),
                  
                  ),
                  TextSpan(
                    text: isHindi
                        ? '🎮 गेम-आधारित लर्निंग:\n'
                        : '🎮 Game-Based Learning:\n',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'साथी पाठों को छोटे, मजेदार खेलों में बदल देता है जो बच्चों का ध्यान बनाए रखते हैं और सीखने को आनंदमय बनाते हैं। इसमें ड्रैग एंड ड्रॉप, अक्षर मिलान और पैटर्न पहचान जैसे गेम शामिल हैं।\n\n'
                        : 'SAATHI transforms lessons into playful, bite-sized games that hold children’s attention and make learning enjoyable. From drag-and-drop activities to letter matching and pattern recognition games, it ensures every interaction reinforces a concept.\n\n',
                  ),
                  TextSpan(
                    text: isHindi
                        ? '📚 बुनियादी पाठ्यक्रम:\n'
                        : '📚 Foundational Curriculum:\n',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'ऐप बुनियादी पढ़ना, गिनती और सामान्य ज्ञान जैसे विषयों पर केंद्रित है, खासकर उन बच्चों के लिए जो पहली बार डिजिटल शिक्षा से जुड़ रहे हैं।\n\n'
                        : 'The app focuses on basic literacy, numeracy, and general awareness, serving as a stepping stone for children new to digital education or school systems.\n\n',
                  ),
                  TextSpan(
                    text: isHindi
                        ? '🧒 बच्चों के अनुकूल इंटरफ़ेस:\n'
                        : '🧒 Kid-Friendly Interface:\n',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'साथी को इस तरह डिज़ाइन किया गया है कि छोटे बच्चे बिना किसी मदद के इसे आसानी से उपयोग कर सकें। इंटरफ़ेस सरल, बड़ा और आकर्षक है।\n\n'
                        : 'Designed especially for first-time digital users, SAATHI features a simple and intuitive UI, making it easy for young children to navigate without adult supervision.\n\n',
                  ),
                  TextSpan(
                    text: isHindi
                        ? '🌐 द्विभाषी सामग्री (हिंदी और अंग्रेज़ी):\n'
                        : '🌐 Bilingual Content (Hindi & English):\n',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'सभी गेम और निर्देश हिंदी और अंग्रेज़ी दोनों में उपलब्ध हैं, जिससे बच्चे अपनी पसंद की भाषा में सीख सकते हैं और धीरे-धीरे द्विभाषी क्षमता भी विकसित कर सकते हैं।\n\n'
                        : 'All games and instructions are available in both Hindi and English, allowing children to learn in their preferred language and gradually build bilingual proficiency.\n\n',
                  ),




                     TextSpan(
                    text: isHindi
                        ? '🎮 साथी में खेल\n\n'
                        : '🎮 Games in SAATHI\n\n',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18, color: Color.fromARGB(255, 101, 65, 239)),
                  ),

                  // 1. Name Picture Matching
                  TextSpan(
                    text: isHindi
                        ? '🖼️ नाम चित्र मिलान: '
                        : '🖼️ Name Picture Matching: ',
                    style: const TextStyle(fontWeight: FontWeight.bold,color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'इस खेल में बच्चों को किसी वस्तु का नाम पढ़कर उससे संबंधित सही चित्र को पहचानना होता है। यह शब्दावली और दृश्य पहचान को बढ़ावा देता है।\n\n'
                        : 'Children are asked to match a word with its corresponding picture. This enhances vocabulary and improves visual recognition.\n\n',
                  ),

                  // 2. Guess the Letter
                  TextSpan(
                    text:
                        isHindi ? '🔠 अक्षर ज्ञान: ' : '🔠 Guess the Letter: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'बच्चों को एक तस्वीर दिखाई जाती है, और उन्हें उस शब्द का पहला अक्षर बताना होता है जिसे वह तस्वीर दर्शाती है। यह वर्णमाला की समझ और ध्यान केंद्रित करने की क्षमता को बढ़ाता है।\n\n'
                        : 'Children are shown a picture, and they have to guess the first letter of the word it represents. This sharpens alphabet recognition and focus.\n\n',
                  ),

                  // 3. Compare
                  TextSpan(
                    text: isHindi ? '📏 तुलना: ' : '📏 Compare: ',
                    style: const TextStyle(fontWeight: FontWeight.bold,color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'इसमें बच्चे दो वस्तुओं की मात्रा की तुलना करते हैं। यह विश्लेषणात्मक और तर्क कौशल को विकसित करता है।\n\n'
                        : 'Children compare the quantity of objects. This helps develop analytical and logical thinking.\n\n',
                  ),

                  // 4. Let Us Count
                  TextSpan(
                    text: isHindi ? '🔢 चलो गिनें: ' : '🔢 Let Us Count: ',
                    style: const TextStyle(fontWeight: FontWeight.bold,color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'बच्चे चित्रों में मौजूद वस्तुओं को गिनकर सही संख्या चुनते हैं। यह प्रारंभिक गणितीय कौशल को मजबूत करता है।\n\n'
                        : 'Children count items shown in pictures and select the correct number. This strengthens early math skills.\n\n',
                  ),

                  // 5. Number Name Matching
                  TextSpan(
                    text: isHindi
                        ? '🔤 संख्या नाम मिलान: '
                        : '🔤 Number Name Matching: ',
                    style: const TextStyle(fontWeight: FontWeight.bold,color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'इस खेल में बच्चों को अंकों (जैसे ४) को उनके नामों (जैसे चार) से मिलाना होता है। इससे संख्या और शब्दों की समझ बढ़ती है।\n\n'
                        : 'Children match numeric digits (like 4) with their names (like four). This improves number-to-word association.\n\n',
                  ),

                  // 6. Name Number Matching
                  TextSpan(
                    text: isHindi
                        ? '🧮 नाम संख्या मिलान: '
                        : '🧮 Name Number Matching: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'इस गतिविधि में संख्या नाम को उनके अंकों से जोड़ा जाता है, जिससे गणना की मूलभूत समझ विकसित होती है।\n\n'
                        : 'In this activity, number names are matched with their digits, reinforcing basic numerical understanding.\n\n',
                  ),

                  // 7. Let Us Tell Time
                  TextSpan(
                    text:
                        isHindi ? '⏰ चलो समय बताएँ: ' : '⏰ Let Us Tell Time: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'बच्चों को घड़ी में समय देखकर सही उत्तर चुनना होता है। यह समय की अवधारणा और दैनिक जीवन की तैयारी में मदद करता है।\n\n'
                        : 'Children look at a clock and choose the correct time. It helps build time awareness and real-life readiness.\n\n',
                  ),

                  // 8. Alphabet Knowledge
                  TextSpan(
                    text: isHindi
                        ? '🔡 वर्णमाला ज्ञान: '
                        : '🔡 Alphabet Knowledge: ',
                    style: const TextStyle(fontWeight: FontWeight.bold,color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'यह खेल बच्चों को सभी अक्षरों को पहचानने और उन्हें क्रम में समझने में मदद करता है।\n\n'
                        : 'This game helps children identify and understand the sequence of all letters in the alphabet.\n\n',
                  ),

                  // 9. Left Middle Right
                  TextSpan(
                    text: isHindi
                        ? '🧭 बाएँ दाएँ मध्य: '
                        : '🧭 Left Middle Right: ',
                    style: const TextStyle(fontWeight: FontWeight.bold,color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'बच्चे विभिन्न वस्तुओं की स्थिति (बाएँ, दाएँ, मध्य) को पहचानते हैं। यह स्थानिक समझ को बढ़ाता है।\n\n'
                        : 'Children identify the position of objects (left, right, middle), enhancing spatial awareness.\n\n',
                  ),

                  // 10. Shape Knowledge
                  TextSpan(
                    text: isHindi ? '🔷 आकार ज्ञान: ' : '🔷 Shape Knowledge: ',
                    style: const TextStyle(fontWeight: FontWeight.bold,color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'बच्चों को विभिन्न ज्यामितीय आकृतियों को पहचानने और उनके नाम जानने का अभ्यास कराया जाता है।\n\n'
                        : 'Children practice recognizing various geometric shapes and learning their names.\n\n',
                  ),




                  TextSpan(
                    text:
                       isHindi ? '🙍‍♂️ आपके खाते के बारे में\n\n' : '🙍‍♂️ About Your Account\n\n',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18,color: Color.fromARGB(255, 101, 65, 239)),
                  ),

                  // 1. Name Picture Matching
                  TextSpan(
                    text: isHindi
                        ? '🧾 व्यक्तिगत विवरण: '
                        : '🧾 Personal Details: ',
                    style: const TextStyle(fontWeight: FontWeight.bold,color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                     text: isHindi
                        ? "साथी ऐप में, आपकी प्रोफ़ाइल में आपका नाम, उम्र, लिंग और आपकी कक्षा की जानकारी प्रदर्शित होती है। यह जानकारी आपकी सीखने की यात्रा को वैयक्तिक बनाने में मदद करती है और ऐप आपके लिए उपयुक्त खेलों व सामग्री को दिखा पाता है। यह जानकारी केवल आपके डिवाइस पर सीमित रहती है और किसी भी बाहरी उपयोग के लिए साझा नहीं की जाती।\n\n"
                         : "In the SAATHI app, your profile displays your name, age, gender, and educational standard. This helps personalize your learning journey and allows the app to show content and games suitable for your level.All information remains strictly on your device and is not shared externally in any form.\n\n",
                  ),



                   TextSpan(
                    text: isHindi
                        ? '🗑️ खाता हटाना: '
                        : '🗑️ Deleting Your Account: ',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color.fromARGB(255, 101, 65, 239)),
                  ),
                  TextSpan(
                    text: isHindi
                        ? 'यदि आप अपना खाता हटाना चाहते हैं, तो नीचे दिए गए बटन का उपयोग कर सकते हैं। यह आपकी प्रोफ़ाइल जानकारी और लॉगिन पहचान दोनों को स्थायी रूप से हटा देगा। यह प्रक्रिया अपरिवर्तनीय है, इसलिए कृपया सावधानीपूर्वक निर्णय लें।'
                        : 'If you wish to delete your account, you can use the button below. This will permanently delete both your profile data and authentication credentials. This action is irreversible, so please proceed with caution.',
                  ),
                ],
              ),
              
            ),

            // Subtle red TextButton version of Delete
            Center(
              child: TextButton.icon(
                icon: _deleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.red,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.delete, color: Colors.red),
                label: Text(
                  isHindi ? 'मेरा खाता हटाएं' : 'Delete My Account',
                  style: GoogleFonts.trocchi(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                  ),
                ),
                onPressed: _deleting ? null : _showDeleteDialog,
              ),
            ),
        
            const SizedBox(height: 50),
      
          ],
        ),
      ),
        ),
      ),
    );
  }
}
