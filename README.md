<div align="center">
  <img src="https://github.com/user-attachments/assets/a0819fb3-ffe6-458f-b1aa-134dcaa3491b" alt="SpendSmart Logo" width="120"/>
  <h1>SpendSmart — Turn Clutter into Clarity</h1>
  <p><strong>AI-Powered Receipt Tracking & Expense Intelligence for iOS</strong></p>

  <a href="https://apps.apple.com/us/app/spendsmart-ai-receipt-tool/id6745190294">
    <img src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/en-us?releaseDate=1747180800" alt="Download on the App Store" width="160" />
  </a>
</div>

---

Snap a photo of your receipts — or just say what you spent — and SpendSmart turns them into a beautiful dashboard, spending map, AI chat, and smart insights. No bank connection needed. Open source.

## Features

**Scanning**
- AI-powered receipt scanning (camera, photos, files)
- Batch mode — scan multiple receipts in one session
- Voice entry — "I spent $12 at Starbucks"
- Multi-page receipt stitching

**Intelligence**
- Smart Spending Insights — alerts when your habits change (Plus)
- AI Chat — ask your expenses questions in natural language
- 8 chart types: trends, heatmaps, category breakdowns, time-of-day
- Store location map with spending clusters

**Experience**
- Shareable spending cards for social media
- Micro-interactions (press feedback, animated numbers, staggered entrances)
- Haptic feedback throughout
- Progressive feature discovery
- 10-step onboarding with interactive scanning demo

**Monetization (Freemium)**
- Free: 5 scans/week, full dashboard, 5 AI chat messages/day
- Plus ($2.99/mo): unlimited scans, Smart Insights, unlimited chat, cloud sync, data export

## Tech Stack

- **iOS:** Swift + SwiftUI (iOS 18.0+)
- **AI Pipeline:** Gemini 2.5 Flash (validation + parsing) + Mistral OCR (text extraction)
- **Backend:** Express.js on Vercel (serverless)
- **Database & Auth:** Supabase (Postgres + Apple Sign-In)
- **Subscriptions:** RevenueCat (StoreKit 2)
- **Image Hosting:** ImgBB
- **Security:** Keychain for auth tokens, per-user rate limiting

## Requirements

- iOS 18.0+
- Xcode 16+

## Setup

1. Clone the repository
   ```bash
   git clone https://github.com/madebyshaurya/SpendSmart.git
   cd SpendSmart
   ```

2. Copy the API keys template
   ```bash
   cp SpendSmart/App/APIKeys.template.swift.example SpendSmart/App/APIKeys.swift
   ```

3. Fill in your API keys in `APIKeys.swift`:
   - Supabase URL and anon key
   - RevenueCat API key
   - Backend secret key
   - Brandfetch API key

4. Open in Xcode and run
   ```bash
   open SpendSmart.xcodeproj
   ```

## Project Structure

```
SpendSmart/
├── App/                  # Entry point, API keys, constants
├── Core/                 # Supabase, backend API, local storage, Keychain
├── Services/             # AI, subscriptions, haptics, insights, batch processing
├── ViewModels/           # MVVM view models (9 files)
├── Models/               # Receipt, Profile, AppState, ChatChart
├── Views/
│   ├── Auth/             # Apple Sign-In
│   ├── Dashboard/        # Dashboard + sections + share cards + insights
│   ├── Scanner/          # Camera, batch, voice entry
│   ├── Receipts/         # List, detail, confirmation, manual entry
│   ├── Chat/             # AI chat with charts
│   ├── Map/              # Store locations
│   ├── Settings/         # Profile, usage, storage, export
│   ├── Subscription/     # Paywall, purchase success
│   ├── Onboarding/       # 10-step flow with paywall
│   └── Statistics/       # Advanced analytics
├── Components/           # Brand3DButton, BrandCard, BrandToast, skeletons
├── Charts/               # 8 chart types
├── Extensions/           # Color, Font, Animation, UIImage
└── Illustrations/        # Animated SVG illustrations
```

## License

MIT

## Support

For help or questions, email [shaurya50211@gmail.com](mailto:shaurya50211@gmail.com)

---

Built by [Shaurya Gupta](https://twitter.com/madebyshaurya)
