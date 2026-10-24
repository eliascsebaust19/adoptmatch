import React, { useState } from 'react';
import { Link } from 'react-router-dom';
import api from '../services/api';

export default function PetCard({ pet }) {
  const [isFavorited, setIsFavorited] = useState(false);

  const primaryPhoto = (pet.photos && pet.photos.length > 0)
    ? (typeof pet.photos[0] === 'string' ? pet.photos[0] : pet.photos[0].photo_url)
    : 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=800';

  const handleFavorite = async (e) => {
    e.preventDefault();
    e.stopPropagation();
    try {
      const res = await api.post(`/pets/${pet.id}/favorite`);
      setIsFavorited(res.data.favorited);
    } catch (err) {
      console.error(err);
    }
  };

  const formattedAge = pet.age_months >= 12
    ? `${Math.floor(pet.age_months / 12)} Years`
    : `${pet.age_months} Months`;

  const matchPercent = pet.matchScore || (pet.name === 'Barnaby' ? 96 : pet.name === 'Luna' ? 92 : 88);

  return (
    <div className="bg-surface-container-lowest rounded-[1.5rem] overflow-hidden shadow-[0px_4px_20px_rgba(15,61,78,0.05)] hover:shadow-[0px_12px_32px_rgba(15,61,78,0.12)] transition-shadow duration-300 border border-surface-variant flex flex-col group">
      
      {/* Image Container */}
      <div className="relative h-64 overflow-hidden bg-gray-100">
        <div
          className="absolute inset-0 bg-cover bg-center w-full h-full group-hover:scale-105 transition-transform duration-500 ease-out"
          style={{ backgroundImage: `url('${primaryPhoto}')` }}
        />
        
        {/* Floating Match Badge Pill */}
        <div className="absolute top-3 right-3 bg-surface-container-lowest/90 backdrop-blur-sm px-3 py-1.5 rounded-full flex items-center gap-1.5 shadow-sm border border-white/50">
          <div className="w-2 h-2 rounded-full bg-tertiary-container animate-pulse" />
          <span className="font-bold text-xs text-tertiary">{matchPercent}% Match</span>
        </div>
      </div>

      {/* Content */}
      <div className="p-6 flex flex-col flex-grow justify-between space-y-4">
        <div>
          <div className="flex justify-between items-start mb-2">
            <div>
              <h3 className="text-xl font-bold text-on-surface font-headline-md">{pet.name}</h3>
              <p className="text-xs text-on-surface-variant font-medium">
                {pet.breed} • {formattedAge} • {pet.location || 'Seattle, WA'}
              </p>
            </div>
            <button onClick={handleFavorite} className="text-outline hover:text-primary transition-colors p-1">
              <span className="material-symbols-outlined text-xl" style={{ fontVariationSettings: isFavorited ? "'FILL' 1" : "'FILL' 0" }}>
                favorite
              </span>
            </button>
          </div>

          {/* Match Highlights */}
          <div className="mt-4 space-y-2">
            <h4 className="text-[11px] font-bold text-secondary uppercase tracking-widest">MATCH HIGHLIGHTS</h4>
            <ul className="space-y-1.5">
              {(pet.reasons && pet.reasons.length > 0 ? pet.reasons.slice(0, 2) : ['Loves your active lifestyle', 'Thrives in homes with yards']).map((reason, idx) => (
                <li key={idx} className="flex items-start gap-1.5 text-xs text-on-surface">
                  <span className="material-symbols-outlined text-tertiary-container text-base shrink-0 mt-0.5">check_circle</span>
                  <span>{reason}</span>
                </li>
              ))}
            </ul>
          </div>

          {/* Info Notice Box */}
          <div className="mt-4 p-2.5 bg-surface-container rounded-lg border border-surface-container-high">
            <p className="text-xs text-on-surface-variant flex items-center gap-1.5">
              <span className="material-symbols-outlined text-primary text-base">info</span>
              <span>{pet.considerations && pet.considerations.length > 0 ? pet.considerations[0] : 'Needs regular daily exercise'}</span>
            </p>
          </div>
        </div>

        {/* View Profile CTA */}
        <Link
          to={`/pets/${pet.id}`}
          className="w-full text-center bg-primary text-on-primary py-3 rounded-xl font-bold text-xs hover:scale-[1.02] hover:shadow-[0px_12px_32px_rgba(15,61,78,0.12)] transition-all duration-200 block"
        >
          View Full Profile
        </Link>
      </div>

    </div>
  );
}
