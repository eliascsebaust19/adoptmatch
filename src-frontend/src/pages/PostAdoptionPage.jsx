import React, { useEffect, useState } from 'react';
import { Activity, BookOpen, CheckCircle2, AlertTriangle, ShieldCheck, Heart, Send } from 'lucide-react';
import api from '../services/api';

export default function PostAdoptionPage() {
  const [resources, setResources] = useState([]);
  const [surveySubmitted, setSurveySubmitted] = useState(false);
  const [riskResult, setRiskResult] = useState(null);
  
  const [surveyData, setSurveyData] = useState({
    survey_period: 'WEEK_1',
    adapting_well: true,
    eating_normally: true,
    sleeping_normally: true,
    behavior_issues: false,
    aggression_noted: false,
    facing_difficulties: false,
    notes: ''
  });

  useEffect(() => {
    const fetchResources = async () => {
      try {
        const res = await api.get('/post-adoption/resources');
        setResources(res.data);
      } catch (err) {
        console.error('Failed to fetch support resources:', err);
      }
    };
    fetchResources();
  }, []);

  const handleSurveySubmit = async (e) => {
    e.preventDefault();
    try {
      const res = await api.post('/post-adoption/survey', surveyData);
      setRiskResult(res.data);
      setSurveySubmitted(true);
    } catch (err) {
      console.error('Failed to submit survey:', err);
    }
  };

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-12">
      
      {/* Header */}
      <div className="border-b border-gray-200 pb-6 space-y-2">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-100 text-emerald-800 text-xs font-bold uppercase tracking-wider">
          <Activity className="w-4 h-4 text-emerald-600" /> Post-Adoption Companion Care
        </div>
        <h1 className="font-headline font-extrabold text-3xl text-brand-dark">Adoption Journey & Support Hub</h1>
        <p className="text-sm text-gray-600">Guided resources and checkup surveys to ensure a smooth, permanent transition for your new companion.</p>
      </div>

      {/* 3-3-3 RULE TIMELINE BANNER */}
      <div className="bg-gradient-to-r from-brand-teal/10 via-white to-brand-mint/10 p-8 rounded-3xl border border-brand-teal/20 space-y-4">
        <h3 className="font-headline font-bold text-xl text-brand-dark flex items-center gap-2">
          <ShieldCheck className="w-5 h-5 text-brand-teal" /> The 3-3-3 Adoption Transition Rule
        </h3>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-white p-5 rounded-2xl border border-gray-100 space-y-2">
            <span className="text-xs font-bold uppercase tracking-wider text-brand-coral">First 3 Days</span>
            <h4 className="font-bold text-sm text-gray-800">Decompressing & Settling</h4>
            <p className="text-xs text-gray-500">Feeling overwhelmed. May hide or refuse food. Give them a quiet, secure space.</p>
          </div>

          <div className="bg-white p-5 rounded-2xl border border-gray-100 space-y-2">
            <span className="text-xs font-bold uppercase tracking-wider text-brand-teal">First 3 Weeks</span>
            <h4 className="font-bold text-sm text-gray-800">Learning Household Routine</h4>
            <p className="text-xs text-gray-500">Starts feeling safe and showing real personality. Establish daily feeding and walk times.</p>
          </div>

          <div className="bg-white p-5 rounded-2xl border border-gray-100 space-y-2">
            <span className="text-xs font-bold uppercase tracking-wider text-emerald-600">First 3 Months</span>
            <h4 className="font-bold text-sm text-gray-800">Complete Trust & Bonding</h4>
            <p className="text-xs text-gray-500">Feels completely at home. Builds lasting emotional bond and routine security.</p>
          </div>
        </div>
      </div>

      {/* SUPPORT ARTICLES */}
      <div className="space-y-4">
        <h3 className="font-headline font-bold text-xl text-brand-dark flex items-center gap-2">
          <BookOpen className="w-5 h-5 text-brand-coral" /> Expert Care Guides
        </h3>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {resources.map((item, idx) => (
            <div key={idx} className="bg-white p-6 rounded-3xl border border-gray-100 shadow-sm space-y-2">
              <span className="text-[10px] font-bold uppercase tracking-wider px-2.5 py-0.5 rounded-full bg-brand-coral/10 text-brand-coral">
                {item.category} • {item.target_period}
              </span>
              <h4 className="font-headline font-bold text-base text-brand-dark">{item.title}</h4>
              <p className="text-xs text-gray-600 leading-relaxed">{item.content}</p>
            </div>
          ))}
        </div>
      </div>

      {/* RETURN-RISK SURVEY MODULE */}
      <div className="bg-white p-8 rounded-3xl border border-gray-100 shadow-xl space-y-6">
        <div className="space-y-1">
          <span className="text-xs font-bold uppercase tracking-wider text-brand-coral">Companion Transition Checkup</span>
          <h3 className="font-headline font-bold text-xl text-brand-dark">How is Your Pet Adapting?</h3>
          <p className="text-xs text-gray-500">Periodic checkup to help identify early concerns and trigger shelter follow-up support.</p>
        </div>

        {surveySubmitted ? (
          <div className="p-6 rounded-2xl bg-gray-50 border border-gray-200 text-center space-y-3">
            <div className="w-12 h-12 rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center mx-auto">
              <CheckCircle2 className="w-6 h-6" />
            </div>
            <h4 className="font-bold text-lg text-brand-dark">Checkup Survey Submitted</h4>
            
            <div className="inline-block px-4 py-2 rounded-xl text-xs font-extrabold bg-emerald-100 text-emerald-800">
              Risk Level Indicator: {riskResult?.risk_level || 'LOW_CONCERN'}
            </div>

            <p className="text-xs text-gray-600 max-w-md mx-auto">
              {riskResult?.risk_level === 'HIGH_CONCERN' 
                ? 'High concern flagged. A shelter specialist will reach out to offer behavioral advice and guidance.'
                : 'Everything appears to be progressing normally. Thank you for taking great care of your pet!'}
            </p>
          </div>
        ) : (
          <form onSubmit={handleSurveySubmit} className="space-y-4">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs font-bold text-gray-700">
              <label className="flex items-center gap-3 p-4 rounded-2xl bg-gray-50 border border-gray-200 cursor-pointer">
                <input
                  type="checkbox"
                  checked={surveyData.adapting_well}
                  onChange={(e) => setSurveyData({ ...surveyData, adapting_well: e.target.checked })}
                  className="w-5 h-5 text-brand-coral rounded"
                />
                <span>Pet is adapting well to new environment</span>
              </label>

              <label className="flex items-center gap-3 p-4 rounded-2xl bg-gray-50 border border-gray-200 cursor-pointer">
                <input
                  type="checkbox"
                  checked={surveyData.eating_normally}
                  onChange={(e) => setSurveyData({ ...surveyData, eating_normally: e.target.checked })}
                  className="w-5 h-5 text-brand-coral rounded"
                />
                <span>Pet is eating and drinking normally</span>
              </label>

              <label className="flex items-center gap-3 p-4 rounded-2xl bg-gray-50 border border-gray-200 cursor-pointer">
                <input
                  type="checkbox"
                  checked={surveyData.behavior_issues}
                  onChange={(e) => setSurveyData({ ...surveyData, behavior_issues: e.target.checked })}
                  className="w-5 h-5 text-brand-coral rounded"
                />
                <span className="text-amber-800">Experiencing behavior or anxiety issues</span>
              </label>

              <label className="flex items-center gap-3 p-4 rounded-2xl bg-gray-50 border border-gray-200 cursor-pointer">
                <input
                  type="checkbox"
                  checked={surveyData.facing_difficulties}
                  onChange={(e) => setSurveyData({ ...surveyData, facing_difficulties: e.target.checked })}
                  className="w-5 h-5 text-brand-coral rounded"
                />
                <span className="text-amber-800">Facing difficulties or considering return</span>
              </label>
            </div>

            <button
              type="submit"
              className="px-6 py-3 rounded-xl bg-brand-coral text-white font-bold text-xs shadow-md hover:bg-brand-coral-light flex items-center gap-2"
            >
              <Send className="w-4 h-4" /> Submit Checkup Survey
            </button>
          </form>
        )}
      </div>

    </div>
  );
}
