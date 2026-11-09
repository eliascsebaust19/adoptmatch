import React from 'react';
import { Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import Footer from './components/Footer';

import LandingPage from './pages/LandingPage';
import AssessmentPage from './pages/AssessmentPage';
import RecommendationsPage from './pages/RecommendationsPage';
import BrowsePetsPage from './pages/BrowsePetsPage';
import PetProfilePage from './pages/PetProfilePage';
import ApplicationPage from './pages/ApplicationPage';
import ShelterDashboard from './pages/ShelterDashboard';
import FosterPage from './pages/FosterPage';
import PostAdoptionPage from './pages/PostAdoptionPage';
import LoginPage from './pages/LoginPage';

export default function App() {
  return (
    <div className="min-h-screen flex flex-col justify-between bg-brand-bg font-sans">
      <div>
        <Navbar />
        <main>
          <Routes>
            <Route path="/" element={<LandingPage />} />
            <Route path="/assessment" element={<AssessmentPage />} />
            <Route path="/recommendations" element={<RecommendationsPage />} />
            <Route path="/pets" element={<BrowsePetsPage />} />
            <Route path="/pets/:id" element={<PetProfilePage />} />
            <Route path="/apply/:petId" element={<ApplicationPage />} />
            <Route path="/shelter-dashboard" element={<ShelterDashboard />} />
            <Route path="/foster" element={<FosterPage />} />
            <Route path="/post-adoption" element={<PostAdoptionPage />} />
            <Route path="/login" element={<LoginPage />} />
          </Routes>
        </main>
      </div>
      <Footer />
    </div>
  );
}
