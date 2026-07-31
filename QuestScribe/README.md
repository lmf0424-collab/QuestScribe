# QuestScribe

A minimal viable product iOS app for Dungeon Masters. Photograph handwritten D&D prep notes, extract the raw text with Apple's on-device Vision framework, structure it into **Quests**, **Loot**, and **NPCs** using the OpenAI API (gpt-4o-mini, JSON Schema), and view it on a clean mid-game HUD dashboard.

## Requirements

- macOS with **Xcode 15+** (iOS development requires a Mac; this repo was written on Windows)
- iOS **17.0**+ deployment target
- A physical iPhone for camera capture (photo library works everywhere)
- An OpenAI API key from a billing-enabled account (gpt-4o-mini)

## Setup

1. In Xcode: `File ▸ New ▸ Project ▸ iOS ▸ App`. Name it `QuestScribe`, Interface **SwiftUI**, Language **Swift**, Minimum Deployments **iOS 17.0**.
2. Delete the default `ContentView.swift`.
3. Drag the `QuestScribe/` source folder from this repository into the project navigator (keep "Copy items if needed" checked). The folder layout mirrors the Xcode group structure.
4. Build and run. `Vision` and `Security` are system frameworks — `import` is enough, no manual linking required.

## Configuration

- In the app open the **Settings** tab, paste your OpenAI API key, and tap **Save Key**. It is stored in the Keychain.
- If no key is set, tapping **Scan Notes** shows an alert that links to Settings.

## Build without a Mac (GitHub Actions)

1. Push this repo to GitHub (free public repo = free macOS CI minutes).
2. In the repo's **Actions** tab, run the **Build QuestScribe IPA** workflow (it also runs on every push to `main`/`master`).
3. Download the `QuestScribe-unsigned-ipa` artifact from the finished run.
4. On a Windows PC, install the `.ipa` on your iPhone with **Sideloadly** or **AltStore** using your free Apple ID. A free Apple ID re-signs every 7 days; a paid Apple Developer account ($99/yr) enables longer installs and TestFlight/App Store distribution.

The `.xcodeproj` is generated from `project.yml` by XcodeGen during CI, so no Xcode is needed on your machine.

## How it works

1. `DashboardView` (tab bar HUD) shows Active/Completed Quests, Loot & Rewards, and NPCs.
2. Tapping the **Scan Notes** button opens the camera or photo library.
3. `VisionOCRManager` extracts handwriting with `VNRecognizeTextRequest` (`.accurate`, language correction on).
4. `DNDParserService` posts the raw text to `https://api.openai.com/v1/chat/completions` with `response_format` JSON Schema and persists the structured result into SwiftData.
5. `ProcessingOverlayView` shows the pipeline progress: `Scanning Handwriting...` → `Structuring Quests & Loot...` → `Done!`.

## Architecture

```
QuestScribe/
├── QuestScribeApp.swift          App entry, SwiftData model container
├── Models/
│   └── Models.swift              SessionNote, Quest, LootItem, NPC
├── Services/
│   ├── VisionOCRManager.swift    Apple Vision OCR
│   ├── DNDParserService.swift    OpenAI + JSON Schema + persistence
│   ├── KeychainHelper.swift      Secure API key storage
│   └── PaywallManager.swift      StoreKit 2 subscription + 7-day trial
├── ViewModels/
│   └── ScanCoordinator.swift     Scan pipeline state machine
└── Views/
    ├── DashboardView.swift       HUD (Quests / Loot / NPCs / Settings)
    ├── CameraScannerView.swift   Camera + photo library pickers
    ├── ProcessingOverlayView.swift
    ├── PaywallView.swift         Subscription paywall (7-day trial → $12.99/mo)
    └── SettingsView.swift        API key + subscription management
```

## Monetization (paywall)

QuestScribe gates scanning behind **Pro**: a 7-day free trial, then $12.99/month.

- StoreKit 2 (`StoreKit` framework) drives the paywall in `Views/PaywallView.swift` via `SubscriptionStoreView`.
- Product: `com.questscribe.pro.monthly`, subscription group `21653932` (see `QuestScribe.storekit`).
- Sideloaded builds can't process real purchases, so the app also grants a **local 7-day trial** (first-launch date in UserDefaults). On App Store builds the StoreKit transaction takes over.
- In DEBUG builds, Settings shows a "Developer: Unlock Pro" toggle for testing.
- To ship for real: create the subscription in App Store Connect with the same product/group IDs and configure the 7-day introductory offer there.

## Notes

- Swipe a quest to complete/reopen/delete; tap a quest row to toggle its status.
- The OCR → LLM pipeline requires network access and a valid API key.
- The camera capture uses `UIImagePickerController`, which crashes on the Simulator — use the photo library there.
