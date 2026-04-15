import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { rtdb } from '../firebase';
import { ref, remove, get, set as dbSet } from 'firebase/database';
import { NavBar } from '../components/NavBar';
import { Sidebar } from '../components/Sidebar';
import { Info, Target, Smartphone, UserCircle, Trash2, AlertTriangle } from 'lucide-react';

export const About: React.FC = () => {
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const [isHindi, setIsHindi] = useState(false);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [deleteConfirmText, setDeleteConfirmText] = useState('');
  const [isDeleting, setIsDeleting] = useState(false);

  const handleDeleteAccount = async () => {
    if (deleteConfirmText.toLowerCase() !== 'delete') return;
    setIsDeleting(true);
    try {
      const uid = user!.uid;
      const userRef = ref(rtdb, `users/${uid}`);
      const snap = await get(userRef);
      
      if (snap.exists()) {
        const userData = snap.val();
        const phone = userData.phone;
        
        // 1. Archive
        await dbSet(ref(rtdb, `deleted_uids/${uid}`), {
          phone,
          archivedAt: new Date().toISOString(),
          data: userData
        });
        
        // 2. Remove mappings
        if (phone) {
          await remove(ref(rtdb, `phone_to_uid/${encodeURIComponent(phone)}`));
        }
        
        // 3. Remove user
        await remove(userRef);
      }
      
      // 4. Logout (Actual Auth user deletion usually requires re-auth, keeping it simple with data removal)
      await logout();
      navigate('/login');
    } catch (error) {
      console.error(error);
    } finally {
      setIsDeleting(false);
    }
  };

  const sections = [
    {
      title: isHindi ? 'साथी के बारे में' : 'About Saathi',
      icon: <Info className="text-blue-500" />,
      content: isHindi 
        ? 'साथी एक मोबाइल ऐप है जो पूर्व-प्राथमिक बच्चों के लिए शिक्षा को सुलभ, आकर्षक और समावेशी बनाने हेतु डिज़ाइन किया गया है। यह ऐप मज़ेदान खेलों और इंटरएक्टिव गतिविधियों के माध्यम से बुनियादी साक्षरता, गणित और सामान्य ज्ञान सिखाने में मदद करता है।'
        : 'SAATHI is a gamified learning platform designed to make foundational education accessible, engaging, and inclusive for pre-primary children. It helps teach basic literacy, numeracy, and general awareness through fun games.'
    },
    {
       title: isHindi ? 'हमारा उद्देश्य' : 'Our Objective',
       icon: <Target className="text-red-500" />,
       content: isHindi
         ? 'उन बच्चों को सशक्त बनाना जिनके पास पारंपरिक शिक्षा तक पहुंच नहीं है, एक मजेदार और नि:शुल्क लर्निंग प्लेटफॉर्म के माध्यम से।'
         : 'To empower children with limited access to formal education by offering a free, fun, and interactive learning experience through a mobile-first approach.'
    },
    {
      title: isHindi ? 'साथी को खास क्या बनाता है?' : 'What Makes SAATHI Unique?',
      icon: <Smartphone className="text-green-500" />,
      features: [
        { 
          label: isHindi ? 'गेम-आधारित लर्निंग' : 'Game-Based Learning', 
          desc: isHindi ? 'पाठों को छोटे, मजेदार खेलों में बदलना।' : 'Transforms lessons into playful, bite-sized games.' 
        },
        { 
          label: isHindi ? 'बुनियादी पाठ्यक्रम' : 'Foundational Curriculum', 
          desc: isHindi ? 'बुनियादी पढ़ना और गिनती पर ध्यान।' : 'Focuses on basic literacy and numeracy.' 
        },
        { 
          label: isHindi ? 'द्विभाषी सामग्री' : 'Bilingual Content', 
          desc: isHindi ? 'हिंदी और अंग्रेज़ी दोनों में उपलब्ध।' : 'Available in both Hindi and English.' 
        }
      ]
    },
    {
      title: isHindi ? 'प्रोफ़ाइल और खाता' : 'Profile and Account',
      icon: <UserCircle className="text-purple-500" />,
      content: isHindi
        ? 'आपकी प्रोफ़ाइल जानकारी आपकी सीखने की यात्रा को वैयक्तिक बनाने में मदद करती है। यह जानकारी केवल आपके डिवाइस पर सीमित रहती है।'
        : 'Your profile info helps personalize your learning journey. This information remains strictly on your device and is not shared externally.'
    }
  ];

  return (
    <div className="min-h-screen bg-[#F5FFFF]">
      <NavBar isHindi={isHindi} onToggleLanguage={setIsHindi} showMenuButton onClickMenu={() => setIsSidebarOpen(true)} />
      <Sidebar isOpen={isSidebarOpen} onClose={() => setIsSidebarOpen(false)} isHindi={isHindi} />
      
      <main className="p-4 max-w-4xl mx-auto space-y-8 pb-20 pt-8">
        <div className="flex flex-col items-center mb-8">
           <img src="/assets/logo.png" alt="Saathi Logo" className="h-32 mb-4" />
           <div className="h-2 w-24 bg-[#6541EF] rounded-full" />
        </div>

        <div className="space-y-6">
          {sections.map((sec, idx) => (
            <div key={idx} className="bg-white rounded-[32px] p-8 shadow-xl border-l-8 border-[#6541EF]">
              <div className="flex items-center gap-3 mb-4">
                {sec.icon}
                <h2 className="text-2xl font-bold text-[#6541EF]">{sec.title}</h2>
              </div>
              
              {sec.content && (
                <p className="text-gray-600 leading-relaxed text-lg">{sec.content}</p>
              )}
              
              {sec.features && (
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mt-4">
                  {sec.features.map((f, i) => (
                    <div key={i} className="p-4 bg-[#F5FFFF] rounded-2xl">
                      <h4 className="font-bold text-[#6541EF] mb-1">{f.label}</h4>
                      <p className="text-sm text-gray-500">{f.desc}</p>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ))}
        </div>

        {/* Account Deletion */}
        <div className="pt-12 text-center">
           <button 
             onClick={() => setShowDeleteModal(true)}
             className="text-red-500 font-bold flex items-center gap-2 mx-auto hover:bg-red-50 p-3 rounded-xl transition-colors"
           >
             <Trash2 size={20} />
             {isHindi ? 'मेरा खाता हटाएं' : 'Delete My Account'}
           </button>
        </div>
      </main>

      {/* Delete Modal */}
      {showDeleteModal && (
        <div className="fixed inset-0 bg-black/50 z-[150] flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl p-8 max-w-md w-full shadow-2xl text-center space-y-6">
            <div className="w-16 h-16 bg-red-100 text-red-600 rounded-full flex items-center justify-center mx-auto">
              <AlertTriangle size={32} />
            </div>
            
            <div className="space-y-2">
              <h2 className="text-2xl font-bold text-gray-800">
                {isHindi ? 'खाता हटाना चाहते हैं?' : 'Delete Account?'}
              </h2>
              <p className="text-gray-500">
                {isHindi 
                  ? 'यह क्रिया स्थायी है। जारी रखने के लिए नीचे "delete" लिखें।'
                  : 'This action is permanent and cannot be undone. Type "delete" to confirm.'}
              </p>
            </div>
            
            <input 
              type="text"
              value={deleteConfirmText}
              onChange={e => setDeleteConfirmText(e.target.value)}
              placeholder="delete"
              className="w-full px-4 py-3 rounded-xl border-2 border-red-100 focus:border-red-500 outline-none text-center font-mono"
            />
            
            <div className="flex gap-4">
              <button 
                onClick={() => setShowDeleteModal(false)}
                className="flex-1 py-4 bg-gray-100 text-gray-600 rounded-2xl font-bold hover:bg-gray-200"
              >
                {isHindi ? 'रद्द करें' : 'Cancel'}
              </button>
              <button 
                onClick={handleDeleteAccount}
                disabled={deleteConfirmText.toLowerCase() !== 'delete' || isDeleting}
                className="flex-1 py-4 bg-red-500 text-white rounded-2xl font-bold shadow-lg disabled:opacity-50 active:scale-95 transition-all"
              >
                {isDeleting ? '...' : (isHindi ? 'हटाएं' : 'Delete')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
