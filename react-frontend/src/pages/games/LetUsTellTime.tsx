import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import { NavBar } from '../../components/NavBar';
import { VoiceIcon } from '../../components/VoiceIcon';
import { db, rtdb } from '../../firebase';
import { collection, query, getDocs, orderBy, limit, where, documentId } from 'firebase/firestore';
import { ref, get, update, increment, set as dbSet } from 'firebase/database';
import { aiService } from '../../services/aiService';
import { Brain, ArrowRight, X, Clock } from 'lucide-react';
import ReactClock from 'react-clock';
import 'react-clock/dist/Clock.css';

interface LetUsTellTimeProps {
  gameTitle: string;
  isHindi: boolean;
}

export const LetUsTellTime: React.FC<LetUsTellTimeProps> = ({ gameTitle, isHindi }) => {
  const { user } = useAuth();
  const navigate = useNavigate();

  // State
  const [isLoading, setIsLoading] = useState(true);
  const [isPretestMode, setIsPretestMode] = useState(false);
  const [showPretestIntro, setShowPretestIntro] = useState(false);
  
  const [questions, setQuestions] = useState<any[]>([]);
  const [currentQuestionIndex, setCurrentQuestionIndex] = useState(0);
  const [userAnswers, setUserAnswers] = useState<Record<string, any>>({});
  const [pendingSelectedIndex, setPendingSelectedIndex] = useState<number | null>(null);
  const [hasSubmitted, setHasSubmitted] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [isAiAnalyzing, setIsAiAnalyzing] = useState(false);

  const [clockTime, setClockTime] = useState<Date>(new Date(2025, 0, 1, 10, 0));
  const questionStartTime = useRef<number>(Date.now());

  useEffect(() => {
    const initializeGame = async () => {
      if (!user) return;
      const snap = await get(ref(rtdb, `users/${user.uid}/games/${gameTitle}`));
      let preCompleted = false;
      let state: any = {};

      if (snap.exists()) {
        state = snap.val();
        preCompleted = state.pretestCompleted || false;
      }
      
      if (preCompleted) {
        setIsPretestMode(false);
        await setupMainGame(state);
      } else {
        setIsPretestMode(true);
        await setupPretest(state);
      }
      setIsLoading(false);
    };

    initializeGame();
  }, [user, gameTitle]);

  const setupPretest = async (state: any) => {
    const pretestState = state.pretest;
    if (pretestState?.questionIds && pretestState.questionIds.length > 0) {
      setUserAnswers(pretestState.answers || {});
      const idx = pretestState.currentQuestionIndex || 0;
      setCurrentQuestionIndex(idx);
      await loadPretestQuestions(pretestState.questionIds, idx);
    } else {
      setShowPretestIntro(true);
    }
  };

  const generatePretest = async () => {
    setIsLoading(true);
    try {
      const getIds = async (col: string, count: number) => {
        const q = query(collection(db, col), limit(count));
        const snap = await getDocs(q);
        return snap.docs.map(d => d.id);
      };

      const l1Ids = await getIds(`${gameTitle} L1`, 4);
      const l2Ids = await getIds(`${gameTitle} L2`, 4);
      const l3Ids = await getIds(`${gameTitle} L3`, 2);
      
      const allIds = [...l1Ids.map(id => ({id, level: 'L1'})), 
                      ...l2Ids.map(id => ({id, level: 'L2'})), 
                      ...l3Ids.map(id => ({id, level: 'L3'}))];
      
      for (let i = allIds.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [allIds[i], allIds[j]] = [allIds[j], allIds[i]];
      }

      const initialPretestState = {
        questionIds: allIds,
        levelScores: {
          L1: { correct: 0, incorrect: 0 },
          L2: { correct: 0, incorrect: 0 },
          L3: { correct: 0, incorrect: 0 }
        },
        answers: {},
        currentQuestionIndex: 0
      };

      await dbSet(ref(rtdb, `users/${user!.uid}/games/${gameTitle}/pretest`), initialPretestState);
      setShowPretestIntro(false);
      await loadPretestQuestions(allIds, 0);
    } finally {
      setIsLoading(false);
    }
  };

  const loadPretestQuestions = async (questionIds: any[], startIndex: number) => {
    const idsByLevel: Record<string, string[]> = {};
    questionIds.forEach(q => {
      if (!idsByLevel[q.level]) idsByLevel[q.level] = [];
      idsByLevel[q.level].push(q.id);
    });

    const docsById: Record<string, any> = {};
    for (const [level, ids] of Object.entries(idsByLevel)) {
      const q = query(collection(db, `${gameTitle} ${level}`), where(documentId(), 'in', ids));
      const snap = await getDocs(q);
      snap.forEach(doc => {
        docsById[doc.id] = doc.data();
      });
    }

    const loadedQuestions = questionIds.map(q => ({
      id: q.id,
      level: q.level,
      data: docsById[q.id]
    })).filter(q => q.data);

    setQuestions(loadedQuestions);
    initQuestionState(loadedQuestions, startIndex);
  };

  const setupMainGame = async (state: any) => {
    const mainGameData = state.main_game;
    setUserAnswers(mainGameData?.answers || {});
    await loadCurrentLevelQuestions(state);
  };

  const loadCurrentLevelQuestions = async (state: any) => {
    const mainGameData = state.main_game || {};
    const levelsToShow = mainGameData.levelsToShow || [];
    const currentLevelIdx = mainGameData.currentLevelIndex || 0;
    
    if (levelsToShow.length === 0 || currentLevelIdx >= levelsToShow.length) {
      setQuestions([]);
      return;
    }
    
    const currentLevelName = levelsToShow[currentLevelIdx];
    const q = query(collection(db, `${gameTitle} ${currentLevelName}`), orderBy('timestamp'));
    const snap = await getDocs(q);
    
    const loadedQuestions = snap.docs.map(doc => ({
      id: doc.id,
      level: currentLevelName,
      data: doc.data()
    }));
    
    setQuestions(loadedQuestions);
    const progress = mainGameData.levelProgress?.[currentLevelName]?.currentQuestionIndex || 0;
    setCurrentQuestionIndex(progress);
    initQuestionState(loadedQuestions, progress);
  };

  const initQuestionState = (qs: any[], idx: number) => {
    if (qs.length === 0 || idx >= qs.length) return;
    const currentQ = qs[idx];
    const data = currentQ.data;
    
    // Parse time from text (e.g., "10:30")
    const match = data.text.match(/(\d{1,2}):(\d{2})/);
    if (match) {
      const hours = parseInt(match[1]);
      const minutes = parseInt(match[2]);
      setClockTime(new Date(2025, 0, 1, hours, minutes));
    }

    if (userAnswers[currentQ.id]) {
      setPendingSelectedIndex(userAnswers[currentQ.id].selectedOptionIndex);
      setHasSubmitted(true);
    } else {
      setPendingSelectedIndex(null);
      setHasSubmitted(false);
    }
    questionStartTime.current = Date.now();
  };

  const handleSubmit = async () => {
    if (pendingSelectedIndex === null || hasSubmitted || isProcessing) return;
    setIsProcessing(true);
    
    const currentQuestion = questions[currentQuestionIndex];
    const isCorrect = currentQuestion.data.options[pendingSelectedIndex].isCorrect;
    
    const newAnswer = {
      selectedOptionIndex: pendingSelectedIndex,
      isCorrect,
      timeTakenSeconds: Math.floor((Date.now() - questionStartTime.current) / 1000)
    };
    
    const newUserAnswers = { ...userAnswers, [currentQuestion.id]: newAnswer };
    setUserAnswers(newUserAnswers);
    setHasSubmitted(true);
    speakFeedback(isCorrect);
    
    if (isPretestMode) {
      await updatePretestState(newUserAnswers, isCorrect);
    } else {
      await updateMainGameState(newUserAnswers, isCorrect);
    }
    setIsProcessing(false);
  };

  const updatePretestState = async (answers: Record<string, any>, isCorrect: boolean) => {
    const level = questions[currentQuestionIndex].level;
    const updates: any = {
      [`pretest/levelScores/${level}/${isCorrect ? 'correct' : 'incorrect'}`]: increment(1),
      [`pretest/currentQuestionIndex`]: currentQuestionIndex,
      [`pretest/answers`]: answers
    };
    await update(ref(rtdb, `users/${user!.uid}/games/${gameTitle}`), updates);
  };

  const updateMainGameState = async (answers: Record<string, any>, isCorrect: boolean) => {
    const currentLevel = questions[currentQuestionIndex].level;
    const dateKey = new Date().toISOString().split('T')[0];
    
    const updates: any = {
      [`main_game/correctCount`]: increment(isCorrect ? 1 : 0),
      [`main_game/incorrectCount`]: increment(isCorrect ? 0 : 1),
      [`main_game/score`]: increment(isCorrect ? 1 : 0),
      [`main_game/levelProgress/${currentLevel}/currentQuestionIndex`]: currentQuestionIndex,
      [`main_game/answers`]: answers,
    };
    
    // Overall stats
    const overallUpdates: any = {
      [`users/${user!.uid}/totalAttempted`]: increment(1),
      [`users/${user!.uid}/score`]: increment(isCorrect ? 1 : 0),
      [`users/${user!.uid}/monthlyStats/${dateKey}/correct`]: increment(isCorrect ? 1 : 0),
      [`users/${user!.uid}/monthlyStats/${dateKey}/incorrect`]: increment(isCorrect ? 0 : 1),
      [`users/${user!.uid}/today_activity/date`]: dateKey,
      [`users/${user!.uid}/today_activity/correct`]: increment(isCorrect ? 1 : 0),
      [`users/${user!.uid}/today_activity/incorrect`]: increment(isCorrect ? 0 : 1),
    };

    await Promise.all([
      update(ref(rtdb, `users/${user!.uid}/games/${gameTitle}`), updates),
      update(ref(rtdb), overallUpdates)
    ]);
  };

  const speakFeedback = (isCorrect: boolean) => {
    const posH = ['शाबाश! बिल्कुल सही।', 'वाह! बहुत बढ़िया।', 'सही जवाब! बहुत अच्छे।'];
    const negH = ['ध्यान दो, अगली बार सही होगा।', 'कोशिश करते रहो, तुम कर सकते हो!', 'हिम्मत रखो, अगली बार ज़रूर सही होगा।'];
    const posE = ['Correct! Well done!', 'Great job! Keep it up!', 'Excellent! You got it right!'];
    const negE = ['Focus! You will get it next time.', 'Keep trying, you can do it!', "Don't give up! Next one will be correct."];
    
    const phrases = isCorrect ? (isHindi ? posH : posE) : (isHindi ? negH : negE);
    const text = phrases[Math.floor(Math.random() * phrases.length)];
    
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = isHindi ? 'hi-IN' : 'en-US';
    window.speechSynthesis.speak(utterance);
  };

  const handleNext = async () => {
    if (isPretestMode && currentQuestionIndex === questions.length - 1) {
      await calculatePretestResults();
      return;
    }

    if (currentQuestionIndex < questions.length - 1) {
      const nextIdx = currentQuestionIndex + 1;
      setCurrentQuestionIndex(nextIdx);
      initQuestionState(questions, nextIdx);
    } else {
      handleEndOfLevel();
    }
  };

  const calculatePretestResults = async () => {
    setIsLoading(true);
    const snap = await get(ref(rtdb, `users/${user!.uid}/games/${gameTitle}/pretest`));
    const pretestState = snap.val();
    const scores = pretestState.levelScores;
    
    const l1p = (scores.L1.correct / 4) >= 0.75;
    const l2p = (scores.L2.correct / 4) >= 0.75;
    const l3p = (scores.L3.correct / 2) >= 1.0;

    const levelsToShow: string[] = [];
    if (!l1p) levelsToShow.push('L1');
    if (!l2p) levelsToShow.push('L2');
    if (!l3p) levelsToShow.push('L3');

    const updates = {
      pretestCompleted: true,
      main_game: {
        levelsToShow,
        currentLevelIndex: 0,
        levelProgress: Object.fromEntries(levelsToShow.map(l => [l, {currentQuestionIndex: 0}])),
        answers: {},
        correctCount: 0,
        incorrectCount: 0,
        score: 0
      }
    };

    await update(ref(rtdb, `users/${user!.uid}/games/${gameTitle}`), updates);
    
    if (levelsToShow.length === 0) {
      navigate('/result', { state: { gameTitle, score: 0, correctCount: 0, incorrectCount: 0, isHindi } });
    } else {
      setIsPretestMode(false);
      await setupMainGame(updates);
    }
    setIsLoading(false);
  };

  const handleEndOfLevel = async () => {
    const snap = await get(ref(rtdb, `users/${user!.uid}/games/${gameTitle}`));
    const state = snap.val();
    const mainGameData = state.main_game;
    const levelsToShow = mainGameData.levelsToShow || [];
    let currentLevelIdx = mainGameData.currentLevelIndex || 0;
    
    currentLevelIdx++;
    if (currentLevelIdx < levelsToShow.length) {
      setIsLoading(true);
      await update(ref(rtdb, `users/${user!.uid}/games/${gameTitle}/main_game`), { currentLevelIndex: currentLevelIdx });
      await loadCurrentLevelQuestions({ ...state, main_game: { ...mainGameData, currentLevelIndex: currentLevelIdx } });
      setIsLoading(false);
    } else {
      navigate('/result', { state: { 
        gameTitle, 
        score: mainGameData.score, 
        correctCount: mainGameData.correctCount, 
        incorrectCount: mainGameData.incorrectCount,
        isHindi 
      }});
    }
  };

  const analyzeWithAI = async () => {
    if (pendingSelectedIndex === null || isAiAnalyzing) return;
    setIsAiAnalyzing(true);
    
    const currentQuestion = questions[currentQuestionIndex];
    const data = currentQuestion.data;
    const options = data.options.map((o: any) => o.title);
    const correctOption = data.options.find((o: any) => o.isCorrect).title;
    const attemptedOption = data.options[pendingSelectedIndex].title;

    try {
      const feedback = await aiService.getFeedback(
        data.text,
        options,
        correctOption,
        attemptedOption,
        undefined,
        isHindi
      );

      navigate('/video-lesson', { state: {
        script: feedback.explanation,
        fromPage: 'let-us-tell-time',
        question: data.text,
        correctOption,
        attemptedOption,
        clockTime,
        isHindi
      }});
    } catch (error) {
      console.error(error);
    } finally {
      setIsAiAnalyzing(false);
    }
  };

  if (isLoading) return <div className="min-h-screen bg-[#F5FFFF] flex items-center justify-center font-bold text-[#6541EF]">LOADING...</div>;

  if (showPretestIntro) return (
    <div className="min-h-screen bg-[#F5FFFF] flex flex-col items-center justify-center p-6 text-center">
       <div className="w-32 h-32 bg-white rounded-full flex items-center justify-center shadow-lg mb-8 border-4 border-[#6541EF]">
        <Clock size={64} className="text-[#6541EF]" />
      </div>
      <h1 className="text-4xl font-bold text-[#6541EF] mb-4">
        {isHindi ? 'समय देखना' : 'Time Pre-test'}
      </h1>
      <p className="text-xl text-gray-600 mb-10 max-w-md">
        {isHindi 
          ? 'आइए देखें कि आप समय को कितनी अच्छी तरह पहचान सकते हैं।' 
          : 'Let\'s see how well you can tell the time from an analog clock.'}
      </p>
      <button 
        onClick={generatePretest}
        className="bg-[#6541EF] text-white px-12 py-4 rounded-full font-bold text-xl shadow-xl hover:scale-105 transition-transform"
      >
        {isHindi ? 'शुरू करें' : 'GET STARTED'}
      </button>
    </div>
  );

  const currentQuestion = questions[currentQuestionIndex];
  if (!currentQuestion) return null;

  return (
    <div className="min-h-screen bg-[#F5FFFF]">
      <NavBar isHindi={isHindi} onToggleLanguage={() => {}} />
      
      <main className="p-4 max-w-4xl mx-auto">
        <div className="bg-[#6541EF] text-white px-6 py-4 rounded-2xl flex justify-between items-center mb-6 shadow-lg">
          <div>
            <span className="text-xs opacity-80 uppercase font-bold">
              {isPretestMode ? 'Time (Pre-test)' : `Time - ${currentQuestion.level}`}
            </span>
            <h1 className="text-xl font-bold uppercase">{gameTitle}</h1>
          </div>
          <div className="flex gap-4">
             <VoiceIcon text={currentQuestion.data.text} isHindi={isHindi} color="white" />
             <div className="w-10 h-10 bg-white/20 rounded-full flex items-center justify-center cursor-pointer" onClick={() => navigate(-1)}>
                <X size={20} />
             </div>
          </div>
        </div>

        <div className="bg-white rounded-[40px] p-8 shadow-xl border-t-8 border-[#6541EF]">
          <h2 className="text-2xl font-bold text-gray-800 mb-8 text-center leading-relaxed">
            {isHindi ? 'सही समय चुनें' : 'Select the correct time'}
          </h2>

          {/* Clock View */}
          <div className="flex justify-center mb-10">
             <div className="p-8 bg-gray-50 rounded-full border-4 border-gray-100 shadow-inner">
               <ReactClock 
                 value={clockTime} 
                 size={250} 
                 renderNumbers={true}
               />
             </div>
          </div>

          <div className="grid grid-cols-2 gap-4 max-w-lg mx-auto">
            {currentQuestion.data.options.map((opt: any, idx: number) => {
              const isSelected = pendingSelectedIndex === idx;
              const showResult = hasSubmitted && isSelected;
              const isCorrect = opt.isCorrect;
              
              let borderColor = "border-gray-100";
              let bgColor = "bg-white";
              
              if (isSelected) borderColor = "border-[#6541EF]";
              if (showResult) {
                borderColor = isCorrect ? "border-green-500" : "border-red-500";
                bgColor = isCorrect ? "bg-green-50" : "bg-red-50";
              }

              return (
                <button
                  key={idx}
                  onClick={() => !hasSubmitted && setPendingSelectedIndex(idx)}
                  className={`p-6 rounded-3xl border-4 transition-all flex items-center justify-center gap-2 group ${borderColor} ${bgColor}`}
                  disabled={hasSubmitted}
                >
                  <span className={`text-2xl font-black ${isSelected ? 'text-[#6541EF]' : 'text-gray-700'}`}>
                    {opt.title}
                  </span>
                </button>
              );
            })}
          </div>

          <div className="mt-12 flex flex-col items-center gap-6">
            {!hasSubmitted ? (
              <button 
                onClick={handleSubmit}
                disabled={pendingSelectedIndex === null || isProcessing}
                className="w-full max-w-sm py-5 bg-[#6541EF] text-white rounded-3xl font-bold text-xl shadow-xl active:scale-95 transition-all disabled:opacity-50"
              >
                {isProcessing ? 'SUBMITTING...' : 'SUBMIT'}
              </button>
            ) : (
              <div className="flex flex-col w-full gap-4 items-center">
                {!currentQuestion.data.options[pendingSelectedIndex!].isCorrect && (
                   <button 
                     onClick={analyzeWithAI}
                     disabled={isAiAnalyzing}
                     className="flex items-center gap-2 text-[#6541EF] font-bold py-2 px-4 rounded-xl hover:bg-white transition-colors"
                   >
                     {isAiAnalyzing ? (
                       <span className="flex items-center gap-2 animate-pulse"><Brain size={24} /> Analyzing...</span>
                     ) : (
                       <><Brain size={24} /> {isHindi ? 'AI शिक्षक से पूछें' : 'ASK AI TEACHER'}</>
                     )}
                   </button>
                )}
                
                <div className="flex gap-4 w-full max-w-sm">
                   <button 
                    onClick={handleNext}
                    className="flex-1 py-5 bg-[#6541EF] text-white rounded-3xl font-bold text-xl shadow-xl flex items-center justify-center gap-2 active:scale-95 transition-all"
                  >
                    NEXT <ArrowRight size={24} />
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
};
