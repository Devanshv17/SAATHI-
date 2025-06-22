import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'language_notifier.dart';
import 'navbar.dart';
import 'menu_bar.dart';

class AboutSaathiPage extends StatefulWidget {
  const AboutSaathiPage({Key? key}) : super(key: key);

  @override
  _AboutSaathiPageState createState() => _AboutSaathiPageState();
}

class _AboutSaathiPageState extends State<AboutSaathiPage> {
  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;

    return Scaffold(
      appBar: NavBar(
        isHindi: isHindi,
        onToggleLanguage: (value) {
          // update the notifier
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(value);
          // then rebuild this page
          setState(() {});
        },
        showMenuButton: true,
      ),
      drawer: CustomMenuBar(isHindi: isHindi),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Image.asset('logo.png', height: 150),
             const SizedBox(height: 15),
            // Welcome text
            Text(
              isHindi ? '' : 'About Saathi',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              isHindi
                  ? 'SAATHI एक मोबाइल ऐप है जो उपयोगकर्ताओं को ...'
                  : 'SAATHI is a mobile application designed to help users ...',
              style: GoogleFonts.poppins(fontSize: 16, height: 1.5),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 16),
            Text(
              isHindi ? 'हमारा मिशन है ...' : 'Our mission is to ...',
              style: GoogleFonts.poppins(fontSize: 16, height: 1.5),
              textAlign: TextAlign.justify,
            ),
            // Add more about sections as needed
          ],
        ),
      ),
    );
  }
}
