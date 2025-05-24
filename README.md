<div align="center">

  <img src="https://github.com/user-attachments/assets/a0819fb3-ffe6-458f-b1aa-134dcaa3491b" alt="SpendSmart Logo" width="150"/>

  <h1>SpendSmart 💰</h1>

  <p><strong>SpendSmart</strong> is an open-source iOS app that uses AI to make receipt management effortless.<br/>
  Just snap a photo of one or more receipts, and SpendSmart automatically extracts all the key details: store name, location, items, totals, payment method, and more.</p>

  <a href="https://apps.apple.com/us/app/spendsmart-ai-receipt-tool/id6745190294?itscg=30200&itsct=apps_box_badge&mttnsubad=6745190294">
    <img src="https://toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/en-us?releaseDate=1747180800" alt="Download on the App Store" width="200" />
  </a>
</div>


---

## 🚀 Features

- 📸 Capture receipts using your iPhone camera  
- 🤖 AI-powered OCR to extract:
  - Store name
  - Address/location
  - Items and totals
  - Payment method
  - Date & time
- 🧠 Smart parsing logic for messy or unclear receipts  
- 📂 View and manage all your receipts in one place  
- 🔓 100% open source & free to use  

---

## 📱 Screenshots

| Capture | Extract | Manage |
|--------|--------|--------|
| ![Capture](https://github.com/user-attachments/assets/458a19fa-2cc1-483e-abbd-2cd0cf75c99a) | ![Extract](https://github.com/user-attachments/assets/059bc146-7277-4a7f-a6c6-81d88544fb63) | ![Manage](https://github.com/user-attachments/assets/8b4a082a-ba40-46c9-b55c-b7477d0da197) |

> Additional App Store preview screenshots available [here](https://apple.co/43aJhQ5)  

---

## 🛠 Tech Stack

- **iOS**: Swift + SwiftUI  
- **AI/OCR**: Gemini 2.0 Flash
- **Storage & Auth**: Local (without account) + Supabase for sync

---

## 📦 Installation

```bash
git clone https://github.com/yourusername/SpendSmart.git
cd SpendSmart
```

### 🔐 API Setup

Before building, create a new file in the project root called `APIKeys.swift`:

```swift
let supabaseURL = "YOUR_SUPABASE_URL"
let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
let supabaseServiceRoleKey = "YOUR_SUPABASE_SERVICE_ROLE_KEY"
let geminiAPIKey = "YOUR_GEMINI_API_KEY"
let secretKey = "YOUR_SECRET_BACKEND_KEY"
let imgBBAPIKey = "YOUR_IMGBB_API_KEY"
```

You can get these keys from:

- [Supabase](https://supabase.com/) – for the URL, anon key, and service role key  
- [Google Cloud Console](https://console.cloud.google.com/) – to generate your Gemini API key  
- [imgBB](https://api.imgbb.com/) – for image upload API keys  

Do **NOT** commit this file to version control.

---

## ⭐️ Support

If you find SpendSmart useful, consider giving the repo a ⭐️ or sharing it!  
Built solo, bootstrapped, and open source – every bit of support matters.

---

## 👋 Contact

Built and maintained by **Shaurya Gupta**  
- Twitter: [@madebyshaurya](https://twitter.com/madebyshaurya)  
- GitHub: [@madebyshaurya](https://github.com/madebyshaurya)

Have a question or feedback? Open an issue or start a discussion.
