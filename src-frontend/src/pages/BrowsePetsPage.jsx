import React, { useEffect, useState } from 'react';
import { Search, Filter, Sparkles } from 'lucide-react';
import PetCard from '../components/PetCard';
import api from '../services/api';

export default function BrowsePetsPage() {
  const [pets, setPets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [species, setSpecies] = useState('All');
  const [energy, setEnergy] = useState('All');

  const fetchPets = async () => {
    try {
      setLoading(true);
      const res = await api.get(`/pets?species=${species}&energy=${energy}&search=${search}`);
      setPets(res.data);
    } catch (err) {
      console.error('Failed to fetch pets:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPets();
  }, [species, energy]);

  const handleSearchSubmit = (e) => {
    e.preventDefault();
    fetchPets();
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-8">
      
      {/* Header */}
      <div className="border-b border-gray-200 pb-6 space-y-2">
        <span className="text-xs font-bold uppercase tracking-widest text-brand-coral">Available Animals</span>
        <h1 className="font-headline font-extrabold text-3xl text-brand-dark">Browse Companion Animals</h1>
        <p className="text-sm text-gray-600">Search verified shelter animals ready for adoption across our partner network.</p>
      </div>

      {/* Filter & Search Bar */}
      <form onSubmit={handleSearchSubmit} className="bg-white p-4 rounded-2xl border border-gray-100 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        
        <div className="relative flex-1 w-full">
          <Search className="w-4 h-4 text-gray-400 absolute left-3 top-3.5" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by name, breed, or location..."
            className="w-full pl-10 pr-4 py-2.5 rounded-xl border border-gray-200 text-xs font-medium focus:border-brand-coral"
          />
        </div>

        <div className="flex flex-wrap items-center gap-3 w-full md:w-auto">
          <select
            value={species}
            onChange={(e) => setSpecies(e.target.value)}
            className="p-2.5 rounded-xl border border-gray-200 text-xs font-bold text-gray-700 bg-gray-50"
          >
            <option value="All">All Species</option>
            <option value="Dog">Dogs</option>
            <option value="Cat">Cats</option>
            <option value="Rabbit">Rabbits</option>
          </select>

          <select
            value={energy}
            onChange={(e) => setEnergy(e.target.value)}
            className="p-2.5 rounded-xl border border-gray-200 text-xs font-bold text-gray-700 bg-gray-50"
          >
            <option value="All">All Energy Levels</option>
            <option value="Low">Low Energy</option>
            <option value="Moderate">Moderate Energy</option>
            <option value="High">High Energy</option>
          </select>

          <button
            type="submit"
            className="px-5 py-2.5 rounded-xl bg-brand-coral text-white text-xs font-bold shadow-md hover:bg-brand-coral-light"
          >
            Search
          </button>
        </div>

      </form>

      {/* Pet Grid */}
      {loading ? (
        <div className="text-center py-20 text-gray-500 font-medium">Loading animals...</div>
      ) : pets.length === 0 ? (
        <div className="text-center py-16 bg-white rounded-3xl border border-gray-100">
          <p className="text-gray-600 font-semibold mb-2">No animals matching your search query.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {pets.map(pet => (
            <PetCard key={pet.id} pet={pet} />
          ))}
        </div>
      )}

    </div>
  );
}
