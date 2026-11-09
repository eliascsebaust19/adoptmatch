import React from 'react';
import { Link } from 'react-router-dom';

export default function Footer() {
  return (
    <footer className="w-full rounded-t-xl bg-surface-container-high dark:bg-inverse-surface border-t border-outline-variant mt-20">
      <div className="w-full px-4 md:px-10 py-12 flex flex-col md:flex-row justify-between items-center gap-6 max-w-container-max mx-auto">
        <div className="flex flex-col items-center md:items-start gap-2">
          <span className="text-2xl font-extrabold text-primary font-headline-md tracking-tight">AdoptMatch</span>
          <p className="text-secondary text-body-sm font-body-sm">
            © {new Date().getFullYear()} AdoptMatch AI. Intelligent Empathy for Pet Adoption.
          </p>
        </div>
        <div className="flex flex-wrap justify-center gap-6 font-body-sm text-body-sm">
          <Link className="text-on-surface-variant hover:text-secondary hover:underline transition-all" to="#">Privacy Policy</Link>
          <Link className="text-on-surface-variant hover:text-secondary hover:underline transition-all" to="#">Terms of Service</Link>
          <Link className="text-on-surface-variant hover:text-secondary hover:underline transition-all" to="#">Cookie Settings</Link>
          <Link className="text-on-surface-variant hover:text-secondary hover:underline transition-all" to="#">Contact Us</Link>
          <Link className="text-on-surface-variant hover:text-secondary hover:underline transition-all" to="#">Careers</Link>
        </div>
      </div>
    </footer>
  );
}
