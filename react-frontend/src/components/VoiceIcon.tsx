import React from 'react';
import { Volume2 } from 'lucide-react';

interface VoiceIconProps {
  text: string;
  isHindi: boolean;
  size?: number;
  color?: string;
}

export const VoiceIcon: React.FC<VoiceIconProps> = ({ text, isHindi, size = 24, color = '#6541EF' }) => {
  const speak = () => {
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = isHindi ? 'hi-IN' : 'en-US';
    window.speechSynthesis.speak(utterance);
  };

  return (
    <button 
      onClick={speak}
      className="p-1 hover:bg-slate-200 rounded-full transition-colors inline-block"
      title={isHindi ? 'सुनने के लिए दबाएं' : 'Tap to listen'}
    >
      <Volume2 size={size} color={color} />
    </button>
  );
};
