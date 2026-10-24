import React, { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import PetCard from '../components/PetCard';
import api from '../services/api';

export default function RecommendationsPage() {
  const location = useLocation();
  const [recommendations, setRecommendations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [speciesFilter, setSpeciesFilter] = useState('All');
  const [sizeFilter, setSizeFilter] = useState('All');

  useEffect(() => {
    const fetchRecommendations = async () => {
      try {
        setLoading(true);
        const res = await api.get('/matching/recommendations');
        setRecommendations(res.data.recommendations || []);
      } catch (err) {
        console.error('Failed to fetch recommendations:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchRecommendations();
  }, [location.state]);

  const filteredPets = recommendations.filter(pet => {
    if (speciesFilter !== 'All' && pet.species.toLowerCase() !== speciesFilter.toLowerCase()) return false;
    if (sizeFilter !== 'All' && pet.size.toLowerCase() !== sizeFilter.toLowerCase()) return false;
    return true;
  });

  return (
    <div className="space-y-0">
      
      {/* Header Summary Section - Exact Stitch Specs */}
      <header className="max-w-container-max mx-auto px-4 md:px-10 py-8">
        <div className="bg-surface-container-low rounded-2xl p-6 md:p-8 shadow-[0px_4px_20px_rgba(15,61,78,0.05)] border border-outline-variant flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
          <div>
            <h1 className="text-3xl md:text-4xl font-headline font-extrabold text-on-surface mb-2">
              Top Matches for Your Lifestyle
            </h1>
            <p className="text-base text-on-surface-variant font-medium">
              Based on your AI profile: <span className="font-bold text-secondary">Active House with Yard</span>
            </p>
          </div>
          
          <div className="flex items-center gap-2 bg-tertiary-container/20 text-on-tertiary-container px-4 py-2 rounded-full border border-tertiary-container/30">
            <span className="material-symbols-outlined text-secondary text-lg" style={{ fontVariationSettings: "'FILL' 1" }}>auto_awesome</span>
            <span className="font-bold text-xs">AI Precision 98%</span>
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="max-w-container-max mx-auto px-4 md:px-10 pb-16 grid grid-cols-1 md:grid-cols-4 gap-8">
        
        {/* Sidebar Filters - Exact Stitch Specs */}
        <aside className="hidden md:block col-span-1">
          <div className="bg-surface-container-lowest rounded-2xl p-6 shadow-[0px_4px_20px_rgba(15,61,78,0.05)] border border-surface-variant sticky top-28 space-y-6">
            
            <div className="flex items-center gap-2 pb-4 border-b border-surface-variant">
              <span className="material-symbols-outlined text-secondary">tune</span>
              <h2 className="font-bold text-lg text-on-surface font-headline-md">Refine Matches</h2>
            </div>

            <div className="space-y-5">
              {/* SPECIES */}
              <div>
                <h3 className="text-xs font-bold text-on-surface-variant uppercase tracking-widest mb-2">SPECIES</h3>
                <div className="flex flex-wrap gap-2">
                  {['All', 'Dog', 'Cat'].map(sp => (
                    <button
                      key={sp}
                      onClick={() => setSpeciesFilter(sp)}
                      className={`px-3 py-1.5 rounded-full text-xs font-bold transition-colors ${speciesFilter === sp ? 'bg-secondary text-on-secondary' : 'bg-surface-variant text-on-surface hover:bg-surface-container-high'}`}
                    >
                      {sp === 'All' ? 'All Species' : sp + 's'}
                    </button>
                  ))}
                </div>
              </div>

              {/* SIZE */}
              <div>
                <h3 className="text-xs font-bold text-on-surface-variant uppercase tracking-widest mb-2">SIZE</h3>
                <div className="flex flex-wrap gap-2">
                  {['All', 'Small', 'Medium', 'Large'].map(sz => (
                    <button
                      key={sz}
                      onClick={() => setSizeFilter(sz)}
                      className={`px-3 py-1.5 rounded-full text-xs font-bold transition-colors ${sizeFilter === sz ? 'bg-secondary text-on-secondary' : 'bg-surface-variant text-on-surface hover:bg-surface-container-high'}`}
                    >
                      {sz}
                    </button>
                  ))}
                </div>
              </div>
            </div>

          </div>
        </aside>

        {/* Results Grid */}
        <section className="col-span-1 md:col-span-3">
          {loading ? (
            <div className="text-center py-20 text-on-surface-variant font-medium">Calculating AI Compatibility...</div>
          ) : filteredPets.length === 0 ? (
            <div className="text-center py-16 bg-surface-container-lowest rounded-2xl border border-surface-variant">
              <p className="text-on-surface font-semibold mb-2">No pets match the selected filters.</p>
              <button onClick={() => { setSpeciesFilter('All'); setSizeFilter('All'); }} className="text-xs font-bold text-primary underline">Reset Filters</button>
            </div>
          ) : (
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
              {filteredPets.map(pet => (
                <PetCard key={pet.id} pet={pet} />
              ))}
            </div>
          )}
        </section>

      </main>

    </div>
  );
}
