import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';
import { useAuth } from '../context/AuthContext';

export default function AssessmentPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);

  const [formData, setFormData] = useState({
    activity_level: 'MODERATE',
    housing_type: 'HOUSE',
    daily_free_time_hours: 3,
    working_schedule: 'HYBRID',
    pet_experience: 'INTERMEDIATE',
    has_yard: true,
    has_children: true,
    has_other_pets: false,
    preferred_species: 'Dog'
  });

  const handleChange = (field, value) => {
    setFormData(prev => ({ ...prev, [field]: value }));
  };

  const handleNext = () => {
    if (step < 4) {
      setStep(step + 1);
    } else {
      handleSubmit();
    }
  };

  const handleSubmit = async () => {
    try {
      setLoading(true);
      if (user) {
        await api.post('/matching/assess', formData).catch(() => {});
      }
      navigate('/recommendations', { state: { assessment: formData } });
    } catch (err) {
      navigate('/recommendations', { state: { assessment: formData } });
    } finally {
      setLoading(false);
    }
  };

  const progressPercent = Math.round((step / 4) * 100);

  return (
    <main className="flex-grow flex flex-col items-center py-12 px-4 md:px-10 max-w-container-max mx-auto w-full">
      
      {/* Progress Bar Area - Exact Stitch Specs */}
      <div className="w-full max-w-3xl mb-10">
        <div className="flex justify-between items-center mb-2">
          <span className="font-label-caps text-label-caps text-secondary uppercase tracking-widest font-bold text-xs">
            Step {step} of 4
          </span>
          <span className="font-label-caps text-label-caps text-on-surface-variant text-xs font-semibold">
            {progressPercent}% Complete
          </span>
        </div>
        <div className="w-full bg-surface-variant rounded-full h-2 overflow-hidden">
          <div
            className="bg-tertiary h-2 rounded-full transition-all duration-500 ease-out"
            style={{ width: `${progressPercent}%` }}
          />
        </div>
      </div>

      {/* Two Column Layout for Form and Info Box */}
      <div className="w-full max-w-5xl grid grid-cols-1 lg:grid-cols-12 gap-10">
        
        {/* Left Column: The Form */}
        <div className="lg:col-span-8 flex flex-col gap-6">
          <div>
            <h1 className="font-headline font-extrabold text-3xl md:text-4xl text-on-background mb-3">
              Tell us about your lifestyle.
            </h1>
            <p className="text-base text-on-surface-variant">
              Let's find a companion that perfectly matches your daily rhythm.
            </p>
          </div>

          {/* Form Container */}
          <form onSubmit={(e) => e.preventDefault()} className="flex flex-col gap-8 bg-surface-container-lowest p-6 md:p-10 rounded-2xl shadow-[0px_4px_20px_rgba(15,61,78,0.05)] border border-surface-container-highest">
            
            {/* STEP 1: ACTIVITY & LIVING SITUATION */}
            {step === 1 && (
              <>
                {/* Question 1: Activity Level (Icon Cards) */}
                <div className="flex flex-col gap-4">
                  <label className="text-xl font-bold text-on-background">How active are you on a typical day?</label>
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                    
                    {/* Option 1 */}
                    <label className="relative cursor-pointer group">
                      <input
                        type="radio"
                        name="activity"
                        value="SEDENTARY"
                        checked={formData.activity_level === 'SEDENTARY'}
                        onChange={() => handleChange('activity_level', 'SEDENTARY')}
                        className="peer sr-only"
                      />
                      <div className="h-full flex flex-col items-center justify-center p-6 bg-surface border-2 border-surface-variant rounded-2xl peer-checked:border-primary peer-checked:bg-primary-fixed/20 hover:border-outline-variant hover:shadow-[0px_12px_32px_rgba(15,61,78,0.08)] transition-all duration-200">
                        <span className="material-symbols-outlined text-[44px] text-secondary mb-2 group-hover:scale-110 transition-transform">weekend</span>
                        <span className="font-bold text-on-surface text-center text-sm">Relaxed</span>
                        <span className="text-xs text-on-surface-variant text-center mt-1">Short walks, mostly indoors</span>
                      </div>
                    </label>

                    {/* Option 2 */}
                    <label className="relative cursor-pointer group">
                      <input
                        type="radio"
                        name="activity"
                        value="MODERATE"
                        checked={formData.activity_level === 'MODERATE'}
                        onChange={() => handleChange('activity_level', 'MODERATE')}
                        className="peer sr-only"
                      />
                      <div className="h-full flex flex-col items-center justify-center p-6 bg-surface border-2 border-surface-variant rounded-2xl peer-checked:border-primary peer-checked:bg-primary-fixed/20 hover:border-outline-variant hover:shadow-[0px_12px_32px_rgba(15,61,78,0.08)] transition-all duration-200">
                        <span className="material-symbols-outlined text-[44px] text-secondary mb-2 group-hover:scale-110 transition-transform">directions_walk</span>
                        <span className="font-bold text-on-surface text-center text-sm">Moderate</span>
                        <span className="text-xs text-on-surface-variant text-center mt-1">Daily walks, some play time</span>
                      </div>
                    </label>

                    {/* Option 3 */}
                    <label className="relative cursor-pointer group">
                      <input
                        type="radio"
                        name="activity"
                        value="ACTIVE"
                        checked={formData.activity_level === 'ACTIVE'}
                        onChange={() => handleChange('activity_level', 'ACTIVE')}
                        className="peer sr-only"
                      />
                      <div className="h-full flex flex-col items-center justify-center p-6 bg-surface border-2 border-surface-variant rounded-2xl peer-checked:border-primary peer-checked:bg-primary-fixed/20 hover:border-outline-variant hover:shadow-[0px_12px_32px_rgba(15,61,78,0.08)] transition-all duration-200">
                        <span className="material-symbols-outlined text-[44px] text-secondary mb-2 group-hover:scale-110 transition-transform">hiking</span>
                        <span className="font-bold text-on-surface text-center text-sm">Highly Active</span>
                        <span className="text-xs text-on-surface-variant text-center mt-1">Running, hiking, intense play</span>
                      </div>
                    </label>

                  </div>
                </div>

                <hr className="border-surface-variant" />

                {/* Question 2: Home Type */}
                <div className="flex flex-col gap-4">
                  <label className="text-xl font-bold text-on-background">Describe your living situation.</label>
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
                    {[
                      { value: 'APARTMENT', icon: 'apartment', label: 'Apartment' },
                      { value: 'HOUSE', icon: 'home', label: 'House (No Yard)' },
                      { value: 'TOWNHOUSE', icon: 'grass', label: 'House (Yard)' },
                      { value: 'CONDO', icon: 'landscape', label: 'Acreage/Farm' }
                    ].map(opt => (
                      <label key={opt.value} className="cursor-pointer">
                        <input
                          type="radio"
                          name="home_type"
                          value={opt.value}
                          checked={formData.housing_type === opt.value}
                          onChange={() => handleChange('housing_type', opt.value)}
                          className="peer sr-only"
                        />
                        <div className="px-3 py-4 text-center rounded-xl border border-surface-variant bg-surface text-on-surface-variant peer-checked:bg-secondary peer-checked:text-on-secondary peer-checked:border-secondary hover:bg-surface-container-high transition-colors">
                          <span className="material-symbols-outlined block mb-1">{opt.icon}</span>
                          <span className="font-bold text-xs">{opt.label}</span>
                        </div>
                      </label>
                    ))}
                  </div>
                </div>

                <hr className="border-surface-variant" />

                {/* Question 3: Free Time Slider */}
                <div className="flex flex-col gap-4">
                  <label className="text-xl font-bold text-on-background" htmlFor="freetime">
                    How much daily free time can you dedicate to a pet?
                  </label>
                  <p className="text-xs text-on-surface-variant">Including walks, feeding, grooming, and dedicated play time.</p>
                  <div className="px-2 pt-2">
                    <input
                      type="range"
                      min="1"
                      max="5"
                      id="freetime"
                      value={formData.daily_free_time_hours}
                      onChange={(e) => handleChange('daily_free_time_hours', parseInt(e.target.value))}
                      className="w-full h-2 bg-surface-variant rounded-lg appearance-none cursor-pointer accent-primary"
                    />
                    <div className="flex justify-between text-xs font-bold text-on-surface-variant mt-3">
                      <span>&lt; 1 hr</span>
                      <span>1-2 hrs</span>
                      <span>3-4 hrs</span>
                      <span>5+ hrs</span>
                    </div>
                  </div>
                </div>
              </>
            )}

            {/* STEP 2: FAMILY & PET PREFERENCES */}
            {step === 2 && (
              <div className="space-y-6">
                <h2 className="text-xl font-bold text-on-background">Family & Preferences</h2>
                
                <div className="space-y-3">
                  <label className="flex items-center gap-3 p-4 rounded-xl border border-surface-variant bg-surface cursor-pointer">
                    <input
                      type="checkbox"
                      checked={formData.has_children}
                      onChange={(e) => handleChange('has_children', e.target.checked)}
                      className="w-5 h-5 text-primary rounded"
                    />
                    <div>
                      <span className="block font-bold text-sm text-on-background">Children at home</span>
                      <span className="text-xs text-on-surface-variant">Filters for patient, kid-friendly companions</span>
                    </div>
                  </label>

                  <label className="flex items-center gap-3 p-4 rounded-xl border border-surface-variant bg-surface cursor-pointer">
                    <input
                      type="checkbox"
                      checked={formData.has_other_pets}
                      onChange={(e) => handleChange('has_other_pets', e.target.checked)}
                      className="w-5 h-5 text-primary rounded"
                    />
                    <div>
                      <span className="block font-bold text-sm text-on-background">Other household pets</span>
                      <span className="text-xs text-on-surface-variant">Filters for dog/cat friendly pets</span>
                    </div>
                  </label>
                </div>
              </div>
            )}

            {/* STEP 3 & 4 (Additional Preferences) */}
            {(step === 3 || step === 4) && (
              <div className="space-y-6">
                <h2 className="text-xl font-bold text-on-background">Companion Preferences</h2>
                <div className="grid grid-cols-3 gap-3">
                  {['Dog', 'Cat', 'Any'].map(sp => (
                    <button
                      key={sp}
                      type="button"
                      onClick={() => handleChange('preferred_species', sp)}
                      className={`p-4 rounded-xl border text-sm font-bold ${formData.preferred_species === sp ? 'bg-primary text-white border-primary' : 'bg-surface border-surface-variant text-on-surface'}`}
                    >
                      {sp}
                    </button>
                  ))}
                </div>
              </div>
            )}

            {/* Navigation Actions */}
            <div className="flex justify-between items-center pt-6 border-t border-surface-variant">
              {step > 1 ? (
                <button
                  type="button"
                  onClick={() => setStep(step - 1)}
                  className="px-6 py-3 rounded-xl border border-outline text-primary font-bold text-sm hover:bg-surface-container-highest transition-colors"
                >
                  Back
                </button>
              ) : <div />}

              <button
                type="button"
                onClick={handleNext}
                disabled={loading}
                className="bg-primary text-on-primary font-label-bold text-base py-3 px-8 rounded-xl shadow-[0px_4px_20px_rgba(15,61,78,0.05)] hover:scale-[1.02] hover:shadow-[0px_12px_32px_rgba(15,61,78,0.12)] hover:bg-surface-tint transition-all duration-200 flex items-center gap-2"
              >
                {step === 4 ? (loading ? 'Analyzing...' : 'See Results') : 'Next Step'}
                <span className="material-symbols-outlined">arrow_forward</span>
              </button>
            </div>

          </form>
        </div>

        {/* Right Column: Info/Why We Ask Box (Sticky) - Exact Stitch Specs */}
        <div className="lg:col-span-4 relative">
          <div className="sticky top-[100px] bg-secondary-container rounded-2xl p-6 flex flex-col gap-4 shadow-[0px_4px_20px_rgba(15,61,78,0.05)]">
            <div className="flex items-center gap-3 text-on-secondary-container">
              <span className="material-symbols-outlined text-[32px] text-secondary" style={{ fontVariationSettings: "'FILL' 1" }}>psychology</span>
              <h3 className="text-lg font-bold">Why we ask this</h3>
            </div>
            <p className="text-sm text-on-secondary-container opacity-90 leading-relaxed">
              Our AI uses these details to ensure your lifestyle beautifully matches a pet's energy and care needs. 
              By understanding your routine, we can filter out matches that might find your home too quiet or too chaotic, setting you both up for a lifelong bond.
            </p>
            <div className="mt-2 rounded-xl overflow-hidden h-32 relative opacity-80 mix-blend-multiply border border-secondary/20">
              <img
                src="https://lh3.googleusercontent.com/aida-public/AB6AXuDcFNYSZoJcwCTtLX_CDxaAcBxYF4I9jTzC8R1Gs08iwgvF5Vx85m353g0Eo5pVNR7P736sYbJxUO8HoJXQSNEafPb_whXThdjL3A_RgjL3NMYVt9MjkA5_VqEeAKk--0pHyd2Vs4Qu7YidZji2cpgr5Zb6z3CsLE6KrC4jkbmSVjalAD3rxDAauMwr2oCWVcjbnY7dE58RqMjVNV6NYIjlG88ar27_jtR76XlQy2kunPsg136S72QB"
                alt="AI Harmony"
                className="object-cover w-full h-full"
              />
            </div>
          </div>
        </div>

      </div>

    </main>
  );
}
