import React, { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { rtdb } from '../firebase';
import { ref, get, update } from 'firebase/database';
import { NavBar } from '../components/NavBar';
import { Sidebar } from '../components/Sidebar';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, PieChart, Pie, Cell } from 'recharts';
import CalendarHeatmap from 'react-calendar-heatmap';
import 'react-calendar-heatmap/dist/styles.css';
import { User, Calendar, Transgender, School, BookOpen, Edit2, TrendingUp, Award, Zap, Flame, Trophy, X } from 'lucide-react';

export const Profile: React.FC = () => {
  const { user } = useAuth();
  const [isHindi, setIsHindi] = useState(false);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [profileData, setProfileData] = useState<any>({});
  
  // Stats
  const [todayPoints, setTodayPoints] = useState(0);
  const [totalPoints, setTotalPoints] = useState(0);
  const [streakCount, setStreakCount] = useState(0);
  const [weeklyData, setWeeklyData] = useState<any[]>([]);
  const [totalAccuracy, setTotalAccuracy] = useState({ correct: 0, incorrect: 0 });
  const [gameAccuracies, setGameAccuracies] = useState<any[]>([]);
  const [monthlyStats, setMonthlyStats] = useState<any[]>([]);
  
  // Edit Profile
  const [isEditing, setIsEditing] = useState(false);
  const [editFormData, setEditFormData] = useState({
    name: '',
    age: '',
    gender: '',
    class: '',
    school: false
  });

  useEffect(() => {
    if (user) {
      loadProfileData();
    }
  }, [user]);

  const loadProfileData = async () => {
    setIsLoading(true);
    try {
      const userRef = ref(rtdb, `users/${user!.uid}`);
      const snap = await get(userRef);
      if (snap.exists()) {
        const data = snap.val();
        setProfileData(data);
        setTotalPoints(data.score || 0);
        setStreakCount(data.streak?.count || 0);
        
        // Today's activity
        const today = new Date().toISOString().split('T')[0];
        if (data.today_activity?.date === today) {
          setTodayPoints(data.today_activity.correct || 0);
        }

        // Weekly progress
        const scores = calculateWeeklyScores(data.monthlyStats || {});
        setWeeklyData(scores);

        // Monthly Heatmap
        const heatmap = Object.entries(data.monthlyStats || {}).map(([date, stats]: any) => ({
          date,
          count: stats.correct || 0
        }));
        setMonthlyStats(heatmap);

        // Accuracy Data
        let totalCorrect = 0;
        let totalIncorrect = 0;
        const gameAccs: any[] = [];

        if (data.games) {
          Object.entries(data.games).forEach(([gameName, gameData]: any) => {
            const main = gameData.main_game;
            if (main) {
              const c = main.correctCount || 0;
              const i = main.incorrectCount || 0;
              totalCorrect += c;
              totalIncorrect += i;
              if (c + i > 0) {
                gameAccs.push({
                  name: gameName,
                  accuracy: Math.round((c / (c + i)) * 100)
                });
              }
            }
          });
        }
        setTotalAccuracy({ correct: totalCorrect, incorrect: totalIncorrect });
        setGameAccuracies(gameAccs);
        
        setEditFormData({
          name: data.name || '',
          age: data.age?.toString() || '',
          gender: data.gender || '',
          class: data.class || '',
          school: data.school || false
        });
      }
    } catch (error) {
      console.error(error);
    } finally {
      setIsLoading(false);
    }
  };

  const calculateWeeklyScores = (monthlyStats: any) => {
    const now = new Date();
    const dayOfWeek = now.getDay(); // 0 is Sunday
    const startOfWeek = new Date(now);
    startOfWeek.setDate(now.getDate() - dayOfWeek);
    
    const weekLabels = isHindi ? ['रवि', 'सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि'] : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const data = [];

    for (let i = 0; i < 7; i++) {
      const d = new Date(startOfWeek);
      d.setDate(startOfWeek.getDate() + i);
      const key = d.toISOString().split('T')[0];
      data.push({
        day: weekLabels[i],
        points: monthlyStats[key]?.correct || 0
      });
    }
    return data;
  };

  const handleUpdateProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      await update(ref(rtdb, `users/${user!.uid}`), {
        name: editFormData.name,
        age: parseInt(editFormData.age),
        gender: editFormData.gender,
        class: editFormData.class,
        school: editFormData.school
      });
      setIsEditing(false);
      loadProfileData();
    } catch (error) {
      console.error(error);
    }
  };

  if (isLoading) return <div className="min-h-screen bg-[#F5FFFF] flex items-center justify-center font-bold text-[#6541EF]">LOADING...</div>;

  const totalPossible = totalAccuracy.correct + totalAccuracy.incorrect;
  const overallAccuracy = totalPossible > 0 ? Math.round((totalAccuracy.correct / totalPossible) * 100) : 0;
  
  const pieData = [
    { name: 'Correct', value: totalAccuracy.correct, color: '#22C55E' },
    { name: 'Incorrect', value: totalAccuracy.incorrect, color: '#EF4444' }
  ];

  return (
    <div className="min-h-screen bg-[#F5FFFF]">
      <NavBar isHindi={isHindi} onToggleLanguage={setIsHindi} showMenuButton onClickMenu={() => setIsSidebarOpen(true)} />
      <Sidebar isOpen={isSidebarOpen} onClose={() => setIsSidebarOpen(false)} isHindi={isHindi} />
      
      <main className="p-4 max-w-5xl mx-auto space-y-8 pb-20">
        <div className="flex flex-col items-center">
           <div className="w-32 h-32 bg-white rounded-full flex items-center justify-center shadow-lg border-4 border-[#6541EF] overflow-hidden">
             <img src="/assets/logo.png" alt="Profile" className="w-24 h-24 object-contain" />
           </div>
           <h1 className="mt-4 text-3xl font-bold text-[#6541EF]">{profileData.name || (isHindi ? 'अनाम' : 'Anonymous')}</h1>
        </div>

        {/* Info Card */}
        <div className="bg-[#BFEBEF] rounded-3xl p-8 shadow-lg space-y-4">
          <div className="flex justify-between items-center">
            <h2 className="text-2xl font-bold text-[#6541EF]">{isHindi ? 'व्यक्तिगत जानकारी' : 'Personal Information'}</h2>
            <button onClick={() => setIsEditing(true)} className="p-2 bg-white rounded-full text-[#6541EF] hover:bg-gray-100 shadow">
              <Edit2 size={20} />
            </button>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <InfoRow icon={<User size={20} />} label={isHindi ? 'नाम' : 'Name'} value={profileData.name} />
            <InfoRow icon={<Calendar size={20} />} label={isHindi ? 'आयु' : 'Age'} value={profileData.age} />
            <InfoRow icon={<Transgender size={20} />} label={isHindi ? 'लिंग' : 'Gender'} value={profileData.gender} />
            <InfoRow icon={<School size={20} />} label={isHindi ? 'स्कूल' : 'School'} value={profileData.school ? (isHindi ? 'हाँ' : 'Yes') : (isHindi ? 'नहीं' : 'No')} />
            <InfoRow icon={<BookOpen size={20} />} label={isHindi ? 'कक्षा' : 'Class'} value={profileData.class} />
          </div>
        </div>

        {/* Stats Row */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <StatCard icon={<Zap size={32} className="text-yellow-500" />} label={isHindi ? 'आज' : 'Today'} value={todayPoints} unit={isHindi ? 'अंक' : 'pts'} />
          <StatCard icon={<Flame size={32} className="text-orange-500" />} label={isHindi ? 'स्ट्रिक' : 'Streak'} value={streakCount} unit={isHindi ? 'दिन' : 'days'} />
          <StatCard icon={<Trophy size={32} className="text-purple-600" />} label={isHindi ? 'कुल' : 'Total'} value={totalPoints} unit={isHindi ? 'अंक' : 'pts'} />
        </div>

        {/* Charts Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          {/* Weekly Progress */}
          <div className="bg-white rounded-[40px] p-8 shadow-xl border-t-8 border-teal-400">
            <h3 className="text-xl font-bold text-gray-800 mb-6 flex items-center gap-2">
              <TrendingUp className="text-teal-500" /> {isHindi ? 'साप्ताहिक प्रगति' : 'Weekly Progress'}
            </h3>
            <div className="h-[250px]">
              <ResponsiveContainer width="100%" height="100%">
                <LineChart data={weeklyData}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} />
                  <XAxis dataKey="day" axisLine={false} tickLine={false} />
                  <YAxis axisLine={false} tickLine={false} />
                  <Tooltip 
                    contentStyle={{ borderRadius: '15px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }}
                  />
                  <Line 
                    type="monotone" 
                    dataKey="points" 
                    stroke="#2DD4BF" 
                    strokeWidth={4} 
                    dot={{ fill: '#2DD4BF', r: 6, strokeWidth: 2, stroke: '#fff' }} 
                    activeDot={{ r: 8 }}
                  />
                </LineChart>
              </ResponsiveContainer>
            </div>
          </div>

          {/* Overall Accuracy */}
          <div className="bg-white rounded-[40px] p-8 shadow-xl border-t-8 border-[#6541EF]">
            <h3 className="text-xl font-bold text-gray-800 mb-6 flex items-center gap-2">
              <Award className="text-[#6541EF]" /> {isHindi ? 'कुल सटीकता' : 'Overall Accuracy'}
            </h3>
            <div className="flex items-center justify-around">
               <div className="h-[200px] w-1/2">
                 <ResponsiveContainer width="100%" height="100%">
                   <PieChart>
                     <Pie
                        data={pieData}
                        innerRadius={60}
                        outerRadius={80}
                        paddingAngle={5}
                        dataKey="value"
                     >
                       {pieData.map((entry, index) => (
                         <Cell key={`cell-${index}`} fill={entry.color} />
                       ))}
                     </Pie>
                   </PieChart>
                 </ResponsiveContainer>
                 <div className="absolute top-1/2 left-1/4 transform -translate-y-1/2 text-center w-1/2 pointer-events-none">
                    <span className="text-3xl font-black text-gray-800">{overallAccuracy}%</span>
                 </div>
               </div>
               <div className="space-y-4">
                 <div className="flex items-center gap-2">
                   <div className="w-4 h-4 rounded-full bg-green-500" />
                   <span className="text-gray-600 font-bold">{totalAccuracy.correct} {isHindi ? 'सही' : 'Correct'}</span>
                 </div>
                 <div className="flex items-center gap-2">
                   <div className="w-4 h-4 rounded-full bg-red-500" />
                   <span className="text-gray-600 font-bold">{totalAccuracy.incorrect} {isHindi ? 'गलत' : 'Incorrect'}</span>
                 </div>
               </div>
            </div>
          </div>
        </div>

        {/* Game Accuracy Bars */}
        <div className="bg-white rounded-[40px] p-8 shadow-xl border-t-8 border-orange-400">
           <h3 className="text-xl font-bold text-gray-800 mb-6">{isHindi ? 'खेल सटीकता' : 'Game Accuracy'}</h3>
           <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-12 gap-y-6">
             {gameAccuracies.map((game, idx) => (
               <div key={idx} className="space-y-2">
                 <div className="flex justify-between text-sm font-bold text-gray-600">
                   <span>{game.name}</span>
                   <span>{game.accuracy}%</span>
                 </div>
                 <div className="h-3 bg-gray-100 rounded-full overflow-hidden">
                   <div 
                     className="h-full bg-orange-400 rounded-full transition-all duration-1000" 
                     style={{ width: `${game.accuracy}%` }}
                   />
                 </div>
               </div>
             ))}
           </div>
        </div>

        {/* Monthly Heatmap */}
        <div className="bg-white rounded-[40px] p-8 shadow-xl border-t-8 border-cyan-400">
          <h3 className="text-xl font-bold text-gray-800 mb-6">{isHindi ? 'मासिक प्रगति' : 'Monthly Progress'}</h3>
          <div className="px-4">
            <CalendarHeatmap
              startDate={new Date(new Date().setMonth(new Date().getMonth() - 2))}
              endDate={new Date()}
              values={monthlyStats}
              classForValue={(value) => {
                if (!value) return 'color-empty';
                return `color-scale-${Math.min(value.count, 4)}`;
              }}
            />
          </div>
          <style>{`
            .react-calendar-heatmap .color-scale-1 { fill: #d1fae5; }
            .react-calendar-heatmap .color-scale-2 { fill: #6ee7b7; }
            .react-calendar-heatmap .color-scale-3 { fill: #10b981; }
            .react-calendar-heatmap .color-scale-4 { fill: #059669; }
            .react-calendar-heatmap .color-empty { fill: #f3f4f6; }
          `}</style>
        </div>

      </main>

      {/* Edit Modal */}
      {isEditing && (
        <div className="fixed inset-0 bg-black/50 z-[100] flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl p-8 max-w-md w-full shadow-2xl relative">
            <button onClick={() => setIsEditing(false)} className="absolute top-4 right-4 p-2 text-gray-400 hover:text-gray-600">
              <X size={24} />
            </button>
            <h2 className="text-2xl font-bold text-[#6541EF] mb-6">{isHindi ? 'प्रोफ़ाइल संपादित करें' : 'Edit Profile'}</h2>
            
            <form onSubmit={handleUpdateProfile} className="space-y-4">
               <div>
                 <label className="block text-sm font-bold text-gray-600 mb-1">{isHindi ? 'नाम' : 'Name'}</label>
                 <input 
                   type="text" 
                   value={editFormData.name} 
                   onChange={e => setEditFormData({...editFormData, name: e.target.value})}
                   className="w-full px-4 py-2 rounded-xl border-2 border-gray-100 focus:border-[#6541EF] outline-none"
                 />
               </div>
               <div className="grid grid-cols-2 gap-4">
                 <div>
                   <label className="block text-sm font-bold text-gray-600 mb-1">{isHindi ? 'आयु' : 'Age'}</label>
                   <input 
                     type="number" 
                     value={editFormData.age} 
                     onChange={e => setEditFormData({...editFormData, age: e.target.value})}
                     className="w-full px-4 py-2 rounded-xl border-2 border-gray-100 focus:border-[#6541EF] outline-none"
                   />
                 </div>
                 <div>
                   <label className="block text-sm font-bold text-gray-600 mb-1">{isHindi ? 'लिंग' : 'Gender'}</label>
                   <select 
                     value={editFormData.gender}
                     onChange={e => setEditFormData({...editFormData, gender: e.target.value})}
                     className="w-full px-4 py-2 rounded-xl border-2 border-gray-100 focus:border-[#6541EF] outline-none"
                   >
                     <option value="Male">{isHindi ? 'पुरुष' : 'Male'}</option>
                     <option value="Female">{isHindi ? 'महिला' : 'Female'}</option>
                     <option value="Other">{isHindi ? 'अन्य' : 'Other'}</option>
                   </select>
                 </div>
               </div>
               <div>
                  <label className="block text-sm font-bold text-gray-600 mb-1">{isHindi ? 'कक्षा' : 'Class'}</label>
                  <input 
                    type="text" 
                    value={editFormData.class} 
                    onChange={e => setEditFormData({...editFormData, class: e.target.value})}
                    className="w-full px-4 py-2 rounded-xl border-2 border-gray-100 focus:border-[#6541EF] outline-none"
                  />
               </div>
               <div className="flex items-center gap-2">
                  <input 
                    type="checkbox" 
                    id="school"
                    checked={editFormData.school} 
                    onChange={e => setEditFormData({...editFormData, school: e.target.checked})}
                    className="w-5 h-5 rounded accent-[#6541EF]"
                  />
                  <label htmlFor="school" className="text-sm font-bold text-gray-600">{isHindi ? 'क्या आप स्कूल जाते हैं?' : 'Goes to School?'}</label>
               </div>
               
               <button type="submit" className="w-full py-4 bg-[#6541EF] text-white rounded-2xl font-bold text-lg shadow-lg hover:scale-[1.02] active:scale-95 transition-all mt-6">
                 {isHindi ? 'अपडेट करें' : 'UPDATE PROFILE'}
               </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

const InfoRow: React.FC<{ icon: React.ReactNode, label: string, value: any }> = ({ icon, label, value }) => (
  <div className="flex items-center gap-4">
    <div className="w-10 h-10 bg-white/50 rounded-lg flex items-center justify-center text-[#6541EF]">
      {icon}
    </div>
    <div>
      <span className="block text-xs uppercase font-bold text-[#6541EF]/70">{label}</span>
      <span className="text-lg font-bold text-gray-800">{value?.toString() || '-'}</span>
    </div>
  </div>
);

const StatCard: React.FC<{ icon: React.ReactNode, label: string, value: number, unit: string }> = ({ icon, label, value, unit }) => (
  <div className="bg-white rounded-3xl p-6 shadow-md border-b-4 border-gray-100 flex items-center gap-4">
    <div className="p-3 bg-gray-50 rounded-2xl">{icon}</div>
    <div>
      <span className="block text-sm font-bold text-gray-400">{label}</span>
      <div className="flex items-baseline gap-1">
        <span className="text-2xl font-black text-gray-800">{value}</span>
        <span className="text-sm font-bold text-gray-500">{unit}</span>
      </div>
    </div>
  </div>
);
