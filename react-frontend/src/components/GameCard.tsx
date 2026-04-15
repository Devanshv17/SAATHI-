import React from 'react';
import { VoiceIcon } from './VoiceIcon';

interface GameCardProps {
  title: string;
  imagePath: string;
  correctScore: number;
  incorrectScore: number;
  isHindi: boolean;
  onPlay: () => void;
  playLabel: string;
  continueLabel: string;
}

export const GameCard: React.FC<GameCardProps> = ({
  title,
  imagePath,
  correctScore,
  incorrectScore,
  isHindi,
  onPlay,
  playLabel,
  continueLabel,
}) => {
  const hasPlayed = (correctScore + incorrectScore) > 0;
  const imageSrc = imagePath.startsWith('assets/') ? `/${imagePath}` : imagePath;

  return (
    <div className="w-[85%] p-[10px] my-[10px] bg-[rgba(191,235,239,0.4)] border-2 border-[#6541EF] rounded-[15px] flex items-center shadow-sm mx-auto">
      <div 
        className="w-[70px] h-[70px] rounded-full border border-[#6541EF] bg-cover bg-center shrink-0"
        style={{ backgroundImage: `url(${imageSrc})` }}
      />
      
      <div className="ml-[15px] flex-1">
        <div className="flex items-start gap-2">
          <h3 className="text-lg font-bold text-[#444] leading-tight flex-1">
            {title}
          </h3>
          <VoiceIcon text={title} isHindi={isHindi} size={20} />
        </div>

        {hasPlayed && (
          <div className="mt-1 flex items-center gap-2 font-bold text-lg">
            <span className="text-[#3F6C40]">{correctScore}</span>
            <span className="text-[#6541EF]">|</span>
            <span className="text-[#C85257]">{incorrectScore}</span>
          </div>
        )}

        <div className="mt-2 flex">
          <button 
            onClick={onPlay}
            className="bg-[#BFEBF7] px-4 py-1.5 rounded-lg text-sm font-bold shadow-sm hover:bg-[#a6e0f0] transition-colors"
          >
            {hasPlayed ? continueLabel : playLabel}
          </button>
        </div>
      </div>
    </div>
  );
};
