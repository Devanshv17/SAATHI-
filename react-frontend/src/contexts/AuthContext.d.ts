import React from 'react';
import { User } from 'firebase/auth';
interface AuthContextType {
    user: User | null;
    loading: boolean;
    setupRecaptcha: (containerId: string) => void;
    signInWithPhone: (phoneNumber: string) => Promise<void>;
    confirmOTP: (otp: string) => Promise<void>;
    logout: () => Promise<void>;
}
export declare const AuthProvider: React.FC<{
    children: React.ReactNode;
}>;
export declare const useAuth: () => AuthContextType;
export {};
//# sourceMappingURL=AuthContext.d.ts.map