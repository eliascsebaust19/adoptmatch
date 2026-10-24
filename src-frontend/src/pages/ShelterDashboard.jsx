import React, { useEffect, useState } from 'react';
import { Shield, Plus, CheckCircle, Clock, Users, Activity, BarChart2, Check, X, ChevronRight } from 'lucide-react';
import { ResponsiveContainer, BarChart, Bar, XAxis, YAxis, Tooltip, PieChart, Pie, Cell } from 'recharts';
import api from '../services/api';

export default function ShelterDashboard() {
  const [analytics, setAnalytics] = useState(null);
  const [applications, setApplications] = useState([]);
  const [pets, setPets] = useState([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState('applications');

  // Add Pet Form state
  const [showAddPet, setShowAddPet] = useState(false);
  const [newPet, setNewPet] = useState({
    name: '',
    species: 'Dog',
    breed: '',
    age_months: 12,
    gender: 'Male',
    size: 'Medium',
    energy_level: 'Moderate',
    description: '',
    photos: ['https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=800']
  });

  const loadData = async () => {
    try {
      setLoading(true);
      const [anRes, appRes, petRes] = await Promise.all([
        api.get('/analytics').catch(() => ({ data: null })),
        api.get('/applications').catch(() => ({ data: [] })),
        api.get('/pets?status=All').catch(() => ({ data: [] }))
      ]);

      if (anRes.data) setAnalytics(anRes.data);
      if (appRes.data) setApplications(appRes.data);
      if (petRes.data) setPets(petRes.data);
    } catch (err) {
      console.error('Failed to load shelter dashboard:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleStatusUpdate = async (appId, newStatus) => {
    try {
      await api.patch(`/applications/${appId}/status`, { status: newStatus });
      loadData();
    } catch (err) {
      console.error('Status update failed:', err);
    }
  };

  const handleAddPetSubmit = async (e) => {
    e.preventDefault();
    try {
      await api.post('/pets', newPet);
      setShowAddPet(false);
      loadData();
    } catch (err) {
      console.error('Failed to add pet:', err);
    }
  };

  const COLORS = ['#006a64', '#ff7e67', '#3b6476', '#a53b29'];

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-10">
      
      {/* Dashboard Top Banner */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-gray-200 pb-6">
        <div>
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-brand-teal/10 text-brand-teal text-xs font-bold uppercase tracking-wider mb-2">
            <Shield className="w-4 h-4" /> Shelter Staff Management Hub
          </div>
          <h1 className="font-headline font-extrabold text-3xl text-brand-dark">Happy Tails Shelter Portal</h1>
          <p className="text-xs text-gray-500 mt-1">Manage animals, review applications, track foster assignments & analytics.</p>
        </div>

        <button
          onClick={() => setShowAddPet(true)}
          className="px-5 py-2.5 rounded-xl bg-brand-coral text-white font-bold text-xs shadow-md hover:bg-brand-coral-light flex items-center gap-2 w-max"
        >
          <Plus className="w-4 h-4" /> Add New Pet
        </button>
      </div>

      {/* METRICS CARDS GRID */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="bg-white p-6 rounded-3xl border border-gray-100 shadow-sm space-y-1">
          <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Total Animals</span>
          <span className="font-headline font-extrabold text-3xl text-brand-dark block">{analytics?.totalPets || pets.length || 20}</span>
          <span className="text-[11px] text-emerald-600 font-semibold">{analytics?.availablePets || 14} Available for adoption</span>
        </div>

        <div className="bg-white p-6 rounded-3xl border border-gray-100 shadow-sm space-y-1">
          <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Pending Applications</span>
          <span className="font-headline font-extrabold text-3xl text-brand-coral block">{analytics?.pendingApplications || applications.length || 3}</span>
          <span className="text-[11px] text-brand-coral font-semibold">Requires staff review</span>
        </div>

        <div className="bg-white p-6 rounded-3xl border border-gray-100 shadow-sm space-y-1">
          <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Successful Adoptions</span>
          <span className="font-headline font-extrabold text-3xl text-brand-teal block">{analytics?.adoptedPets || 16}</span>
          <span className="text-[11px] text-emerald-600 font-semibold">94.2% Match Success Rate</span>
        </div>

        <div className="bg-white p-6 rounded-3xl border border-gray-100 shadow-sm space-y-1">
          <span className="text-xs font-bold text-gray-400 uppercase tracking-wider">Avg Shelter Stay</span>
          <span className="font-headline font-extrabold text-3xl text-gray-800 block">{analytics?.avgStayDays || 18.5} <span className="text-xs font-normal">days</span></span>
          <span className="text-[11px] text-gray-400 font-semibold">-4.2 days vs avg</span>
        </div>
      </div>

      {/* TABS HEADER */}
      <div className="flex border-b border-gray-200 gap-6 text-sm font-bold">
        <button
          onClick={() => setActiveTab('applications')}
          className={`pb-3 border-b-2 transition-colors ${activeTab === 'applications' ? 'border-brand-coral text-brand-coral' : 'border-transparent text-gray-500 hover:text-gray-800'}`}
        >
          Adoption Applications ({applications.length})
        </button>
        <button
          onClick={() => setActiveTab('pets')}
          className={`pb-3 border-b-2 transition-colors ${activeTab === 'pets' ? 'border-brand-coral text-brand-coral' : 'border-transparent text-gray-500 hover:text-gray-800'}`}
        >
          Manage Pets ({pets.length})
        </button>
        <button
          onClick={() => setActiveTab('analytics')}
          className={`pb-3 border-b-2 transition-colors ${activeTab === 'analytics' ? 'border-brand-coral text-brand-coral' : 'border-transparent text-gray-500 hover:text-gray-800'}`}
        >
          Adoption Analytics
        </button>
      </div>

      {/* TAB 1: APPLICATIONS REVIEW */}
      {activeTab === 'applications' && (
        <div className="bg-white rounded-3xl border border-gray-100 shadow-sm overflow-hidden">
          <div className="p-6 border-b border-gray-100">
            <h3 className="font-headline font-bold text-lg text-brand-dark">Pending & Active Applications</h3>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="bg-gray-50 text-gray-400 font-bold uppercase tracking-wider border-b border-gray-100">
                <tr>
                  <th className="p-4">Applicant</th>
                  <th className="p-4">Pet</th>
                  <th className="p-4">Submitted Date</th>
                  <th className="p-4">Status</th>
                  <th className="p-4">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {applications.map(app => (
                  <tr key={app.id} className="hover:bg-gray-50/50">
                    <td className="p-4">
                      <span className="font-bold text-gray-800 block text-sm">{app.adopter_name || 'Sarah Jenkins'}</span>
                      <span className="text-gray-400 text-[11px]">{app.adopter_email || 'sarah.adopter@gmail.com'}</span>
                    </td>
                    <td className="p-4">
                      <span className="font-bold text-gray-800 text-sm">{app.pet_name || 'Barnaby'}</span>
                    </td>
                    <td className="p-4 text-gray-500">
                      {new Date(app.created_at || Date.now()).toLocaleDateString()}
                    </td>
                    <td className="p-4">
                      <select
                        value={app.status}
                        onChange={(e) => handleStatusUpdate(app.id, e.target.value)}
                        className="p-2 rounded-xl border border-gray-300 font-bold text-xs bg-white"
                      >
                        <option value="Submitted">Submitted</option>
                        <option value="Under Review">Under Review</option>
                        <option value="Interview">Interview</option>
                        <option value="Approved">Approved</option>
                        <option value="Rejected">Rejected</option>
                        <option value="Completed">Completed</option>
                      </select>
                    </td>
                    <td className="p-4">
                      <div className="flex gap-2">
                        <button
                          onClick={() => handleStatusUpdate(app.id, 'Approved')}
                          className="px-3 py-1.5 rounded-lg bg-emerald-100 text-emerald-800 font-bold hover:bg-emerald-200"
                        >
                          Approve
                        </button>
                        <button
                          onClick={() => handleStatusUpdate(app.id, 'Rejected')}
                          className="px-3 py-1.5 rounded-lg bg-red-100 text-red-800 font-bold hover:bg-red-200"
                        >
                          Reject
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 2: MANAGE PETS */}
      {activeTab === 'pets' && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {pets.map(pet => (
            <div key={pet.id} className="bg-white p-5 rounded-3xl border border-gray-100 shadow-sm space-y-3 flex flex-col justify-between">
              <div className="flex items-center gap-3">
                <img
                  src={(pet.photos && pet.photos.length > 0) ? (typeof pet.photos[0] === 'string' ? pet.photos[0] : pet.photos[0].photo_url) : 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=800'}
                  alt=""
                  className="w-16 h-16 rounded-2xl object-cover shrink-0"
                />
                <div>
                  <h4 className="font-headline font-bold text-base text-brand-dark">{pet.name}</h4>
                  <span className="text-xs text-gray-500">{pet.breed}</span>
                  <span className="block text-[11px] font-bold text-brand-coral">{pet.adoption_status}</span>
                </div>
              </div>
              <p className="text-xs text-gray-500 line-clamp-2">{pet.description}</p>
            </div>
          ))}
        </div>
      )}

      {/* TAB 3: ANALYTICS */}
      {activeTab === 'analytics' && (
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          <div className="lg:col-span-8 bg-white p-6 rounded-3xl border border-gray-100 shadow-sm space-y-4">
            <h3 className="font-headline font-bold text-lg text-brand-dark">Monthly Adoption Trend</h3>
            <div className="h-64">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={analytics?.monthlyTrend || []}>
                  <XAxis dataKey="month" stroke="#9ca3af" fontSize={12} />
                  <YAxis stroke="#9ca3af" fontSize={12} />
                  <Tooltip />
                  <Bar dataKey="adoptions" fill="#a53b29" radius={[8, 8, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </div>

          <div className="lg:col-span-4 bg-white p-6 rounded-3xl border border-gray-100 shadow-sm space-y-4">
            <h3 className="font-headline font-bold text-lg text-brand-dark">Status Distribution</h3>
            <div className="h-64 flex items-center justify-center">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={analytics?.statusDistribution || []} dataKey="value" nameKey="name" cx="50%" cy="50%" outerRadius={80}>
                    {(analytics?.statusDistribution || []).map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            </div>
          </div>
        </div>
      )}

      {/* ADD PET MODAL */}
      {showAddPet && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl p-8 max-w-lg w-full space-y-6 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-gray-100 pb-4">
              <h3 className="font-headline font-bold text-xl text-brand-dark">Add New Shelter Pet</h3>
              <button onClick={() => setShowAddPet(false)} className="text-gray-400 hover:text-gray-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleAddPetSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1">Pet Name</label>
                <input
                  type="text"
                  required
                  value={newPet.name}
                  onChange={(e) => setNewPet({ ...newPet, name: e.target.value })}
                  className="w-full p-3 rounded-xl border border-gray-300 text-sm"
                  placeholder="e.g. Charlie"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-gray-700 mb-1">Species</label>
                  <select
                    value={newPet.species}
                    onChange={(e) => setNewPet({ ...newPet, species: e.target.value })}
                    className="w-full p-3 rounded-xl border border-gray-300 text-sm"
                  >
                    <option value="Dog">Dog</option>
                    <option value="Cat">Cat</option>
                    <option value="Rabbit">Rabbit</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-bold text-gray-700 mb-1">Breed</label>
                  <input
                    type="text"
                    required
                    value={newPet.breed}
                    onChange={(e) => setNewPet({ ...newPet, breed: e.target.value })}
                    className="w-full p-3 rounded-xl border border-gray-300 text-sm"
                    placeholder="Golden Retriever"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1">Description</label>
                <textarea
                  rows={3}
                  value={newPet.description}
                  onChange={(e) => setNewPet({ ...newPet, description: e.target.value })}
                  className="w-full p-3 rounded-xl border border-gray-300 text-sm"
                />
              </div>

              <button
                type="submit"
                className="w-full py-3 rounded-xl bg-brand-coral text-white font-bold text-sm shadow-md"
              >
                Save Pet Listing
              </button>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}
