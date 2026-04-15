import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { NavBar } from '../components/NavBar';
import { VoiceIcon } from '../components/VoiceIcon';

const Login: React.FC = () => {
  const [phoneNumber, setPhoneNumber] = useState('');
  const [countryCode, setCountryCode] = useState('+91');
  const [otp, setOtp] = useState('');
  const [step, setStep] = useState<'phone' | 'otp'>('phone');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [isHindi, setIsHindi] = useState(false);
  
  const { setupRecaptcha, signInWithPhone, confirmOTP } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    setupRecaptcha('recaptcha-container');
  }, []);

  const handleSendOTP = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const formattedPhone = `${countryCode}${phoneNumber}`;
      await signInWithPhone(formattedPhone);
      setStep('otp');
    } catch (err: any) {
      setError(err.message || 'Failed to send OTP');
    } finally {
      setLoading(false);
    }
  };

  const handleVerifyOTP = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      await confirmOTP(otp);
      navigate('/');
    } catch (err: any) {
      setError('Invalid OTP code');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex flex-col min-h-screen bg-[#F5FFFF]">
      <NavBar isHindi={isHindi} onToggleLanguage={setIsHindi} />
      
      <main className="flex-1 flex flex-col items-center justify-center p-6">
        <div id="recaptcha-container"></div>
        
        <img src="/assets/logo.png" alt="Saathi Logo" className="h-[150px] mb-4" />
        
        <div className="flex items-center gap-2 mb-4">
          <div className="text-center">
            <h1 className="text-3xl font-bold text-[#444]">
              {isHindi ? 'स्वागत है' : 'Welcome Back'}
            </h1>
            <p className="text-slate-600">
              {isHindi ? 'कृपया अपने फ़ोन नंबर से लॉगिन करें' : 'Please login with your phone number'}
            </p>
          </div>
          <VoiceIcon 
            text={isHindi ? 'स्वागत है. कृपया अपने फ़ोन नंबर से लॉगिन करें' : 'Welcome Back. Please login with your phone number'} 
            isHindi={isHindi} 
          />
        </div>

        <div className="w-full max-w-md bg-[#C9F5F5] p-8 rounded-2xl shadow-lg border-2 border-[#6541EF]">
          <div className="flex items-center justify-center gap-2 mb-6">
            <h2 className="text-xl font-bold text-[#444]">
              {isHindi ? 'अपना फ़ोन नंबर दर्ज करें' : 'Enter Your Phone Number'}
            </h2>
            <VoiceIcon 
              text={isHindi ? 'अपना फ़ोन नंबर दर्ज करें' : 'Enter Your Phone Number'} 
              isHindi={isHindi} 
            />
          </div>

          <form onSubmit={step === 'phone' ? handleSendOTP : handleVerifyOTP} className="space-y-6">
            {step === 'phone' ? (
              <div className="flex gap-4">
                <div className="flex-1">
                  <label className="block text-sm font-medium mb-1">{isHindi ? 'कोड' : 'Code'}</label>
                  <input
                    type="text"
                    value={countryCode}
                    onChange={(e) => setCountryCode(e.target.value)}
                    className="w-full p-3 rounded-xl border border-[#D1D5DB] focus:ring-2 focus:ring-[#6541EF] outline-none"
                    disabled={loading}
                  />
                </div>
                <div className="flex-[2]">
                  <label className="block text-sm font-medium mb-1">{isHindi ? 'मोबाइल नंबर' : 'Mobile Number'}</label>
                  <input
                    type="tel"
                    value={phoneNumber}
                    onChange={(e) => setPhoneNumber(e.target.value)}
                    className="w-full p-3 rounded-xl border border-[#D1D5DB] focus:ring-2 focus:ring-[#6541EF] outline-none"
                    placeholder="XXXXX XXXXX"
                    disabled={loading}
                  />
                </div>
              </div>
            ) : (
              <div>
                <label className="block text-sm font-medium mb-1">OTP Code</label>
                <input
                  type="text"
                  value={otp}
                  onChange={(e) => setOtp(e.target.value)}
                  className="w-full p-3 rounded-xl border border-[#D1D5DB] focus:ring-2 focus:ring-[#6541EF] outline-none"
                  placeholder="123456"
                  maxLength={6}
                  disabled={loading}
                />
              </div>
            )}

            {error && <p className="text-red-500 text-sm text-center font-bold">{error}</p>}

            <button 
              className="w-full bg-[#6541EF] text-white py-4 rounded-full font-bold shadow-md hover:bg-[#412896] transition-colors disabled:opacity-50"
              disabled={loading}
              type="submit"
            >
              {loading ? '...' : (step === 'phone' ? (isHindi ? 'ओटीपी भेजें' : 'Send OTP') : 'Verify')}
            </button>
          </form>

          <p className="mt-4 text-center text-sm text-[#555]">
            {isHindi ? 'खाता नहीं है? रजिस्टर करें' : "Don't have an account? Register"}
          </p>
        </div>
      </main>
    </div>
  );
};

export default Login;
