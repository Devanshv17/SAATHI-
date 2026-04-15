import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { NavBar } from '../components/NavBar';
import { Sidebar } from '../components/Sidebar';
import { GameCard } from '../components/GameCard';
import { rtdb } from '../firebase';
import { ref, get } from 'firebase/database';

const HomePage: React.FC = () => {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [isHindi, setIsHindi] = useState(false);
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [scores, setScores] = useState<Record<string, { correct: number, incorrect: number }>>({});

  const boxTextsEnglish: Record<string, string> = {
    'Box1': 'Name Picture Matching',
    'Box2': 'Guess the Letter',
    'Box3': 'Compare',
    'Box4': 'Let us Count',
    'Box5': 'Number Name Matching',
    'Box6': 'Name Number Matching',
    'Box7': 'Let us Tell Time',
    'Box9': 'Alphabet Knowledge',
    'Box10': 'Left Middle Right',
    'Box11': 'Shape Knowledge',
  };

  const boxTextsHindi: Record<string, string> = {
    'Box1': 'नाम चित्र मिलान',
    'Box2': 'अक्षर ज्ञान',
    'Box3': 'तुलना',
    'Box4': 'चलो गिनें',
    'Box5': 'संख्या नाम मिलान',
    'Box6': 'नाम संख्या मिलान',
    'Box7': 'चलो समय बताएँ',
    'Box9': 'वर्णमाला ज्ञान',
    'Box10': 'बाएँ दाएँ मध्य',
    'Box11': 'आकार ज्ञान',
  };

  useEffect(() => {
    const loadScores = async () => {
      if (!user) return;
      try {
        const snapshot = await get(ref(rtdb, `users/${user.uid}/games`));
        if (snapshot.exists()) {
          const data = snapshot.val();
          const newScores: Record<string, { correct: number, incorrect: number }> = {};
          
          Object.keys(boxTextsEnglish).forEach(key => {
            const engTitle = boxTextsEnglish[key];
            const hinTitle = boxTextsHindi[key];
            const displayTitle = isHindi ? hinTitle : engTitle;
            
            const gameData = data[displayTitle]?.main_game;
            newScores[displayTitle] = {
              correct: gameData?.correctCount || 0,
              incorrect: gameData?.incorrectCount || 0
            };
          });
          setScores(newScores);
        }
      } catch (err) {
        console.error("Error loading scores:", err);
      }
    };

    loadScores();
  }, [user, isHindi]);

  const games = [
    { id: 'Box1', img: 'assets/npp.png', imgH: 'assets/npph.jpg' },
    { id: 'Box2', img: 'assets/gtl.png', imgH: 'assets/gtlh.jpg' },
    { id: 'Box3', img: 'assets/cmp.png', imgH: 'assets/cmp.png' },
    { id: 'Box4', img: 'assets/cnt.png', imgH: 'assets/cnth.jpg' },
    { id: 'Box5', img: 'assets/namenm.png', imgH: 'assets/namenmh.jpg' },
    { id: 'Box6', img: 'assets/numnp.png', imgH: 'assets/numnph.jpg' },
    { id: 'Box7', img: 'assets/ltt.png', imgH: 'assets/ltth.jpg' },
    { id: 'Box9', img: 'assets/ak.png', imgH: 'assets/akh.jpg' },
    { id: 'Box10', img: 'assets/lr.png', imgH: 'assets/lrh.jpg' },
    { id: 'Box11', img: 'assets/fs.png', imgH: 'assets/fsh.jpg' },
  ];

  return (
    <div className="min-h-screen bg-[#F5FFFF]">
      <NavBar isHindi={isHindi} onToggleLanguage={setIsHindi} showMenuButton onClickMenu={() => setIsSidebarOpen(true)} />
      <Sidebar isOpen={isSidebarOpen} onClose={() => setIsSidebarOpen(false)} isHindi={isHindi} />
      
      <main className="max-w-4xl mx-auto py-6 flex flex-col items-center">
        {games.map((g) => {
          const title = isHindi ? boxTextsHindi[g.id] : boxTextsEnglish[g.id];
          const score = scores[title] || { correct: 0, incorrect: 0 };
          return (
            <GameCard
              key={g.id}
              title={title}
              imagePath={isHindi ? g.imgH : g.img}
              correctScore={score.correct}
              incorrectScore={score.incorrect}
              isHindi={isHindi}
              onPlay={() => {
                const pathMap: Record<string, string> = {
                  'Box1': '/matching',
                  'Box2': '/guess-the-letter',
                  'Box3': '/compare',
                  'Box4': '/let-us-count',
                  'Box5': '/number-name-matching',
                  'Box6': '/name-number-matching',
                  'Box7': '/let-us-tell-time',
                };
                if (pathMap[g.id]) navigate(pathMap[g.id]);
                else console.log("Play", title);
              }}
              playLabel={isHindi ? 'खेलें' : 'Play'}
              continueLabel={isHindi ? 'जारी रखें' : 'Continue'}
            />
          );
        })}
        <div className="h-20" />
      </main>
    </div>
  );
};

export default HomePage;
