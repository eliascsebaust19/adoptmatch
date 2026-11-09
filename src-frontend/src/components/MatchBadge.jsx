import React from 'react';
import { Sparkles, CheckCircle2, AlertCircle } from 'lucide-react';

export default function MatchBadge({ score, classification, size = 'normal' }) {
  if (score === undefined || score === null) return null;

  let colorClasses = "bg-emerald-100 text-emerald-800 border-emerald-300";
  let icon = <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600" />;

  if (score >= 85) {
    colorClasses = "bg-emerald-50 text-emerald-900 border-emerald-200 shadow-sm shadow-emerald-100";
    icon = <Sparkles className="w-4 h-4 text-emerald-600 animate-pulse" />;
  } else if (score >= 70) {
    colorClasses = "bg-blue-50 text-blue-900 border-blue-200 shadow-sm shadow-blue-100";
    icon = <CheckCircle2 className="w-4 h-4 text-blue-600" />;
  } else if (score >= 50) {
    colorClasses = "bg-amber-50 text-amber-900 border-amber-200";
    icon = <AlertCircle className="w-4 h-4 text-amber-600" />;
  } else {
    colorClasses = "bg-gray-100 text-gray-700 border-gray-200";
    icon = <AlertCircle className="w-4 h-4 text-gray-500" />;
  }

  if (size === 'large') {
    return (
      <div className={`flex items-center gap-3 px-4 py-2.5 rounded-2xl border ${colorClasses}`}>
        {icon}
        <div>
          <span className="font-headline font-extrabold text-xl leading-none">{score}%</span>
          <span className="block text-xs font-bold uppercase tracking-wider opacity-90 mt-0.5">
            {classification || (score >= 85 ? 'Excellent Match' : score >= 70 ? 'Good Match' : 'Fair Match')}
          </span>
        </div>
      </div>
    );
  }

  return (
    <div className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold border ${colorClasses}`}>
      {icon}
      <span>{score}% {classification || (score >= 85 ? 'Match' : 'Match')}</span>
    </div>
  );
}
