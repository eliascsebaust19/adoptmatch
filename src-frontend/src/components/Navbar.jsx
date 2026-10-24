import React from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export default function Navbar() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();

  return (
    <nav className="docked full-width top-0 shadow-sm bg-surface dark:bg-inverse-surface z-50 sticky transition-all duration-300" id="navbar">
      <div className="flex justify-between items-center w-full px-4 md:px-10 py-4 max-w-container-max mx-auto z-50">
        
        {/* Brand Logo */}
        <Link to="/" className="flex items-center gap-3">
          <img
            alt="AdoptMatch"
            className="h-9 w-9 rounded-lg object-cover shadow-sm"
            src="https://lh3.googleusercontent.com/aida-public/AB6AXuCIZim63pdxw3sU5HGKpqz7oFKZlbZ_GO1aJD-vhn9mgGiAkCt2f3Um1OOVBg35ChGCBTvEkpIr7TUkW2WoNZ5Vqxo26OPS-zmPam1JxesSmCAET-Snh3Ro8KBDhrVWHHMnauEda18uECMBSXHKIgim_zFnpBfquTYlBhi5d2X_jLAYlAGzkBg28tXzEvcwk092VobtjFx_9BWcPeI2e8upJ-yx09ymsLNrygMRDC_TMira_iuvAcce"
          />
          <span className="text-2xl font-extrabold text-primary dark:text-inverse-primary tracking-tight font-headline-md">
            AdoptMatch
          </span>
        </Link>

        {/* Navigation Links */}
        <div className="hidden lg:flex items-center gap-8 font-body-md text-body-md text-on-surface-variant font-medium">
          <Link className="hover:text-primary transition-colors cursor-pointer hover:scale-[1.02] active:scale-95 transition-all" to="/pets">
            Find a Pet
          </Link>
          <Link className="hover:text-primary transition-colors cursor-pointer hover:scale-[1.02] active:scale-95 transition-all" to="/assessment">
            AI Match
          </Link>
          <Link className="hover:text-primary transition-colors cursor-pointer hover:scale-[1.02] active:scale-95 transition-all" to="/recommendations">
            Your Matches
          </Link>
          <Link className="hover:text-primary transition-colors cursor-pointer hover:scale-[1.02] active:scale-95 transition-all" to="/shelter-dashboard">
            Shelters
          </Link>
          <Link className="hover:text-primary transition-colors cursor-pointer hover:scale-[1.02] active:scale-95 transition-all" to="/post-adoption">
            Adoption Support
          </Link>
        </div>

        {/* Auth Buttons */}
        <div className="flex items-center gap-4">
          {user ? (
            <div className="flex items-center gap-3">
              <span className="text-sm font-semibold text-on-background bg-surface-container px-3 py-1.5 rounded-xl border border-outline-variant">
                {user.name} ({user.role})
              </span>
              <button
                onClick={() => { logout(); navigate('/'); }}
                className="text-error font-label-bold text-sm hover:underline"
              >
                Logout
              </button>
            </div>
          ) : (
            <div className="flex items-center gap-3">
              <Link to="/login" className="hidden sm:block text-on-surface-variant hover:text-primary font-label-bold text-label-bold transition-colors px-3 py-2">
                Login
              </Link>
              <Link to="/assessment" className="bg-primary text-on-primary font-label-bold text-label-bold px-6 py-2.5 rounded-xl hover:scale-[1.02] hover:shadow-[0px_12px_32px_rgba(15,61,78,0.12)] transition-all duration-200 active:scale-95">
                Get Started
              </Link>
            </div>
          )}
        </div>

      </div>
    </nav>
  );
}
