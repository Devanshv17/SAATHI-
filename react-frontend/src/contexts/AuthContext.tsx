import React, { createContext, useContext, useEffect, useState } from 'react';
import type { 
  User, 
  ConfirmationResult,
} from 'firebase/auth';
import { 
  onAuthStateChanged, 
  RecaptchaVerifier, 
  signInWithPhoneNumber, 
  signOut as firebaseSignOut
} from 'firebase/auth';
import { auth } from '../firebase';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  setupRecaptcha: (containerId: string) => void;
  signInWithPhone: (phoneNumber: string) => Promise<void>;
  confirmOTP: (otp: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [confirmationResult, setConfirmationResult] = useState<ConfirmationResult | null>(null);
  const [recaptchaVerifier, setRecaptchaVerifier] = useState<RecaptchaVerifier | null>(null);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setUser(user);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  const setupRecaptcha = (containerId: string) => {
    if (recaptchaVerifier) return;
    const verifier = new RecaptchaVerifier(auth, containerId, {
      size: 'invisible',
    });
    setRecaptchaVerifier(verifier);
  };

  const signInWithPhone = async (phoneNumber: string) => {
    if (!recaptchaVerifier) throw new Error("Recaptcha not initialized");
    const result = await signInWithPhoneNumber(auth, phoneNumber, recaptchaVerifier);
    setConfirmationResult(result);
  };

  const confirmOTP = async (otp: string) => {
    if (!confirmationResult) throw new Error("No confirmation result");
    await confirmationResult.confirm(otp);
  };

  const logout = () => firebaseSignOut(auth);

  return (
    <AuthContext.Provider value={{ user, loading, setupRecaptcha, signInWithPhone, confirmOTP, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
