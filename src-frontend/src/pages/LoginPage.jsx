import React, { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import { Heart, Sparkles, UserCheck, Shield } from 'lucide-react';

export default function LoginPage() {
  const { login } = useAuth();
  const navigate = useNavigate();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      setError('');
      setLoading(true);
      const user = await login(email, password);
      if (user.role === 'SHELTER_STAFF' || user.role === 'ADMIN') {
        navigate('/shelter-dashboard');
      } else {
        navigate('/recommendations');
      }
    } catch (err) {
      setError(err.response?.data?.error || 'Login failed. Check credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="max-w-md mx-auto px-4 py-16">
      <div className="bg-white rounded-3xl p-8 border border-gray-100 shadow-xl space-y-6">
        
        <div className="text-center space-y-2">
          <div className="w-12 h-12 rounded-2xl bg-brand-coral/10 text-brand-coral flex items-center justify-center mx-auto">
            <Heart className="w-6 h-6 fill-brand-coral" />
          </div>
          <h2 className="font-headline font-extrabold text-2xl text-brand-dark">Sign In to AdoptMatch</h2>
          <p className="text-xs text-gray-500">Access your adopter assessment or shelter portal.</p>
        </div>

        {error && (
          <div className="p-3 rounded-xl bg-red-50 text-red-700 text-xs font-bold border border-red-200">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-bold text-gray-700 mb-1">Email Address</label>
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full p-3 rounded-xl border border-gray-300 text-sm font-medium focus:border-brand-coral"
            />
          </div>

          <div>
            <label className="block text-xs font-bold text-gray-700 mb-1">Password</label>
            <input
              type="password"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="w-full p-3 rounded-xl border border-gray-300 text-sm font-medium focus:border-brand-coral"
            />
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3.5 rounded-xl bg-brand-coral text-white font-bold text-sm shadow-md hover:bg-brand-coral-light"
          >
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
        </form>

      </div>
    </div>
  );
}
