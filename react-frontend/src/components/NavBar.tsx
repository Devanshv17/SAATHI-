import React from 'react';

interface NavBarProps {
  isHindi: boolean;
  onToggleLanguage: (value: boolean) => void;
  showMenuButton?: boolean;
  onClickMenu?: () => void;
}

export const NavBar: React.FC<NavBarProps> = ({ isHindi, onToggleLanguage, showMenuButton, onClickMenu }) => {
  return (
    <nav className="bg-[#6541EF] px-4 py-3 shadow-md flex items-center justify-between sticky top-0 z-50">
      <div className="flex items-center gap-3">
        {showMenuButton && (
          <button onClick={onClickMenu} className="text-[#EFFFF5] p-2">
            <svg xmlns="http://www.w3.org/2000/svg" className="h-10 w-10" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
        )}
        <img src="/assets/logo.png" alt="Saathi Logo" className="h-10" />
        <span className="text-[#EFFFF5] text-2xl font-['MyCustomFont']">
          {isHindi ? 'साथी' : 'Saathi'}
        </span>
      </div>

      <div className="flex items-center gap-2">
        <span className={`text-[20px] ${!isHindi ? 'text-white font-bold' : 'text-[#BFEBEF]'}`}>
          EN
        </span>
        <button 
          onClick={() => onToggleLanguage(!isHindi)}
          className={`w-12 h-6 rounded-full relative transition-colors ${isHindi ? 'bg-white' : 'bg-[#D1D5DB]'}`}
        >
          <div className={`absolute top-1 w-4 h-4 rounded-full transition-all ${isHindi ? 'right-1 bg-[#6541EF]' : 'left-1 bg-white shadow-sm'}`} />
        </button>
        <span className={`text-[20px] ${isHindi ? 'text-white font-bold' : 'text-[#BFEBEF]'}`}>
          हिंदी
        </span>
      </div>
    </nav>
  );
};
