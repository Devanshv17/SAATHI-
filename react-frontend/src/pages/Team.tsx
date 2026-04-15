import React, { useState } from 'react';
import { NavBar } from '../components/NavBar';
import { Sidebar } from '../components/Sidebar';

export const Team: React.FC = () => {
  const [isHindi, setIsHindi] = useState(false);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);

  const teamMembers = [
    {
      name: 'Devansh Verma',
      role: 'Developer',
      bio: 'MTH UG ’22 • App dev & AI/ML enthusiast, turning ideas into code.',
      image: '/assets/Devansh.jpeg'
    },
    {
      name: 'Riya Sanket Kashive',
      role: 'Developer',
      bio: 'CEUG Y22, Chair at SIGCHI IITK and obsessive designer.',
      image: '/assets/Riya.jpg'
    },
    {
      name: 'Sumit Vishwakarma',
      role: 'Developer',
      bio: "EE IITK'27 | Exploring tech, creating impact.",
      image: '/assets/Sumit.jpeg'
    },
    {
      name: 'Prithviraj Ghosh',
      role: 'Developer',
      bio: 'Department of Mathematics and Statistics Secretary at ACM SIGCHI IIT Kanpur Student Chapter.',
      image: '/assets/Prithviraj.jpg'
    },
    {
      name: 'Sonali Kumari',
      role: 'Developer',
      bio: "Economics IITK'27",
      image: '/assets/Sonali.jpg'
    }
  ];

  return (
    <div className="min-h-screen bg-[#F5FFFF]">
      <NavBar isHindi={isHindi} onToggleLanguage={setIsHindi} showMenuButton onClickMenu={() => setIsSidebarOpen(true)} />
      <Sidebar isOpen={isSidebarOpen} onClose={() => setIsSidebarOpen(false)} isHindi={isHindi} />
      
      <main className="p-4 max-w-6xl mx-auto space-y-12 pb-20 pt-8">
        <div className="space-y-2">
           <h1 className="text-4xl font-bold text-[#6541EF]">{isHindi ? 'हमारी टीम' : 'Our Team'}</h1>
           <p className="text-lg text-gray-500 max-w-2xl">
             {isHindi 
               ? 'यह परियोजना कई समर्पित लोगों के सहयोग से संभव हुई है।'
               : 'This project has been made possible by a group of passionate contributors.'}
           </p>
        </div>

        {/* Supervisor Section */}
        <section className="space-y-6">
           <h2 className="text-2xl font-bold text-[#6541EF] flex items-center gap-2">
             <div className="h-6 w-2 bg-[#6541EF] rounded-full" />
             {isHindi ? 'परियोजना पर्यवेक्षक' : 'Project Supervisor'}
           </h2>
           <div className="bg-[#BFEBEF] rounded-[40px] p-8 shadow-xl flex flex-col md:flex-row items-center gap-8">
              <img 
                src="/assets/Anveshna.jpg" 
                alt="Dr. Anveshna Srivastava" 
                className="w-48 h-48 rounded-3xl object-cover shadow-lg border-4 border-white"
              />
              <div className="space-y-4 text-center md:text-left">
                <div>
                  <h3 className="text-2xl font-bold text-[#6541EF]">Dr. Anveshna Srivastava</h3>
                  <p className="text-cyan-800 font-bold uppercase tracking-wider text-sm">Assistant Professor, IIT Kanpur</p>
                </div>
                <p className="text-gray-700 leading-relaxed text-lg italic">
                  "Assistant Professor. Anveshna heads the Cognition, Learning and Innovation in Pedagogy (CLIP) lab in the Dept. of Cognitive Science at IIT Kanpur. She envisioned and supervised the Saathi project."
                </p>
              </div>
           </div>
        </section>

        {/* Core Team Section */}
        <section className="space-y-6">
           <h2 className="text-2xl font-bold text-[#6541EF] flex items-center gap-2">
             <div className="h-6 w-2 bg-[#6541EF] rounded-full" />
             {isHindi ? 'मुख्य टीम' : 'Core Team'}
           </h2>
           <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-8">
             {teamMembers.map((member, idx) => (
               <div key={idx} className="bg-white rounded-[40px] p-6 shadow-xl hover:scale-[1.02] transition-transform duration-300 flex flex-col items-center text-center space-y-4 border-b-8 border-[#BFEBEF]">
                 <div className="w-32 h-32 rounded-full overflow-hidden border-4 border-[#BFEBEF] shadow-inner mb-2">
                   <img src={member.image} alt={member.name} className="w-full h-full object-cover" />
                 </div>
                 <div>
                   <h4 className="text-xl font-bold text-gray-800">{member.name}</h4>
                   <p className="text-[#6541EF] font-bold text-sm uppercase tracking-wider">{member.role}</p>
                 </div>
                 <p className="text-gray-500 text-sm leading-relaxed">{member.bio}</p>
                 
               </div>
             ))}
           </div>
        </section>
      </main>
    </div>
  );
};
