<div align="center">
  <img src="https://github.com/user-attachments/assets/a0819fb3-ffe6-458f-b1aa-134dcaa3491b" alt="SpendSmart Logo" width="120"/>
  <h1>SpendSmart</h1>
  <p><strong>Less clutter, more clarity.</strong></p>
  <p>AI-powered receipt tracking and expense intelligence for iOS.</p>

  <a href="https://apps.apple.com/us/app/spendsmart-ai-receipt-tool/id6745190294">
    <img src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/en-us?releaseDate=1747180800" alt="Download on the App Store" width="160" />
  </a>
</div>

---

Snap a photo of your receipts, or just say what you spent, and SpendSmart turns it into a clean dashboard, a spending map, an AI chat, and smart insights. No bank connection needed.

## Project status

I'm no longer actively developing SpendSmart, but the app is live and the code is open source under the MIT license. **Contributions are very welcome.** Fork it, fix something, add a feature, or build on top of it. See [Contributing](#contributing) below to get started.

## Features

| Area | What it does |
|------|--------------|
| **Scanning** | AI receipt scanning (camera, photos, files), batch mode, voice entry ("I spent $12 at Starbucks"), multi-page stitching |
| **Intelligence** | Smart spending insights, AI chat about your expenses, 8 chart types, store-location spending map |
| **Experience** | Shareable spending cards, haptics, animated micro-interactions, 10-step onboarding with an interactive scan demo |

The app uses a freemium model (RevenueCat): a free tier with weekly scan limits, and a Plus tier with unlimited scanning, smart insights, cloud sync, and data export.

## Tech stack

- **App:** Swift + SwiftUI (iOS 18.0+), MVVM architecture
- **Database & Auth:** Supabase (Postgres + Apple Sign-In)
- **Subscriptions:** RevenueCat (StoreKit 2)
- **AI pipeline:** Gemini 2.5 Flash (validation + parsing) and Mistral OCR (text extraction)
- **Backend:** Express.js on Vercel (serverless)

## Getting started

### Requirements

- macOS with **Xcode 16+**
- iOS 18.0+ device or simulator

### Steps

1. **Clone the repo**
   ```bash
   git clone https://github.com/madebyshaurya/SpendSmart.git
   cd SpendSmart
   ```

2. **Create your API keys file** from the template
   ```bash
   cp SpendSmart/App/APIKeys.template.swift.example SpendSmart/App/APIKeys.swift
   ```
   `APIKeys.swift` is gitignored, so your keys never get committed.

3. **Fill in your keys** in `APIKeys.swift`. The template explains where to get each one:

   | Key | Where to get it | Required? |
   |-----|-----------------|-----------|
   | `supabaseURL` / `supabaseAnonKey` | [Supabase dashboard](https://app.supabase.com) → Project Settings → API | Yes (auth + storage) |
   | `revenueCatAPIKey` | [RevenueCat](https://app.revenuecat.com) → project API keys | Yes (subscriptions) |
   | `secretKey` | Your backend's shared secret | For AI features |
   | `productionURL` | Your deployed backend URL | For AI features |
   | `brandfetchAPIKey` | [Brandfetch](https://brandfetch.com) | Optional (store logos) |

4. **Open and run**
   ```bash
   open SpendSmart.xcodeproj
   ```

> [!NOTE]
> **About the backend.** AI receipt scanning, chat, and insights call a small backend service (Express on Vercel using Gemini + Mistral OCR). That backend isn't included in this repo. The app builds, runs, and signs in without it, but you'll need to point `productionURL` (or a local `http://localhost:3000`) at your own backend that implements the same endpoints for AI features to work.

## Project structure

```
SpendSmart/
├── App/            # Entry point, API keys, app constants
├── Core/           # Supabase, backend API, local storage, Keychain
├── Services/       # AI, subscriptions, haptics, insights, batch processing
├── ViewModels/     # MVVM view models
├── Models/         # Receipt, Profile, AppState, ChatChart
├── Views/          # Auth, Dashboard, Scanner, Receipts, Chat, Map,
│                   #   Settings, Subscription, Onboarding, Statistics
├── Components/     # Reusable UI: buttons, cards, toasts, skeletons
├── Charts/         # 8 chart types
├── Extensions/     # Color, Font, Animation, UIImage helpers
└── Illustrations/  # Animated illustrations
```

## Contributing

Pull requests are welcome, whether it's a bug fix, a new chart, a UI polish, or docs.

1. Fork the repo and create a branch: `git checkout -b my-change`
2. Make your change. Match the existing style: SwiftUI + MVVM, and reuse the components in `Components/` and the design tokens in `Extensions/` so things stay visually consistent.
3. Build and run on a simulator to confirm it works.
4. Open a PR with a short description of what you changed and why.

No formal CLA or process. Keep PRs focused and they'll be easier to review.

## License

[MIT](LICENSE) © 2025 Shaurya Gupta

---

<div align="center">
  Built by <a href="https://twitter.com/madebyshaurya">Shaurya Gupta</a>
</div>
