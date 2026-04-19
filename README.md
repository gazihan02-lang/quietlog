# QuietLog — Developer Setup Guide

A professional iOS hearing-health app that measures real-time decibel levels, tracks exposure, integrates with Apple Health, and delivers smart alerts — built for iOS 26+ with Swift 6, SwiftData, StoreKit 2, and WidgetKit.

---

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 26 beta or later |
| iOS Deployment Target | 26.0 |
| Swift | 6.0 |
| macOS (host) | Sequoia 15.0+ |

---

## Project Structure

```
Quiet Log/
├── QuietLog/                        # Main app target
│   ├── App/
│   │   └── QuietLogApp.swift        # @main entry point, ModelContainer
│   ├── Models/
│   │   ├── DBZone.swift
│   │   ├── DecibelSample.swift      # @Model
│   │   ├── NoiseSession.swift       # @Model
│   │   ├── AlertEvent.swift         # @Model
│   │   └── UserPreferences.swift    # @AppStorage
│   ├── Services/
│   │   ├── AudioMeterService.swift
│   │   ├── CalibrationService.swift
│   │   ├── SessionService.swift
│   │   ├── HealthKitService.swift
│   │   ├── SubscriptionService.swift
│   │   ├── NotificationService.swift
│   │   ├── HapticsService.swift
│   │   ├── DataService.swift
│   │   └── ReportService.swift
│   ├── Utilities/
│   │   ├── DBCalculator.swift
│   │   └── ExposureCalculator.swift
│   ├── ViewModels/
│   │   ├── LiveMeterViewModel.swift
│   │   ├── HistoryViewModel.swift
│   │   ├── HealthViewModel.swift
│   │   ├── SettingsViewModel.swift
│   │   └── PaywallViewModel.swift
│   ├── Views/
│   │   ├── Components/
│   │   │   ├── DesignSystem.swift
│   │   │   ├── AnimatedWaveformBackground.swift
│   │   │   ├── CircularDBRingView.swift
│   │   │   └── SessionBar.swift
│   │   ├── Onboarding/
│   │   │   ├── OnboardingContainerView.swift
│   │   │   ├── OnboardingWelcomeView.swift
│   │   │   ├── OnboardingProblemView.swift
│   │   │   ├── OnboardingSolutionView.swift
│   │   │   └── OnboardingPermissionsView.swift
│   │   ├── Paywall/
│   │   │   ├── PaywallOnboardingView.swift
│   │   │   └── PaywallContextualView.swift
│   │   ├── LiveMeterView.swift
│   │   ├── HistoryView.swift
│   │   ├── HealthView.swift
│   │   ├── WeeklyReportView.swift
│   │   ├── SettingsView.swift
│   │   └── RootView.swift
│   └── Resources/
│       ├── en.lproj/Localizable.strings
│       ├── tr.lproj/Localizable.strings
│       ├── es.lproj/Localizable.strings
│       ├── de.lproj/Localizable.strings
│       ├── fr.lproj/Localizable.strings
│       ├── PrivacyInfo.xcprivacy
│       └── StoreKit.storekit
└── QuietLogWidgets/                 # Widget extension target
    ├── QuietLogWidgetsBundle.swift
    ├── WidgetProvider.swift
    └── Widgets/
        └── DBWidget.swift
```

---

## Xcode Project Setup (Step by Step)

### 1. Create the Xcode project

1. Open Xcode → **File → New → Project**
2. Choose **App** template under iOS
3. Set:
   - **Product Name**: `QuietLog`
   - **Bundle Identifier**: `com.gazihan.quietlog`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: None (we add SwiftData manually)
4. Save to the `Quiet Log/` folder

### 2. Set Deployment Target

In the project navigator → click the project → **TARGETS → QuietLog → General**:
- **Minimum Deployments**: iOS 26.0

### 3. Add Swift Files

Drag all `.swift` files from the structure above into Xcode, maintaining folder groups. Make sure **"Add to target: QuietLog"** is checked for each main-app file.

### 4. Add Widget Extension Target

1. **File → New → Target** → choose **Widget Extension**
2. Set:
   - **Product Name**: `QuietLogWidgets`
   - **Bundle Identifier**: `com.gazihan.quietlog.widgets`
   - **Include Configuration App Intent**: NO
3. Replace the generated files with the three files in `QuietLogWidgets/`

### 5. Configure App Capabilities

Select **TARGETS → QuietLog → Signing & Capabilities** and add:

| Capability | Notes |
|-----------|-------|
| **HealthKit** | Enable both "Clinical Health Records" OFF, leave default |
| **Background Modes** | Check **Audio, AirPlay, and Picture in Picture** |
| **In-App Purchase** | Auto-enabled when StoreKit products exist |
| **App Groups** | Add `group.com.gazihan.quietlog` |
| **Push Notifications** | Required for UNUserNotificationCenter |

For the **QuietLogWidgets** target, add only:
- **App Groups** → `group.com.gazihan.quietlog`

### 6. Info.plist Keys

Add these keys to **QuietLog/Info.plist** (or the project's Info tab):

```xml
<key>NSMicrophoneUsageDescription</key>
<string>QuietLog uses the microphone to measure ambient noise levels. Audio is never recorded or uploaded.</string>

<key>NSHealthShareUsageDescription</key>
<string>QuietLog reads your Apple Watch headphone audio exposure to provide accurate hearing health data.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>QuietLog writes environmental and headphone audio exposure data to Apple Health.</string>
```

### 7. StoreKit Configuration (Local Testing)

1. In Xcode, select **Product → Scheme → Edit Scheme**
2. Under **Run → Options**, set **StoreKit Configuration** to `QuietLog/Resources/StoreKit.storekit`
3. This enables sandbox purchases without an App Store Connect account during development

### 8. StoreKit Products in App Store Connect

Create these three products in App Store Connect → **Monetization → In-App Purchases**:

| Type | Product ID | Price |
|------|-----------|-------|
| Auto-Renewable Subscription | `com.gazihan.quietlog.pro.monthly` | $4.99/month |
| Auto-Renewable Subscription | `com.gazihan.quietlog.pro.annual` | $29.99/year |
| Non-Consumable | `com.gazihan.quietlog.lifetime` | $49.99 |

Create a **Subscription Group** named `QuietLog Pro` and add both subscription products to it.

Add a **3-day free trial** introductory offer to both subscription products.

### 9. App Group Shared Container

The widget reads dB data written by the main app via:
```swift
UserDefaults(suiteName: "group.com.gazihan.quietlog")
```
Keys written: `widget_current_db`, `widget_peak_db`, `widget_avg_db`, `widget_updated_at`

Make sure both targets have the same App Group identifier registered in your Apple Developer portal under **Certificates, Identifiers & Profiles → Identifiers**.

### 10. Privacy Manifest

The `PrivacyInfo.xcprivacy` file is already in `QuietLog/Resources/`. Add it to the Xcode project and ensure its target membership includes **QuietLog** only (not the widget extension).

---

## Key Architecture Notes

### Swift 6 Concurrency
- All `@Observable` ViewModels and Services are annotated `@MainActor`
- `AudioMeterService` dispatches tap results to `MainActor` via `Task { @MainActor in … }`
- `AVAudioEngine` tap runs on a background audio thread; no UI work is done there

### SwiftData
- `ModelContainer` is created in `QuietLogApp.init()` with schema `[DecibelSample.self, NoiseSession.self, AlertEvent.self]`
- `ModelContext` is passed into `SessionService` and `DataService` via the SwiftUI environment

### Liquid Glass (iOS 26)
- `.glassEffect()` modifier is used on navigation bars and FABs
- `GlassEffectContainer` wraps the tab bar in `RootView`
- Requires Xcode 26 SDK — the project will not compile on earlier Xcode versions

### dB Calculation Pipeline
```
AVAudioEngine tap → Float32 buffer → RMS → dBFS → dBA (+90 offset) → calibration offset → clamped 0–140 dB
```

### Widget Data Flow
```
LiveMeterViewModel.ingestSample()
  → WidgetDataWriter.write(db:peak:avg:)
    → UserDefaults(group.com.gazihan.quietlog)
      → WidgetCenter.shared.reloadAllTimelines()
        → WidgetProvider.getTimeline()
          → DBWidget renders
```

---

## Localization

Five languages are fully localized in `Resources/`:

| Code | Language |
|------|---------|
| `en` | English (base) |
| `tr` | Turkish |
| `es` | Spanish |
| `de` | German |
| `fr` | French |

In Xcode, go to **PROJECT → Info → Localizations** and add all five languages. Xcode will pick up the `.strings` files automatically.

---

## Build & Run

```bash
# Clean build folder (optional)
xcodebuild clean -project "QuietLog.xcodeproj" -scheme QuietLog

# Build for simulator
xcodebuild build \
  -project "QuietLog.xcodeproj" \
  -scheme QuietLog \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro"
```

Or simply press **⌘R** in Xcode after selecting an iOS 26 simulator.

> **Note**: Microphone and HealthKit permissions are not available in the Simulator. Use a physical device running iOS 26 for full feature testing.

---

## Features Summary

| Feature | Free | Pro |
|---------|------|-----|
| Real-time dB meter | ✅ | ✅ |
| Zone colour + advice | ✅ | ✅ |
| Session start/stop | ✅ | ✅ |
| 24-hour history | ✅ | ✅ |
| Unlimited history | ❌ | ✅ |
| Apple Health sync | ❌ | ✅ |
| Smart danger alerts | ❌ | ✅ |
| Headphone tracking | ❌ | ✅ |
| Home/Lock Screen widgets | ❌ | ✅ |
| Weekly hearing report + PDF | ❌ | ✅ |
| CSV / JSON export | ❌ | ✅ |

---

## File Count Summary

| Layer | Files |
|-------|-------|
| App entry + Models | 6 |
| Services | 9 |
| Utilities | 2 |
| ViewModels | 5 |
| UI Components | 4 |
| Onboarding Views | 5 |
| Paywall Views | 2 |
| Main Screen Views | 5 |
| Navigation | 1 |
| Widget Extension | 3 |
| Localization (.strings) | 5 |
| Resources (privacy, storekit) | 2 |
| **Total** | **49** |

---

## Disclaimer

QuietLog is an informational tool. It is **not** a medical device and cannot diagnose, treat, or prevent hearing loss. Decibel measurements via the built-in microphone are approximate (±3 dB) and are affected by phone case, placement, and microphone quality. Do not rely on QuietLog for occupational health compliance (OSHA/NIOSH) assessments. Consult a licensed audiologist for medical advice.
