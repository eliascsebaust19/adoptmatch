-- Seed data that is safe to ship: the plan catalogue.
--
-- Demo listings, shelter accounts and the first admin are created by
-- `scripts/bootstrap-admin.mjs` and `scripts/seed-demo.mjs`, both of which talk
-- to the API with the service role so the auth triggers and guards run.

insert into public.subscription_plans
  (id, name, name_bn, price, currency, duration_days, tag, is_best_value, is_active, features, features_bn)
values
  (
    'plan-monthly',
    '1 Month Supporter',
    '১ মাস সাপোর্টার',
    90.00,
    'BDT',
    30,
    'Starter',
    false,
    true,
    array[
      'Unlimited adoption inquiries',
      'Priority listing badge',
      'Ad-free experience',
      '5 extra HD photos per listing',
      'Verified Supporter badge'
    ],
    array[
      'সীমাহীন অ্যাডপশন রিকোয়েস্ট',
      'প্রায়োরিটি লিস্টিং ব্যাজ',
      '১০০% অ্যাড-মুক্ত অভিজ্ঞতা',
      'প্রতিটি লিস্টিংয়ে ৫টি অতিরিক্ত এইচডি ছবি',
      'ভেরিফাইড সাপোর্টার ব্যাজ'
    ]
  ),
  (
    'plan-quarterly',
    '3 Months Saver',
    '৩ মাস সেভার',
    200.00,
    'BDT',
    90,
    'Most Popular',
    true,
    true,
    array[
      'All 1-Month benefits',
      'Profile visitor analytics',
      'Top search ranking for urgent rescues',
      'Priority shelter hotline',
      '10 extra HD photos per listing',
      'Save ৳70 vs monthly'
    ],
    array[
      '১ মাসের সব সুবিধা',
      'প্রোফাইল ভিজিটর অ্যানালিটিক্স',
      'আর্জেন্ট রেসকিউ পোস্টে টপ র্যাংকিং',
      'প্রায়োরিটি শেল্টার হটলাইন',
      'প্রতিটি লিস্টিংয়ে ১০টি অতিরিক্ত এইচডি ছবি',
      'মাসিকের চেয়ে ৳৭০ সাশ্রয়'
    ]
  ),
  (
    'plan-annual',
    '1 Year VIP Rescuer',
    '১ বছর ভিআইপি রেসকিউয়ার',
    499.00,
    'BDT',
    365,
    'Best Value',
    false,
    true,
    array[
      'All 3-Month benefits',
      'VIP Rescuer crown badge',
      'Unlimited listings and photos',
      'Health passport PDF export',
      '24/7 vet advice channel',
      'Save ৳580+'
    ],
    array[
      '৩ মাসের সব সুবিধা',
      'ভিআইপি রেসকিউয়ার ক্রাউন ব্যাজ',
      'আনলিমিটেড লিস্টিং ও ছবি',
      'হেলথ পাসপোর্ট পিডিএফ এক্সপোর্ট',
      '২৪/৭ ভেট অ্যাডভাইস চ্যানেল',
      '৳৫৮০+ সাশ্রয়'
    ]
  )
on conflict (id) do update
  set name = excluded.name,
      name_bn = excluded.name_bn,
      price = excluded.price,
      currency = excluded.currency,
      duration_days = excluded.duration_days,
      tag = excluded.tag,
      is_best_value = excluded.is_best_value,
      is_active = excluded.is_active,
      features = excluded.features,
      features_bn = excluded.features_bn;
