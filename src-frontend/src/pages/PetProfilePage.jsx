import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import api from '../services/api';

export default function PetProfilePage() {
  const { id } = useParams();
  const [pet, setPet] = useState(null);
  const [loading, setLoading] = useState(true);
  const [isFavorited, setIsFavorited] = useState(false);

  useEffect(() => {
    const fetchPet = async () => {
      try {
        setLoading(true);
        const res = await api.get(`/pets/${id || 1}`);
        setPet(res.data);
      } catch (err) {
        console.error('Failed to fetch pet profile:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchPet();
  }, [id]);

  if (loading) return <div className="text-center py-24 text-on-surface-variant font-medium">Loading pet profile...</div>;

  const currentPet = pet || {
    id: 1,
    name: 'Barnaby',
    breed: 'Golden Retriever Mix',
    age_months: 24,
    gender: 'Male',
    location: 'Seattle, WA',
    description: "Barnaby is a total sweetheart who perfectly balances playful energy with a love for cuddle time. He was found as a stray but has quickly shown that he is eager to please and loves human companionship. He enjoys long walks, playing fetch in the yard, and will happily curl up at your feet while you work. He's incredibly social and makes friends wherever he goes.",
    photos: ['https://lh3.googleusercontent.com/aida-public/AB6AXuBoakciqreo4BsVW5UAXOTPTddrh679A9Q29hUkCx6-voeCdKiDm0NFNFBB3_lpr5UW53bIxCe6r1mu6DIb3LROLCGwEmod3zq_QLxax0jeDeZXVJvOWSCFEu7Ja8PDINQWAnBD8QRVkMxmW3vP0y0WnQL3lkv0R1fxYRquQjgY1MhnEk30NdaFlKSJsAj-60E6Hd7w4Ysu4wcKlQ5l6UCWAgL0ebDufsep52cAwMjV27D6a_SsEjV1']
  };

  const primaryPhoto = (currentPet.photos && currentPet.photos.length > 0)
    ? (typeof currentPet.photos[0] === 'string' ? currentPet.photos[0] : currentPet.photos[0].photo_url)
    : 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=800';

  const formattedAge = currentPet.age_months >= 12
    ? `${Math.floor(currentPet.age_months / 12)} Years Old`
    : `${currentPet.age_months} Months Old`;

  return (
    <main className="flex-grow w-full max-w-container-max mx-auto px-4 md:px-10 py-6 md:py-10 grid grid-cols-1 lg:grid-cols-12 gap-8">
      
      {/* Left Column: Media & Details - Exact Stitch Specs */}
      <div className="lg:col-span-8 flex flex-col gap-6">
        
        {/* Hero Image Section */}
        <div className="relative w-full h-[400px] md:h-[480px] rounded-[24px] overflow-hidden shadow-[0px_4px_20px_rgba(15,61,78,0.05)] bg-surface-container">
          <div
            className="absolute inset-0 bg-cover bg-center w-full h-full"
            style={{ backgroundImage: `url('${primaryPhoto}')` }}
          />
          <div className="absolute inset-0 bg-gradient-to-t from-on-surface/80 via-on-surface/20 to-transparent" />
          
          {/* Hero Content */}
          <div className="absolute bottom-0 left-0 w-full p-8 flex flex-col md:flex-row md:items-end justify-between gap-4">
            <div>
              <h1 className="font-headline font-extrabold text-4xl text-on-primary mb-2">{currentPet.name}</h1>
              <p className="text-sm font-medium text-surface-container flex items-center gap-1.5">
                <span className="material-symbols-outlined text-lg">location_on</span>
                {currentPet.location || 'Seattle, WA'} • {formattedAge} • {currentPet.breed}
              </p>
            </div>

            <button className="bg-surface-container-lowest/20 backdrop-blur-md border border-surface-container-lowest/30 text-on-primary font-bold text-xs px-4 py-2 rounded-full flex items-center gap-2 hover:bg-surface-container-lowest/30 transition-colors w-fit">
              <span className="material-symbols-outlined text-base">share</span>
              Share Profile
            </button>
          </div>
        </div>

        {/* About Section (Bento Card) */}
        <section className="bg-surface-container-lowest rounded-2xl p-8 shadow-[0px_4px_20px_rgba(15,61,78,0.05)] border border-surface-container-low">
          <h2 className="font-headline font-bold text-2xl text-on-surface mb-4">About {currentPet.name}</h2>
          <p className="text-base text-on-surface-variant mb-6 leading-relaxed">
            {currentPet.description}
          </p>

          {/* Personality Tags */}
          <div className="flex flex-wrap gap-3">
            {['Friendly', 'Playful', 'Calm', 'Social', 'Trainable'].map((tag, idx) => (
              <span
                key={idx}
                className={`font-bold text-xs px-4 py-2 rounded-full ${idx === 2 ? 'bg-surface-container-high text-on-surface-variant' : 'bg-secondary text-on-secondary shadow-sm'}`}
              >
                {tag}
              </span>
            ))}
          </div>
        </section>

        {/* Compatibility Section */}
        <section className="bg-surface-container-lowest rounded-2xl p-8 shadow-[0px_4px_20px_rgba(15,61,78,0.05)] border border-surface-container-low">
          <h2 className="font-headline font-bold text-2xl text-on-surface mb-6">Compatibility</h2>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            
            <div className="flex flex-col items-center justify-center p-4 bg-surface rounded-xl border border-surface-variant text-center gap-2">
              <div className="w-12 h-12 rounded-full bg-tertiary-container/20 text-tertiary flex items-center justify-center mb-1">
                <span className="material-symbols-outlined text-2xl" style={{ fontVariationSettings: "'FILL' 1" }}>child_care</span>
              </div>
              <span className="font-bold text-xs text-on-surface">Children</span>
              <span className="text-xs text-tertiary font-bold">Great</span>
            </div>

            <div className="flex flex-col items-center justify-center p-4 bg-surface rounded-xl border border-surface-variant text-center gap-2">
              <div className="w-12 h-12 rounded-full bg-tertiary-container/20 text-tertiary flex items-center justify-center mb-1">
                <span className="material-symbols-outlined text-2xl" style={{ fontVariationSettings: "'FILL' 1" }}>pets</span>
              </div>
              <span className="font-bold text-xs text-on-surface">Other Dogs</span>
              <span className="text-xs text-tertiary font-bold">Friendly</span>
            </div>

            <div className="flex flex-col items-center justify-center p-4 bg-surface rounded-xl border border-surface-variant text-center gap-2">
              <div className="w-12 h-12 rounded-full bg-tertiary-container/20 text-tertiary flex items-center justify-center mb-1">
                <span className="material-symbols-outlined text-2xl" style={{ fontVariationSettings: "'FILL' 1" }}>cruelty_free</span>
              </div>
              <span className="font-bold text-xs text-on-surface">Cats</span>
              <span className="text-xs text-tertiary font-bold">Tolerant</span>
            </div>

            <div className="flex flex-col items-center justify-center p-4 bg-surface rounded-xl border border-surface-variant text-center gap-2">
              <div className="w-12 h-12 rounded-full bg-tertiary-container/20 text-tertiary flex items-center justify-center mb-1">
                <span className="material-symbols-outlined text-2xl" style={{ fontVariationSettings: "'FILL' 1" }}>home</span>
              </div>
              <span className="font-bold text-xs text-on-surface">First-Time</span>
              <span className="text-xs text-tertiary font-bold">Suitable</span>
            </div>

          </div>
        </section>

        {/* Health & Behavior Section */}
        <section className="bg-surface-container-lowest rounded-2xl p-8 shadow-[0px_4px_20px_rgba(15,61,78,0.05)] border border-surface-container-low mb-6">
          <h2 className="font-headline font-bold text-2xl text-on-surface mb-6">Health & Behavior</h2>
          <div className="grid md:grid-cols-2 gap-6">
            <ul className="space-y-4">
              <li className="flex items-start gap-3">
                <span className="material-symbols-outlined text-secondary mt-0.5">vaccines</span>
                <div>
                  <h4 className="font-bold text-xs text-on-surface">Vaccinations up to date</h4>
                  <p className="text-xs text-on-surface-variant">All standard shelter shots completed.</p>
                </div>
              </li>
              <li className="flex items-start gap-3">
                <span className="material-symbols-outlined text-secondary mt-0.5">check_circle</span>
                <div>
                  <h4 className="font-bold text-xs text-on-surface">House Trained</h4>
                  <p className="text-xs text-on-surface-variant">Accident-free in foster home.</p>
                </div>
              </li>
              <li className="flex items-start gap-3">
                <span className="material-symbols-outlined text-secondary mt-0.5">medication</span>
                <div>
                  <h4 className="font-bold text-xs text-on-surface">Neutered</h4>
                  <p className="text-xs text-on-surface-variant">Procedure completed prior to listing.</p>
                </div>
              </li>
            </ul>

            <div className="bg-primary-fixed/30 rounded-2xl p-5 border border-primary-fixed-dim/50 flex items-start gap-4">
              <div className="w-10 h-10 rounded-full bg-primary shrink-0 flex items-center justify-center text-on-primary">
                <span className="material-symbols-outlined">directions_run</span>
              </div>
              <div>
                <h4 className="font-bold text-xs text-on-primary-container mb-1">Energy Needs</h4>
                <p className="text-xs text-on-surface-variant leading-relaxed">
                  {currentPet.name} is a young retriever mix. He requires at least 45-60 minutes of active exercise daily to stay happy and healthy.
                </p>
              </div>
            </div>
          </div>
        </section>

      </div>

      {/* Right Column: AI Match, Shelter Info, CTAs (Sticky) - Exact Stitch Specs */}
      <div className="lg:col-span-4 flex flex-col gap-6 relative">
        <div className="sticky top-24 flex flex-col gap-6">
          
          {/* Precision AI Match Card */}
          <div className="bg-surface-container-lowest rounded-2xl p-6 shadow-[0px_12px_32px_rgba(15,61,78,0.08)] border-t-4 border-tertiary flex flex-col items-center relative overflow-hidden">
            <div className="relative z-10 w-full flex flex-col items-center">
              <h3 className="text-xs font-bold text-tertiary tracking-widest uppercase mb-4">AdoptMatch Precision</h3>
              
              {/* Visual Gauge Ring */}
              <div className="relative w-32 h-32 mb-4 flex items-center justify-center">
                <svg className="w-full h-full transform -rotate-90" viewBox="0 0 100 100">
                  <circle className="text-surface-container-high" cx="50" cy="50" fill="none" r="45" stroke="currentColor" strokeWidth="8"></circle>
                  <circle className="text-tertiary stroke-current" cx="50" cy="50" fill="none" r="45" stroke="currentColor" strokeDasharray="282.7" strokeDashoffset="11.3" strokeWidth="8"></circle>
                </svg>
                <div className="absolute flex flex-col items-center justify-center">
                  <span className="font-headline font-extrabold text-3xl text-on-surface leading-none">96<span className="text-xl">%</span></span>
                </div>
              </div>

              <h2 className="font-headline font-bold text-2xl text-on-surface mb-2">Excellent Match</h2>
              <p className="text-xs text-on-surface-variant text-center mb-6">
                Based on your profile, {currentPet.name} is a near-perfect fit for your lifestyle.
              </p>

              {/* Match Highlights */}
              <div className="w-full space-y-2">
                {['Active house with yard', 'Great with children', 'Matches work-from-home schedule'].map((item, idx) => (
                  <div key={idx} className="flex items-center gap-3 bg-surface p-3 rounded-xl border border-surface-variant text-xs text-on-surface">
                    <span className="material-symbols-outlined text-tertiary text-lg">check_circle</span>
                    <span>{item}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Action CTAs */}
          <div className="flex flex-col gap-3">
            <Link
              to={`/apply/${currentPet.id}`}
              className="w-full bg-primary text-on-primary font-bold text-base py-4 rounded-xl shadow-[0px_4px_20px_rgba(165,59,41,0.2)] hover:bg-primary-fixed-variant hover:shadow-[0px_12px_32px_rgba(165,59,41,0.3)] hover:scale-[1.02] transition-all flex justify-center items-center gap-2"
            >
              Apply to Adopt
              <span className="material-symbols-outlined text-xl">arrow_forward</span>
            </Link>

            <button
              onClick={() => setIsFavorited(!isFavorited)}
              className="w-full bg-surface-container-lowest text-secondary font-bold text-sm py-4 rounded-xl border-2 border-secondary-container hover:bg-secondary-container/20 hover:scale-[1.02] transition-all flex justify-center items-center gap-2"
            >
              <span className="material-symbols-outlined text-lg" style={{ fontVariationSettings: isFavorited ? "'FILL' 1" : "'FILL' 0" }}>
                favorite
              </span>
              {isFavorited ? 'Saved to Favorites' : 'Save to Favorites'}
            </button>
          </div>

          {/* Shelter Info Sidebar */}
          <div className="bg-surface-container-lowest rounded-2xl p-6 shadow-[0px_4px_20px_rgba(15,61,78,0.05)] border border-surface-container-low">
            <h3 className="text-xs font-bold text-on-surface-variant tracking-widest uppercase mb-4">Location</h3>
            <div className="flex items-center gap-4 mb-4">
              <div className="w-12 h-12 rounded-xl bg-surface-container overflow-hidden shrink-0 border border-surface-variant flex items-center justify-center">
                <span className="material-symbols-outlined text-secondary text-2xl">home_work</span>
              </div>
              <div>
                <h4 className="font-bold text-xs text-on-surface">Seattle Animal Haven</h4>
                <p className="text-xs text-on-surface-variant">Seattle, WA 98101</p>
              </div>
            </div>
            <a className="text-secondary font-bold text-xs hover:underline flex items-center gap-1" href="#">
              View Shelter Details
              <span className="material-symbols-outlined text-sm">chevron_right</span>
            </a>
          </div>

        </div>
      </div>

    </main>
  );
}
