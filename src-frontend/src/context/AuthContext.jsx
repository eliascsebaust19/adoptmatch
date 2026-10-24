import React, { createContext, useContext, useState, useEffect } from 'react';
import api from '../services/api';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const initAuth = async () => {
      const token = localStorage.getItem('adoptmatch_token');
      if (token) {
        try {
          const res = await api.get('/auth/me');
          setUser(res.data);
        } catch (err) {
          console.warn('Token expired or invalid');
          localStorage.removeItem('adoptmatch_token');
        }
      }
      setLoading(false);
    };
    initAuth();
  }, []);

  const login = async (email, password) => {
    const res = await api.post('/auth/login', { email, password });
    const { token, user } = res.data;
    localStorage.setItem('adoptmatch_token', token);
    setUser(user);
    return user;
  };

  const register = async (name, email, password, role, phone) => {
    const res = await api.post('/auth/register', { name, email, password, role, phone });
    const { token, user } = res.data;
    localStorage.setItem('adoptmatch_token', token);
    setUser(user);
    return user;
  };

  const logout = () => {
    localStorage.removeItem('adoptmatch_token');
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, loading, login, register, logout }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => useContext(AuthContext);
