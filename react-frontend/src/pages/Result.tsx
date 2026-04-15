import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { PieChart, Pie, Cell, ResponsiveContainer } from 'recharts';
import { NavBar } from '../components/NavBar';
import { VoiceIcon } from '../components/VoiceIcon';

export const Result: React.FC = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const { 
    gameTitle, 
    score, 
    correctCount, 
    incorrectCount, 
    isHindi 
  } = location.state || {
    gameTitle: 'Game',
    score: 0,
    correctCount: 0,
    incorrectCount: 0,
    isHindi: false
  };

  const total = correctCount + incorrectCount;
  const accuracy = total > 0 ? (correctCount / total) * 100 : 0;

  const data = [
    { name: 'Correct', value: correctCount },
    { name: 'Incorrect', value: incorrectCount },
  ];

  const COLORS = ['#4ADE80', '#F87171']; // green-400 and red-400

  const handleReplay = () => {
    // Navigate back to the game page. 
    // The specific path depends on the gameTitle.
    const pathMap: Record<string, string> = {
      'Let Us Count': '/games/let-us-count',
      'Compare': '/games/compare',
      'Guess The Letter': '/games/guess-the-letter',
      'Matching': '/games/matching',
      'Let Us Tell Time': '/games/let-us-tell-time',
    };
    navigate(pathMap[gameTitle] || '/');
  };

  return (
    <div className="min-h-screen bg-[#F5FFFF]">
      <NavBar isHindi={isHindi} onToggleLanguage={() => {}} />
      
      <main className="p-6 max-w-lg mx-auto flex flex-col items-center">
        <h1 className="text-3xl font-bold text-[#6541EF] mb-8">
          {isHindi ? 'परिणाम' : 'Game Result'}
        </h1>

        <div className="bg-white w-full p-8 rounded-[32px] shadow-lg border-2 border-[#6541EF] flex flex-col items-center">
          <div className="text-6xl mb-4">🏆</div>
          
          <h2 className="text-2xl font-bold text-gray-800 mb-2">{gameTitle}</h2>
          
          <div className="flex gap-8 mb-8">
            <div className="flex flex-col items-center">
              <span className="text-gray-500 text-sm">{isHindi ? 'स्कोर' : 'Score'}</span>
              <span className="text-2xl font-bold text-[#6541EF]">{score}</span>
            </div>
            <div className="flex flex-col items-center">
              <span className="text-gray-500 text-sm">{isHindi ? 'सटीकता' : 'Accuracy'}</span>
              <span className="text-2xl font-bold text-[#6541EF]">{Math.round(accuracy)}%</span>
            </div>
          </div>

          <div className="w-full h-48 mb-8">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={data}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={80}
                  paddingAngle={5}
                  dataKey="value"
                >
                  {data.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
              </PieChart>
            </ResponsiveContainer>
            <div className="text-center -mt-28 font-bold text-xl">
              {correctCount}/{total}
            </div>
            <div className="text-center mt-20 text-sm text-gray-500">
              {isHindi ? 'सही / कुल' : 'Correct / Total'}
            </div>
          </div>

          <div className="flex flex-col w-full gap-4">
            <button
              onClick={handleReplay}
              className="w-full py-4 bg-[#6541EF] text-white rounded-2xl font-bold text-lg shadow-md hover:bg-[#412896] transition-colors"
            >
              {isHindi ? 'फिर से खेलें' : 'REPLAY GAME'}
            </button>
            <button
              onClick={() => navigate('/')}
              className="w-full py-4 bg-white text-[#6541EF] border-2 border-[#6541EF] rounded-2xl font-bold text-lg shadow-sm hover:bg-gray-50 transition-colors"
            >
              {isHindi ? 'मुख्य स्क्रीन' : 'GO HOME'}
            </button>
          </div>
        </div>

        <div className="mt-8 flex items-center gap-2 text-gray-600 bg-white px-4 py-2 rounded-full border shadow-sm">
           <VoiceIcon 
             text={`${isHindi ? 'आपका स्कोर है' : 'Your score is'} ${score}. ${isHindi ? 'सटीकता' : 'Accuracy'} ${Math.round(accuracy)}%`} 
             isHindi={isHindi} 
           />
           <span className="text-sm font-medium">
             {isHindi ? 'परिणाम सुनें' : 'Listen to results'}
           </span>
        </div>
      </main>
    </div>
  );
};
