import React, { useEffect, useState } from 'react';
import { Briefcase, Heart, CheckCircle2, UserCheck, Shield } from 'lucide-react';
import api from '../services/api';

export default function FosterPage() {
  const [fosters, setFosters] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchFosters = async () => {
      try {
        const res = await api.get('/fosters');
        setFosters(res.data);
      } catch (err) {
        console.error('Failed to fetch fosters:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchFosters();
  }, []);

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-8">
      <div className="border-b border-gray-200 pb-6 space-y-2">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-brand-teal/10 text-brand-teal text-xs font-bold uppercase tracking-wider">
          <Briefcase className="w-4 h-4" /> Foster Network Coordination
        </div>
        <h1 className="font-headline font-extrabold text-3xl text-brand-dark">Foster Volunteer Network</h1>
        <p className="text-sm text-gray-600">Coordinate temporary home placements for pets undergoing medical recovery or awaiting adoption.</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {fosters.map(f => (
          <div key={f.id} className="bg-white p-6 rounded-3xl border border-gray-100 shadow-sm space-y-3">
            <div className="flex items-center justify-between">
              <span className="font-headline font-bold text-lg text-brand-dark">{f.name || 'Elena Rostova'}</span>
              <span className="px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-800 text-xs font-bold">
                {f.availability_status || 'AVAILABLE'}
              </span>
            </div>
            <div className="text-xs text-gray-500 space-y-1">
              <p>Capacity: {f.capacity} pets</p>
              <p>Preferences: {f.preferred_species}</p>
              <p>Experience: {f.experience_years} years</p>
            </div>
            <p className="text-xs text-gray-600 italic bg-gray-50 p-3 rounded-xl">"{f.home_notes || 'Spacious home with fenced yard.'}"</p>
          </div>
        ))}
      </div>
    </div>
  );
}
