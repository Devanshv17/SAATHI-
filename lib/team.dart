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
        name:  'Devansh Verma',
        role: 'Developer',
        bio:  'MTH UG ’22 • App dev & AI/ML enthusiast, turning ideas into code.',
        image: 'assets/Devansh.jpeg',
      ),
      TeamMember(
        name: 'Riya Sanket Kashive',
        role: 'Developer',
        bio:  'CEUG Y22, Chair at SIGCHI IITK and obsessive designer',
        image: 'assets/Riya.jpg',
      ),
         TeamMember(
        name:'Sumit Vishwakarma',
        role: 'Developer',
        bio: "EE IITK'27 | Exploring tech, creating impact.",
        image: 'assets/Sumit.jpeg',
      ),
      TeamMember(
        name:  'Prithviraj Ghosh',
        role: 'Developer',
        bio:'Department of Mathematics and Statistics Secretary at ACM SIGCHI IIT Kanpur Student Chapter',
        image: 'assets/Prithviraj.jpg',
      ),
   
         TeamMember(
        name:  'Sonali Kumari',
        role:  'Developer',
        bio:  "Economics IITK'27",
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
      backgroundColor: Color.fromARGB(255, 245, 255, 255),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              isHindi ? 'हमारी टीम' : 'Our Team',
              style: GoogleFonts.trocchi(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 101, 65, 239)),
            ),
            const SizedBox(height: 8),
            Text(
              isHindi
                  ? 'यह परियोजना कई समर्पित लोगों के सहयोग से संभव हुई है।'
                  : 'This project has been made possible by a group of passionate contributors.',
              style: GoogleFonts.trocchi(fontSize: 16, color: Colors.grey[700]),
            ),

            const SizedBox(height: 32),

            // Project Supervisor Section
            Text(
              isHindi ? ' परियोजना पर्यवेक्षक' : ' Project Supervisor',
              style: GoogleFonts.trocchi(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 101, 65, 239)),
            ),
            const SizedBox(height: 16),
            _buildMemberCard(
              image: 'assets/Anveshna.jpg',
              name: 'Dr. Anveshna Srivastava',
              role:
                  'Assistant Professor, IIT Kanpur',
              bio:
                  'Assistant Professor. Anveshna heads the Cognition, Learning and Innovation in Pedagogy (CLIP) lab in the Dept. of Cognitive Science at IIT Kanpur. She envisioned and supervised the Saathi project.',
            ),

            const SizedBox(height: 32),

            // Core Team Section
            Text(
              isHindi ? ' मुख्य टीम' : ' Core Team',
              style: GoogleFonts.trocchi(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 101, 65, 239)),
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
      color: Color.fromARGB(255, 191, 235, 239),
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
                      style: GoogleFonts.trocchi(
                          fontWeight: FontWeight.bold, fontSize: 18, color: Color.fromARGB(255, 101, 65, 239))),
                  Text(role,
                      style: GoogleFonts.trocchi(
                          fontSize: 14, color: Colors.cyan[800])),
                  const SizedBox(height: 8),
                  Text(bio,
                      style: GoogleFonts.trocchi(
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
        color:  Color.fromARGB(255, 191, 235, 239),
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
                  style: GoogleFonts.trocchi(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              Text(member.role,
                  style: GoogleFonts.trocchi(
                      fontSize: 13, color: Colors.cyan[800])),
              const SizedBox(height: 4),
              Text(member.bio,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.trocchi(
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



