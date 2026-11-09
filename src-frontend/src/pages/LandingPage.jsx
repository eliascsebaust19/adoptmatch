import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import PetCard from '../components/PetCard';
import api from '../services/api';

export default function LandingPage() {
  const [featuredPets, setFeaturedPets] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchPets = async () => {
      try {
        const res = await api.get('/pets?status=Available');
        setFeaturedPets(res.data.slice(0, 3));
      } catch (err) {
        console.error('Failed to fetch featured pets:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchPets();
  }, []);

  return (
    <div className="space-y-0">
      
      {/* HERO SECTION - Exact Stitch Layout */}
      <section className="relative pt-16 pb-24 overflow-hidden bg-surface-container-low border-b border-surface-container">
        <div className="max-w-container-max mx-auto px-4 md:px-10 grid lg:grid-cols-2 gap-16 items-center">
          
          {/* Left Column Content */}
          <div className="z-10 max-w-2xl space-y-6">
            <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-secondary-container text-on-secondary-container font-label-bold text-label-bold">
              <span className="material-symbols-outlined text-sm" style={{ fontVariationSettings: "'FILL' 1" }}>favorite</span>
              AI-Powered Matching
            </div>

            <h1 className="text-4xl sm:text-5xl lg:text-6xl font-headline font-extrabold text-on-background tracking-tight leading-[1.15]">
              Find a Pet That <br className="hidden lg:block"/>Fits Your Life.
            </h1>

            <p className="text-lg font-normal text-on-surface-variant max-w-xl leading-relaxed">
              AI-powered pet matching that helps animals find the right home and helps adopters find the right companion. Experience a guided, intelligent journey to your new best friend.
            </p>

            <div className="flex flex-col sm:flex-row gap-4 pt-2">
              <Link
                to="/assessment"
                className="bg-primary text-on-primary font-label-bold text-label-bold px-8 py-4 rounded-xl hover:scale-[1.02] hover:shadow-[0px_12px_32px_rgba(15,61,78,0.12)] transition-all duration-200 flex items-center justify-center gap-2"
              >
                Find My Match
                <span className="material-symbols-outlined text-sm">arrow_forward</span>
              </Link>
              <Link
                to="/pets"
                className="bg-surface text-primary border border-outline font-label-bold text-label-bold px-8 py-4 rounded-xl hover:bg-surface-container-highest transition-all duration-200 flex items-center justify-center"
              >
                Browse Pets
              </Link>
            </div>

            {/* Avatar Social Proof */}
            <div className="pt-6 flex items-center gap-6 text-on-surface-variant text-body-sm font-body-sm">
              <div className="flex -space-x-3">
                <img className="w-10 h-10 rounded-full border-2 border-surface object-cover shadow-sm" src="https://lh3.googleusercontent.com/aida-public/AB6AXuAtl_EUVu75665Pq1sigvgjPyfqTzlBxr-Whhr1zE6D-B9AJarCdA0qzGSGRjkV8bZHZNXl5YQrdtph_vUixYrMkr9P4JTWdtklyh63UNL-fJZWQRRhwaoB2F0xE20LC-T9F-ytuXTGV7jSD2imZKzIyszssbEFWFVuOgGFblCiJQgaJHMnrPzt9fLIWE4o9NOT3Xr2evy7AuLuWM_Ck_5kZg0-8T6bSHObra2zMlWoI3qh117LcK8a" alt="" />
                <img className="w-10 h-10 rounded-full border-2 border-surface object-cover shadow-sm" src="https://lh3.googleusercontent.com/aida-public/AB6AXuBYEgaWM7v3eVdSsJrPtFBtZkVKfYzRybzE3-6yf-QbdUbcQ9wZalEo4Y-DJ4fyN7dfKGZGsus2w5W0HA4EzlWNIRuKDT6-ateIUO7w9AhjxyvWOr9-Uc_l7nxi6Ck-gBOqb2HY0QCNkojjhmzxMuHrVFYMUndcv-mQqeJZQmex-jlC9vwVZ9qFSZ8CMcKR_Ae6XXRq7PG4SpvzZMhPOd5zKtelVLW65l2pwqiFJZPNAs1Ta-Ws6Mo_" alt="" />
                <img className="w-10 h-10 rounded-full border-2 border-surface object-cover shadow-sm" src="https://lh3.googleusercontent.com/aida-public/AB6AXuCT1ZRXktyLFyIH1MNfaMhAr3HQrHiICEU2fR9ysG0zvcbpAqABMEaGEnN_JvI0rK21Ta_8_--9d7sISHljI-sT6NPUqf_wq2dUhmTenQvSsamEppPXbSU3wxh58-N7k7ufcqlTRaPE0IjcLqaA_utsTiMTeSnfPc2LCSMUZXgYXNcJEIAq59ImaAmHlxUtOjeSOaeMDrmw17S8x1Ry5JOXFgzMIyl5e3dPo5gr-vwzS7zkPgV89BzR" alt="" />
              </div>
              <p>Join <strong className="text-on-background font-semibold">10,000+</strong> happy adopters.</p>
            </div>
          </div>

          {/* Right Column Hero Image Showcase */}
          <div className="relative z-10 lg:h-[550px] w-full rounded-[2rem] overflow-hidden shadow-[0px_12px_32px_rgba(15,61,78,0.12)] border border-surface-container">
            <img
              className="w-full h-full object-cover"
              src="https://lh3.googleusercontent.com/aida-public/AB6AXuD2muQ94he6QJ2EISQs3hM6QboJ4DgGxL8frLpCDjaxh0Z5Mgr4dkCENHz_mKvuB6iYJ4MCsNUO0jYqDhqDcQKEZKnq6dmHFLBfgqyf0F2_UoS68W4aqM8fmsPejP4mAE74b3ikkQ12tMP76JMeP4jnTzYX9V6jo7XRnx7FQ1MZY9Ctkf2p4kqvO01rrJ721TsNICHReszFAjELD7YE_p3-H7M5GX0KD142utc9YKu4PioG5oRTje0q"
              alt="Golden Retriever Companion"
            />
            
            {/* Glassmorphism Badge Overlay */}
            <div className="absolute bottom-8 right-8 bg-white/80 backdrop-blur-md border border-white/60 rounded-2xl p-4 flex items-center gap-4 shadow-xl">
              <div className="relative w-12 h-12 flex items-center justify-center">
                <svg className="w-full h-full transform -rotate-90" viewBox="0 0 36 36">
                  <path className="text-surface-variant" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke="currentColor" strokeWidth="3"></path>
                  <path className="text-tertiary" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831" fill="none" stroke="currentColor" strokeDasharray="98, 100" strokeLinecap="round" strokeWidth="3"></path>
                </svg>
                <span className="absolute font-bold text-on-background text-xs">98%</span>
              </div>
              <div>
                <p className="text-[10px] font-bold text-on-surface-variant uppercase tracking-wider">AI Match Score</p>
                <p className="text-sm font-bold text-on-background">Perfect Companion</p>
              </div>
            </div>
          </div>

        </div>
      </section>

      {/* TRUST SECTION - Exact Stitch Specs */}
      <section className="py-16 bg-surface border-b border-surface-container">
        <div className="max-w-container-max mx-auto px-4 md:px-10">
          <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
            <div className="flex flex-col items-center text-center gap-3">
              <div className="w-14 h-14 rounded-2xl bg-secondary-container flex items-center justify-center text-on-secondary-container shadow-sm">
                <span className="material-symbols-outlined text-2xl" style={{ fontVariationSettings: "'FILL' 1" }}>verified</span>
              </div>
              <h3 className="text-base font-bold text-on-background">Verified Shelters</h3>
              <p className="text-xs text-on-surface-variant">Partnered with trusted local rescues.</p>
            </div>

            <div className="flex flex-col items-center text-center gap-3">
              <div className="w-14 h-14 rounded-2xl bg-tertiary-fixed flex items-center justify-center text-on-tertiary-fixed shadow-sm">
                <span className="material-symbols-outlined text-2xl" style={{ fontVariationSettings: "'FILL' 1" }}>smart_toy</span>
              </div>
              <h3 className="text-base font-bold text-on-background">AI Compatibility</h3>
              <p className="text-xs text-on-surface-variant">Data-driven lifestyle matching.</p>
            </div>

            <div className="flex flex-col items-center text-center gap-3">
              <div className="w-14 h-14 rounded-2xl bg-primary-container flex items-center justify-center text-on-primary-container shadow-sm">
                <span className="material-symbols-outlined text-2xl" style={{ fontVariationSettings: "'FILL' 1" }}>support_agent</span>
              </div>
              <h3 className="text-base font-bold text-on-background">Adoption Support</h3>
              <p className="text-xs text-on-surface-variant">Guidance every step of the way.</p>
            </div>

            <div className="flex flex-col items-center text-center gap-3">
              <div className="w-14 h-14 rounded-2xl bg-surface-variant flex items-center justify-center text-on-surface-variant shadow-sm">
                <span className="material-symbols-outlined text-2xl" style={{ fontVariationSettings: "'FILL' 1" }}>diversity_1</span>
              </div>
              <h3 className="text-base font-bold text-on-background">Foster Network</h3>
              <p className="text-xs text-on-surface-variant">Extensive foster care resources.</p>
            </div>
          </div>
        </div>
      </section>

      {/* FEATURED ANIMALS SECTION */}
      <section className="py-20 max-w-container-max mx-auto px-4 md:px-10">
        <div className="flex items-end justify-between mb-12">
          <div>
            <span className="text-xs font-bold uppercase tracking-widest text-primary">Ready for Adoption</span>
            <h2 className="font-headline font-extrabold text-3xl text-on-background mt-1">Featured Pets</h2>
          </div>
          <Link to="/pets" className="text-sm font-bold text-primary hover:underline flex items-center gap-1">
            View All Animals <span className="material-symbols-outlined text-sm">arrow_forward</span>
          </Link>
        </div>

        {loading ? (
          <div className="text-center py-12 text-on-surface-variant">Loading featured pets...</div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
            {featuredPets.map(pet => (
              <PetCard key={pet.id} pet={pet} />
            ))}
          </div>
        )}
      </section>

    </div>
  );
}
