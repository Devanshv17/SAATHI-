import React, { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { NavBar } from '../components/NavBar';
import { VoiceIcon } from '../components/VoiceIcon';
import { X, CheckCircle, AlertCircle } from 'lucide-react';
import Clock from 'react-clock';
import 'react-clock/dist/Clock.css';

export const VideoLesson: React.FC = () => {
  const location = useLocation();
  const navigate = useNavigate();
  const {
    script,
    fromPage,
    question,
    correctOption,
    attemptedOption,
    imageAssets,
    leftAssets,
    rightAssets,
    imageUrl,
    clockTime,
    isHindi
  } = location.state || {};

  const [isSpeaking, setIsSpeaking] = useState(false);

  useEffect(() => {
    // Auto-speak feedback when entering the page
    if (script) {
      const utterance = new SpeechSynthesisUtterance(script);
      utterance.lang = isHindi ? 'hi-IN' : 'en-US';
      utterance.onstart = () => setIsSpeaking(true);
      utterance.onend = () => setIsSpeaking(false);
      window.speechSynthesis.speak(utterance);
    }
    return () => {
      window.speechSynthesis.cancel();
    };
  }, [script, isHindi]);

  const renderVisuals = () => {
    switch (fromPage) {
      case 'let-us-count':
        return (
          <div className="flex flex-wrap gap-2 justify-center p-4">
            {imageAssets?.map((asset: string, i: number) => (
              <img key={i} src={`/assets/${asset.split('/').pop()}`} alt="object" className="w-10 h-10" />
            ))}
          </div>
        );
      case 'compare':
        return (
          <div className="flex justify-between w-full gap-4 mt-4">
            <div className="flex-1 p-3 border-2 border-dashed border-gray-300 rounded-xl bg-white min-h-[100px] flex flex-wrap gap-1 justify-center">
              {leftAssets?.map((asset: string, i: number) => (
                <img key={i} src={`/assets/${asset.split('/').pop()}`} alt="left" className="w-8 h-8" />
              ))}
            </div>
            <div className="flex items-center font-bold text-2xl text-[#6541EF]">VS</div>
            <div className="flex-1 p-3 border-2 border-dashed border-gray-300 rounded-xl bg-white min-h-[100px] flex flex-wrap gap-1 justify-center">
              {rightAssets?.map((asset: string, i: number) => (
                <img key={i} src={`/assets/${asset.split('/').pop()}`} alt="right" className="w-8 h-8" />
              ))}
            </div>
          </div>
        );
      case 'guess-the-letter':
        return imageUrl ? (
          <div className="flex justify-center p-4">
            <img src={imageUrl} alt="question" className="max-h-32 object-contain rounded-lg" />
          </div>
        ) : null;
      case 'let-us-tell-time':
        return clockTime ? (
          <div className="flex justify-center p-6">
            <div className="bg-gray-100 p-4 rounded-full shadow-inner">
              <Clock value={new Date(clockTime)} size={150} renderNumbers />
            </div>
          </div>
        ) : null;
      default:
        return null;
    }
  };

  return (
    <div className="min-h-screen bg-[#F5FFFF]">
      <NavBar isHindi={isHindi} onToggleLanguage={() => {}} />
      
      <main className="p-6 max-w-2xl mx-auto">
        <div className="flex items-center gap-4 mb-6">
          <button 
            onClick={() => navigate(-1)}
            className="p-2 hover:bg-gray-200 rounded-full transition-colors"
          >
            <X size={24} />
          </button>
          <h1 className="text-2xl font-bold text-[#6541EF]">
            {isHindi ? 'AI विश्लेषण' : 'AI Explanation'}
          </h1>
        </div>

        <div className="bg-white rounded-[32px] p-6 shadow-lg border-2 border-[#6541EF] flex flex-col gap-6">
          {/* Question Box */}
          <div className="bg-gray-50 p-4 rounded-2xl border border-gray-200 text-center">
            <p className="text-lg font-bold text-gray-800">{question}</p>
          </div>

          {/* Visual Evidence */}
          {renderVisuals()}

          {/* Correct vs Attempted */}
          <div className="grid grid-cols-2 gap-4">
            <div className="flex flex-col items-center p-4 rounded-2xl border-2 border-green-500 bg-green-50">
              <span className="text-xs font-bold text-green-600 mb-2 uppercase">
                {isHindi ? 'सही उत्तर' : 'Correct Answer'}
              </span>
              <div className="flex items-center gap-2">
                <CheckCircle size={20} className="text-green-500" />
                <span className="text-xl font-bold">{correctOption}</span>
              </div>
            </div>
            {attemptedOption && (
              <div className="flex flex-col items-center p-4 rounded-2xl border-2 border-red-500 bg-red-50">
                <span className="text-xs font-bold text-red-600 mb-2 uppercase">
                  {isHindi ? 'आपका उत्तर' : 'Your Answer'}
                </span>
                <div className="flex items-center gap-2">
                  <X size={20} className="text-red-500" />
                  <span className="text-xl font-bold">{attemptedOption}</span>
                </div>
              </div>
            )}
          </div>

          <hr className="border-gray-100" />

          {/* AI Script */}
          <div className="relative group">
            <div className="flex justify-between items-start mb-2">
               <h3 className="text-sm font-bold text-gray-500 uppercase tracking-wider">
                 {isHindi ? 'शिक्षक ने कहा' : 'Teacher says'}
               </h3>
               <div className={isSpeaking ? 'animate-pulse text-blue-500' : 'text-[#6541EF]'}>
                 <VoiceIcon text={script} isHindi={isHindi} size={28} />
               </div>
            </div>
            <div className="p-5 bg-[#BFEBF7] bg-opacity-30 rounded-2xl border-l-4 border-[#6541EF]">
              <p className="text-xl leading-relaxed text-gray-800 italic">
                "{script}"
              </p>
            </div>
          </div>

          <button
            onClick={() => navigate(-1)}
            className="mt-4 w-full py-4 bg-[#6541EF] text-white rounded-2xl font-bold text-lg shadow-md hover:bg-[#412896] transition-colors"
          >
            {isHindi ? 'वापस जाएं' : 'GO BACK'}
          </button>
        </div>
      </main>
    </div>
  );
};
