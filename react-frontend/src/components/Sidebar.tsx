import React from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { X, Home, User, Info, Users, LogOut, ChevronRight } from 'lucide-react';

interface SidebarProps {
  isOpen: boolean;
  onClose: () => void;
  isHindi: boolean;
}

export const Sidebar: React.FC<SidebarProps> = ({ isOpen, onClose, isHindi }) => {
  const navigate = useNavigate();
  const { logout, user } = useAuth();

  const menuItems = [
    { icon: <Home size={24} />, label: isHindi ? 'होम' : 'Home', path: '/' },
    { icon: <User size={24} />, label: isHindi ? 'प्रोफ़ाइल' : 'Profile', path: '/profile' },
    { icon: <Info size={24} />, label: isHindi ? 'साथी के बारे में' : 'About Saathi', path: '/about' },
    { icon: <Users size={24} />, label: isHindi ? 'हमारी टीम' : 'Our Team', path: '/team' },
  ];

  const handleLogout = async () => {
    try {
      await logout();
      navigate('/login');
    } catch (error) {
      console.error(error);
    }
  };

  return (
    <>
      {/* Overlay */}
      <div 
        className={`fixed inset-0 bg-black/50 z-[110] transition-opacity duration-300 ${isOpen ? 'opacity-100 visible' : 'opacity-0 invisible'}`} 
        onClick={onClose}
      />
      
      {/* Panel */}
      <div className={`fixed top-0 left-0 h-full w-[280px] bg-[#6541EF] z-[120] transition-transform duration-300 transform ${isOpen ? 'translate-x-0' : '-translate-x-full'} shadow-2xl flex flex-col`}>
        {/* Header */}
        <div className="p-8 flex flex-col items-center border-b border-white/10">
          <button onClick={onClose} className="absolute top-4 right-4 text-white/70 hover:text-white">
            <X size={24} />
          </button>
          <div className="w-20 h-20 bg-white rounded-full flex items-center justify-center mb-4 shadow-lg">
             <img src="/assets/logo.png" alt="Logo" className="w-14" />
          </div>
          <h2 className="text-white text-xl font-bold">{user?.displayName || (isHindi ? 'साथी' : 'Saathi')}</h2>
        </div>

        {/* Menu */}
        <nav className="flex-1 p-4 py-8 space-y-2">
          {menuItems.map((item, idx) => (
            <button
               key={idx}
               onClick={() => {
                 navigate(item.path);
                 onClose();
               }}
               className="w-full flex items-center justify-between p-4 rounded-2xl text-white/90 hover:bg-white/10 transition-colors group"
            >
              <div className="flex items-center gap-4">
                {item.icon}
                <span className="font-bold text-lg">{item.label}</span>
              </div>
              <ChevronRight size={20} className="text-white/30 group-hover:translate-x-1 transition-transform" />
            </button>
          ))}
        </nav>

        {/* Footer */}
        <div className="p-4 border-t border-white/10">
          <button 
            onClick={handleLogout}
            className="w-full flex items-center gap-4 p-4 rounded-2xl text-white/90 hover:bg-red-500/20 transition-colors"
          >
            <LogOut size={24} className="text-red-300" />
            <span className="font-bold text-lg text-red-300">{isHindi ? 'लॉग आउट' : 'Log Out'}</span>
          </button>
        </div>
      </div>
    </>
  );
};
