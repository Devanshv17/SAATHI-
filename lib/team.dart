import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'navbar.dart';
import 'menu_bar.dart';
import 'language_notifier.dart';
import 'package:provider/provider.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LanguageNotifier>(context).isHindi;

     final List<TeamMember> teamMembers = [
      TeamMember(
        name: isHindi ? 'देवांश वर्मा' : 'Devansh Verma',
        role: isHindi ? 'डेवलपर' : 'Developer',
        bio: isHindi
            ? 'MTH UG ’22 • ऐप विकास और एआई/एमएल उत्साही, विचारों को कोड में बदलने वाले।'
            : 'MTH UG ’22 • App dev & AI/ML enthusiast, turning ideas into code.',
        image: 'assets/Devansh.jpeg',
      ),
      TeamMember(
        name: isHindi ? 'रिया संकेत काशीवे' : 'Riya Sanket Kashive',
        role: isHindi ? 'डेवलपर' : 'Developer',
        bio: isHindi
            ? 'CEUG Y22, आईआईटी कानपुर में SIGCHI की उपाध्यक्ष और UX/UI डिजाइनर'
            : 'CEUG Y22, Chair at SIGCHI IITK and obsessive designer',
        image: 'assets/Riya.jpg',
      ),
         TeamMember(
        name: isHindi ? 'सुमित विश्वकर्मा' : 'Sumit Vishwakarma',
        role: isHindi ? 'डेवलपर' : 'Developer',
        bio: isHindi
            ? "EE IITK'27 | तकनीक की खोज, प्रभाव की रचना।"
            : "EE IITK'27 | Exploring tech, creating impact.",
        image: 'assets/Sumit.jpeg',
      ),
      TeamMember(
        name: isHindi ? 'प्रित्वीराज घोष' : 'Prithviraj Ghosh',
        role: isHindi ? 'डेवलपर' : 'Developer',
        bio: isHindi
            ? 'गणित और सांख्यिकी विभाग सचिव, एसीएम SIGCHI आईआईटी कानपुर छात्र शाखा'
            : 'Department of Mathematics and Statistics Secretary at ACM SIGCHI IIT Kanpur Student Chapter',
        image: 'assets/Prithviraj.jpg',
      ),
   
         TeamMember(
        name: isHindi ? 'सोनाली कुमारी' : 'Sonali Kumari',
        role: isHindi ? 'डेवलपर' : 'Developer',
        bio: isHindi
            ? "अर्थशास्त्र, आईआईटी कानपुर '27"
            : "Economics IITK'27",
        image: 'assets/Sonali.jpg',
      ),
   
      // Add more members similarly
    ];

    return Scaffold(
      appBar: NavBar(
        isHindi: isHindi,
        onToggleLanguage: (_) {
          Provider.of<LanguageNotifier>(context, listen: false)
              .toggleLanguage(!isHindi);
        },
        showMenuButton: true,
      ),
      drawer: CustomMenuBar(isHindi: isHindi),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              isHindi ? 'हमारी टीम' : 'Our Team',
              style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              isHindi
                  ? 'यह परियोजना कई समर्पित लोगों के सहयोग से संभव हुई है।'
                  : 'This project has been made possible by a group of passionate contributors.',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[700]),
            ),

            const SizedBox(height: 32),

            // Project Supervisor Section
            Text(
              isHindi ? ' परियोजना पर्यवेक्षक' : ' Project Supervisor',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 16),
            _buildMemberCard(
              image: 'assets/Anveshna.jpg',
              name: isHindi ? 'डॉ. अन्वेषणा श्रीवास्तव' : 'Dr. Anveshna Srivastava',
              role:
                  isHindi ? 'प्रोफेसर, आईआईटी कानपुर' : 'Professor, IIT Kanpur',
              bio: isHindi
                  ? 'प्रो. श्रीवास्तव का ध्यान शिक्षा में समावेशिता और नवाचार पर केंद्रित है। उन्होंने साथी की संकल्पना और मार्गदर्शन प्रदान किया।'
                  : 'Prof. Srivastava is dedicated to inclusive and innovative education. She envisioned and supervised the SAATHI project.',
            ),

            const SizedBox(height: 32),

            // Core Team Section
            Text(
              isHindi ? ' मुख्य टीम' : ' Core Team',
              style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(height: 16),
           Wrap(
              spacing: 16,
              runSpacing: 16,
              children: teamMembers
                  .map((member) => _buildTeamTile(context, member))
                  .toList(),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard({
    required String image,
    required String name,
    required String role,
    required String bio,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 40, backgroundImage: AssetImage(image)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(role,
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: Colors.teal[700])),
                  const SizedBox(height: 8),
                  Text(bio,
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: Colors.grey[800])),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTeamTile(BuildContext context, TeamMember member) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 2 - 24,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage: AssetImage(member.image),
              ),
              const SizedBox(height: 8),
              Text(member.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              Text(member.role,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: Colors.teal[600])),
              const SizedBox(height: 4),
              Text(member.bio,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }
}

class TeamMember {
  final String name;
  final String role;
  final String image;
  final String bio;

  TeamMember(
      {required this.name,
      required this.role,
      required this.image,
      required this.bio});
}



