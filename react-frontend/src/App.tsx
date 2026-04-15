import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import Login from './pages/Login';
import Home from './pages/Home';
import { LetUsCount } from './pages/games/LetUsCount';
import { Compare } from './pages/games/Compare';
import { GuessTheLetter } from './pages/games/GuessTheLetter';
import { Matching } from './pages/games/Matching';
import { LetUsTellTime } from './pages/games/LetUsTellTime';
import { Result } from './pages/Result';
import { VideoLesson } from './pages/VideoLesson';
import { Profile } from './pages/Profile';
import { About } from './pages/About';
import { Team } from './pages/Team';

function App() {
  return (
    <AuthProvider>
      <Router>
        <Routes>
          <Route path="/" element={<ProtectedRoute><Home /></ProtectedRoute>} />
          <Route path="/login" element={<Login />} />
          <Route path="/result" element={<ProtectedRoute><Result /></ProtectedRoute>} />
          <Route path="/video-lesson" element={<ProtectedRoute><VideoLesson /></ProtectedRoute>} />
          <Route path="/profile" element={<ProtectedRoute><Profile /></ProtectedRoute>} />
          <Route path="/about" element={<ProtectedRoute><About /></ProtectedRoute>} />
          <Route path="/team" element={<ProtectedRoute><Team /></ProtectedRoute>} />
          
          {/* Games */}
          <Route path="/let-us-count" element={<ProtectedRoute><LetUsCount gameTitle="Let us Count" isHindi={false} /></ProtectedRoute>} />
          <Route path="/compare" element={<ProtectedRoute><Compare gameTitle="Compare" isHindi={false} /></ProtectedRoute>} />
          <Route path="/guess-the-letter" element={<ProtectedRoute><GuessTheLetter gameTitle="Guess the Letter" isHindi={false} /></ProtectedRoute>} />
          <Route path="/matching" element={<ProtectedRoute><Matching gameTitle="Name Picture Matching" isHindi={false} /></ProtectedRoute>} />
          <Route path="/number-name-matching" element={<ProtectedRoute><Matching gameTitle="Number Name Matching" isHindi={false} /></ProtectedRoute>} />
          <Route path="/name-number-matching" element={<ProtectedRoute><Matching gameTitle="Name Number Matching" isHindi={false} /></ProtectedRoute>} />
          <Route path="/let-us-tell-time" element={<ProtectedRoute><LetUsTellTime gameTitle="Let us tell Time" isHindi={false} /></ProtectedRoute>} />
        </Routes>
      </Router>
    </AuthProvider>
  );
}

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, loading } = useAuth();
  if (loading) return (
    <div className="flex items-center justify-center min-h-screen">
      <div className="w-12 h-12 border-4 border-[#6541EF] border-t-transparent rounded-full animate-spin" />
    </div>
  );
  if (!user) return <Navigate to="/login" />;
  return <>{children}</>;
}

export default App;
