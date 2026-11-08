import React, { useState, useEffect } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { CheckCircle2, ChevronRight, ChevronLeft, ShieldCheck, Heart, Clock, FileText, ArrowRight } from 'lucide-react';
import api from '../services/api';
import { useAuth } from '../context/AuthContext';

export default function ApplicationPage() {
  const { petId } = useParams();
  const { user } = useAuth();
  const navigate = useNavigate();
  
  const [pet, setPet] = useState(null);
  const [step, setStep] = useState(1);
  const [submittedApp, setSubmittedApp] = useState(null);
  const [loading, setLoading] = useState(false);
  const [submitError, setSubmitError] = useState(null);

  const [formData, setFormData] = useState({
    housing_details: '',
    experience_details: '',
    reason_for_adoption: '',
    care_plan: '',
    agreement_consent: false
  });

  useEffect(() => {
    const fetchPet = async () => {
      if (!petId) return;
      try {
        const res = await api.get(`/pets/${petId}`);
        setPet(res.data);
      } catch (err) {
        console.error('Failed to fetch pet details:', err);
        setSubmitError('Could not load this pet listing. Please return to the catalog and try again.');
      }
    };
    fetchPet();
  }, [petId]);

  const handleChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };


  const handleSubmit = async (e) => {
    e.preventDefault();
    setSubmitError(null);
    const numericPetId = Number.parseInt(petId, 10);
    if (!Number.isInteger(numericPetId)) {
      setSubmitError('A valid pet listing is required before applying.');
      return;
    }
    if (!formData.agreement_consent) {
      setSubmitError('Please confirm the declaration before submitting.');
      return;
    }
    try {
      setLoading(true);
      const res = await api.post('/applications', { pet_id: numericPetId, ...formData });
      if (!res.data || res.data.id == null) throw new Error('The server did not return an application reference.');
      setSubmittedApp(res.data);
      setStep(5); // Success only after a server acknowledgement.
    } catch (err) {
      console.error('Submission error:', err);
      setSubmitError(err.response?.data?.error || err.message || 'Failed to submit application. Please check connection and try again.');
    } finally {
      setLoading(false);
    }
  };

  if (step === 5 && submittedApp) {
    return (
      <div className="max-w-3xl mx-auto px-4 py-16 text-center space-y-8">
        <div className="w-20 h-20 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mx-auto shadow-xl">
          <CheckCircle2 className="w-10 h-10" />
        </div>

        <div className="space-y-2">
          <span className="text-xs font-bold uppercase tracking-widest text-brand-coral">Application Successfully Received</span>
          <h1 className="font-headline font-extrabold text-4xl text-brand-dark">Adoption Application Submitted!</h1>
          <p className="text-gray-600 text-sm max-w-lg mx-auto">
            Your adoption application for <strong className="text-brand-dark">{pet?.name || 'this pet'}</strong> has been received by the server. Application reference: {submittedApp.reference_no ?? submittedApp.id}.
          </p>
        </div>

        {/* Visual Application Timeline */}
        <div className="bg-white p-8 rounded-3xl border border-gray-100 shadow-xl space-y-6 text-left">
          <h3 className="font-headline font-bold text-lg text-brand-dark border-b border-gray-100 pb-3 flex items-center gap-2">
            <Clock className="w-5 h-5 text-brand-teal" /> Submission Receipt
          </h3>

          <div className="space-y-6 relative before:absolute before:left-4 before:top-3 before:bottom-3 before:w-0.5 before:bg-gray-200">
            
            {/* Stage 1: Submitted */}
            <div className="flex items-start gap-4 relative">
              <div className="w-8 h-8 rounded-full bg-emerald-500 text-white flex items-center justify-center font-bold text-xs shrink-0 shadow-md">✓</div>
              <div>
                <h4 className="font-bold text-sm text-brand-dark">Application Submitted</h4>
                <p className="text-xs text-gray-500">Your application details were securely sent to the shelter team.</p>
              </div>
            </div>

            {/* Stage 2: Under Review */}
            <div className="flex items-start gap-4 relative">
              <div className="w-8 h-8 rounded-full bg-gray-200 text-gray-500 flex items-center justify-center font-bold text-xs shrink-0">2</div>
              <div>
                <h4 className="font-bold text-sm text-gray-400">Under Review</h4>
                <p className="text-xs text-gray-400">Pending shelter review. Current server status: {submittedApp.status || 'submitted'}.</p>
              </div>
            </div>

            {/* Stage 3: Interview */}
            <div className="flex items-start gap-4 relative">
              <div className="w-8 h-8 rounded-full bg-gray-200 text-gray-500 flex items-center justify-center font-bold text-xs shrink-0">3</div>
              <div>
                <h4 className="font-bold text-sm text-gray-400">Shelter Interview / Meet & Greet</h4>
                <p className="text-xs text-gray-400">Scheduled upon initial review approval.</p>
              </div>
            </div>

            {/* Stage 4: Approval & Handover */}
            <div className="flex items-start gap-4 relative">
              <div className="w-8 h-8 rounded-full bg-gray-200 text-gray-500 flex items-center justify-center font-bold text-xs shrink-0">4</div>
              <div>
                <h4 className="font-bold text-sm text-gray-400">Adoption Approval & Support Unlocked</h4>
                <p className="text-xs text-gray-400">Formal adoption completion and post-adoption care activation.</p>
              </div>
            </div>

          </div>
        </div>

        <div className="flex justify-center gap-4">
          <Link to="/post-adoption" className="px-6 py-3 rounded-xl bg-brand-teal text-white font-bold text-xs shadow-md">
            Explore Post-Adoption Resources
          </Link>
          <Link to="/pets" className="px-6 py-3 rounded-xl border border-gray-300 text-gray-700 font-bold text-xs">
            Return to Pet Listings
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto px-4 py-12 space-y-8">
      
      {/* Header */}
      <div className="text-center space-y-2">
        <span className="text-xs font-bold uppercase tracking-widest text-brand-coral">Official Adoption Application</span>
        <h1 className="font-headline font-extrabold text-3xl text-brand-dark">Apply to Adopt {pet?.name || 'this pet'}</h1>
        <p className="text-xs text-gray-500">Step {step} of 4 • Submitted to the listing owner through the API</p>
      </div>

      {/* Form Container */}
      <div className="bg-white rounded-3xl p-8 border border-gray-100 shadow-xl">
        <form onSubmit={step === 4 ? handleSubmit : (e) => e.preventDefault()}>
          
          {/* Step 1: Housing */}
          {step === 1 && (
            <div className="space-y-4">
              <h3 className="font-headline font-bold text-lg text-brand-dark">Step 1: Housing & Living Arrangements</h3>
              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1">Describe your home & living space</label>
                <textarea
                  rows={4}
                  value={formData.housing_details}
                  onChange={(e) => handleChange('housing_details', e.target.value)}
                  className="w-full p-3 rounded-xl border border-gray-300 text-sm focus:border-brand-coral"
                  placeholder="Include house/apartment type, yard fencing, landlord approval status..."
                />
              </div>
            </div>
          )}

          {/* Step 2: Experience */}
          {step === 2 && (
            <div className="space-y-4">
              <h3 className="font-headline font-bold text-lg text-brand-dark">Step 2: Pet Experience & Household</h3>
              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1">Your pet ownership background</label>
                <textarea
                  rows={4}
                  value={formData.experience_details}
                  onChange={(e) => handleChange('experience_details', e.target.value)}
                  className="w-full p-3 rounded-xl border border-gray-300 text-sm focus:border-brand-coral"
                  placeholder="Detail previous pets owned, training background, vet references..."
                />
              </div>
            </div>
          )}

          {/* Step 3: Reason & Care Plan */}
          {step === 3 && (
            <div className="space-y-4">
              <h3 className="font-headline font-bold text-lg text-brand-dark">Step 3: Adoption Reason & Care Plan</h3>
              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1">Reason for adopting {pet?.name || 'this pet'}</label>
                <textarea
                  rows={3}
                  value={formData.reason_for_adoption}
                  onChange={(e) => handleChange('reason_for_adoption', e.target.value)}
                  className="w-full p-3 rounded-xl border border-gray-300 text-sm focus:border-brand-coral"
                />
              </div>
              <div>
                <label className="block text-xs font-bold text-gray-700 mb-1">Daily Care & Exercise Plan</label>
                <textarea
                  rows={3}
                  value={formData.care_plan}
                  onChange={(e) => handleChange('care_plan', e.target.value)}
                  className="w-full p-3 rounded-xl border border-gray-300 text-sm focus:border-brand-coral"
                />
              </div>
            </div>
          )}

          {/* Step 4: Consent */}
          {step === 4 && (
            <div className="space-y-4">
              <h3 className="font-headline font-bold text-lg text-brand-dark">Step 4: Agreement & Authorization</h3>
              <label className="flex items-start gap-3 p-4 rounded-2xl bg-gray-50 border border-gray-200 cursor-pointer">
                <input
                  type="checkbox"
                  checked={formData.agreement_consent}
                  onChange={(e) => handleChange('agreement_consent', e.target.checked)}
                  className="w-5 h-5 text-brand-coral rounded mt-0.5"
                />
                <span className="text-xs text-gray-700 leading-relaxed">
                  I certify that all information provided is accurate and truthful. I agree to allow the shelter staff to contact provided vet references and schedule a home visit if necessary.
                </span>
              </label>
            </div>
          )}

          {submitError && (
            <div className="p-3 bg-red-50 border border-red-200 text-red-700 text-xs rounded-xl font-medium">
              {submitError}
            </div>
          )}

          {/* Controls */}
          <div className="pt-6 border-t border-gray-100 flex items-center justify-between">
            {step > 1 ? (
              <button
                type="button"
                onClick={() => setStep(step - 1)}
                className="px-6 py-2.5 rounded-xl border border-gray-300 text-xs font-bold text-gray-700 hover:bg-gray-50 flex items-center gap-1"
              >
                <ChevronLeft className="w-4 h-4" /> Back
              </button>
            ) : <div />}

            {step < 4 ? (
              <button
                type="button"
                onClick={() => setStep(step + 1)}
                className="px-6 py-2.5 rounded-xl bg-brand-coral text-white text-xs font-bold shadow-md hover:bg-brand-coral-light flex items-center gap-1"
              >
                Next <ChevronRight className="w-4 h-4" />
              </button>
            ) : (
              <button
                type="submit"
                disabled={loading}
                className="px-8 py-3 rounded-xl bg-gradient-to-r from-brand-coral to-brand-coral-light text-white text-xs font-bold shadow-lg flex items-center gap-2"
              >
                {loading ? 'Submitting...' : 'Submit Application'} <Heart className="w-4 h-4 fill-white" />
              </button>
            )}
          </div>

        </form>
      </div>

    </div>
  );
}
