/**
 * AdoptMatch - Subscription Plans Store
 * Dynamic persistence for BDT plans editable by Administrators.
 */

const defaultPlans = [
  {
    id: 'plan-monthly',
    name: '1 Month Supporter',
    nameBn: '১ মাস সাপোর্টার',
    price: 90,
    currency: 'BDT',
    durationDays: 30,
    tag: 'Starter',
    isBestValue: false,
    isActive: true,
    features: [
      'Unlimited adoption inquiries & fast-track application reviews',
      'Priority listing badge for all your rescue & foster posts',
      '100% Ad-free and distraction-free app experience',
      '5 extra high-definition photos per pet profile',
      'Verified Supporter golden badge on your profile'
    ],
    featuresBn: [
      'সীমাহীন অ্যাডপশন রিকোয়েস্ট এবং দ্রুত অ্যাপ্লিকেশন রিভিউ',
      'রেসকিউ ও ফস্টার পোস্টের জন্য প্রায়োরিটি লিস্টিং ব্যাজ',
      '১০০% অ্যাড-মুক্ত ও পরিচ্ছন্ন অ্যাপ এক্সপেরিয়েন্স',
      'প্রতিটি পেট প্রোফাইলে ৫টি অতিরিক্ত এইচডি ছবি',
      'প্রোফাইলে গোল্ডেন ভেরিফাইড সাপোর্টার ব্যাজ'
    ]
  },
  {
    id: 'plan-quarterly',
    name: '3 Months Saver',
    nameBn: '৩ মাস সেভার',
    price: 200,
    currency: 'BDT',
    durationDays: 90,
    tag: 'Most Popular',
    isBestValue: true,
    isActive: true,
    features: [
      'All 1-Month Supporter benefits included',
      'Profile Visitor Analytics ("Who viewed my pet post")',
      'Top search ranking for urgent foster & rescue posts',
      'Direct priority shelter and coordinator hotline',
      '10 extra high-definition photos per pet profile',
      'Save ৳70 compared to monthly plan'
    ],
    featuresBn: [
      '১ মাসের সমস্ত সুবিধাসমূহ অন্তর্ভুক্ত',
      'ভিজিটর অ্যানালিটিক্স ("কে আমার পেট পোস্ট দেখেছে")',
      'সার্চ রেজাল্টে সবার উপরে প্রায়োরিটি লিস্টিং',
      'শেল্টার ও কোঅর্ডিনেটরের সাথে সরাসরি প্রায়োরিটি চ্যাট',
      'প্রতিটি পোস্টের জন্য ১০টি অতিরিক্ত এইচডি ছবি',
      'মাসিক প্ল্যানের চেয়ে ৳৭০ সাশ্রয়ী'
    ]
  },
  {
    id: 'plan-annual',
    name: '1 Year VIP Rescuer',
    nameBn: '১ বছর ভিআইপি রেসকিউয়ার',
    price: 499,
    currency: 'BDT',
    durationDays: 365,
    tag: 'Best Value',
    isBestValue: false,
    isActive: true,
    features: [
      'All 3-Month Saver benefits included',
      'VIP Rescuer Golden Crown badge across app',
      'Unlimited pet listings with unlimited HD photo uploads',
      'Lifetime pet health and vaccination passport PDF export',
      '24/7 dedicated online veterinary advice chat channel',
      'Save ৳580+ (Massive yearly discount)'
    ],
    featuresBn: [
      '৩ মাসের সমস্ত সুবিধাসমূহ অন্তর্ভুক্ত',
      'প্রোফাইলে ও সমস্ত পোস্টে ভিআইপি গোল্ডেন ক্রাউন ব্যাজ',
      'সীমাহীন পেট লিস্টিং এবং আনলিমিটেড এইচডি ছবি',
      'লাইফটাইম মেডিকেল ও ভ্যাকসিন হিস্ট্রি পিডিএফ এক্সপোর্ট',
      '২৪/৭ ডেডিকেটেড অনলাইন ভেটেরিনারি চ্যাট সাপোর্ট',
      '৳৫৮০+ এর বিশাল বাৎসরিক ছাড়'
    ]
  }
];

const store = require('./recordStore')('plans', defaultPlans);
const getAllPlans = () => store.all().filter(p => p.isActive);
const getPlanById = (id) => store.find(id);
const updatePlan = (id, updates) => {
  const current = getPlanById(id);
  if (!current) return null;
  const allowed = new Set(['name','nameBn','price','durationDays','tag','isBestValue','isActive','features','featuresBn']);
  if (!updates || typeof updates !== 'object' || Object.keys(updates).some(key => !allowed.has(key))) {
    throw new Error('Plan update contains unsupported fields.');
  }
  const safe = Object.fromEntries(Object.entries(updates).filter(([key]) => allowed.has(key)));
  const next = { ...current, ...safe, updatedAt: new Date().toISOString() };
  const text = (value, max) => typeof value === 'string' && value.trim().length > 0 && value.length <= max;
  const list = value => Array.isArray(value) && value.length <= 30 && value.every(item => typeof item === 'string' && item.length <= 300);
  if (!Number.isFinite(next.price) || next.price <= 0 || next.price > 100000 ||
      !Number.isInteger(next.durationDays) || next.durationDays < 1 || next.durationDays > 3660 ||
      !text(next.name, 120) || !text(next.nameBn, 160) || !text(next.tag, 80) ||
      typeof next.isBestValue !== 'boolean' || typeof next.isActive !== 'boolean' ||
      !list(next.features) || !list(next.featuresBn)) {
    throw new Error('Plan price, name, duration, flags or features are invalid.');
  }
  return store.update(id, next);
};
module.exports = { getAllPlans, getPlanById, updatePlan };
