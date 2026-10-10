# Yeetcard iOS App

Yeetcard is an iOS app that keeps all your loyalty, membership, and rewards cards in one
private place on your device — so you can leave the plastic at home. Scan a barcode once,
then pull it up full-screen at checkout with the brightness boosted so it always scans.
Everything stays on the device: no account, no sign-up, no tracking, no server.

## Technical Stack

- **Platform:** iOS 26.1+
- **Language:** Swift
- **UI Framework:** SwiftUI
- **Architecture:** MVVM (Model-View-ViewModel)
- **Data Persistence:** SwiftData (local only, no cloud sync)
- **Authentication:** Face ID / Touch ID with device-passcode fallback (LocalAuthentication)

## Core Features

### Card Scanning
Scan barcodes and QR codes with the camera, with real-time detection via Apple's Vision
framework. Supported formats: QR Code, Micro QR, Code 128, Code 39, Code 93, Codabar,
Interleaved 2 of 5 / ITF-14, EAN-13, EAN-8, UPC-A, UPC-E, GS1 DataBar, MSI Plessey, PDF417,
MicroPDF417, Aztec, and Data Matrix. Auto-capture triggers when a barcode stays in view for about
a second; manual capture is always available.

### Manual Entry
Fallback for damaged or hard-to-scan cards. Type the barcode number and pick the format;
input is validated per format. A clean, scannable barcode image is generated with Core Image
so the card still works from the app.

### Photo Import
Import an existing card image straight from your photo library (via `PhotosUI` / `PHPicker`).

### Full-Screen Display
Pull up any card full-screen on a black background with the screen **brightness boosted
automatically**, so the register scans it on the first try. Toggle between the freshly
rendered barcode and the stored photo of the card.

### Card Groups
Group related cards together (e.g. a shared household membership) and swipe through them in a
single looping full-screen view. Groups support **hands-free auto-advance**: with "Auto" on,
Yeetcard advances to the next card when it hears a checkout **beep** (microphone RMS-spike
detection via `AVAudioEngine`) or feels a **tap/knock** on the device (accelerometer via
`CoreMotion`). A developer debug overlay (toggled in Settings) visualizes the live detection
signal and thresholds.

### Gallery
A grid of all your cards with search, sorting, filtering, and favorites.

### Local Storage
All data is stored on-device with SwiftData. Full-size card images are saved to the app's
Documents directory (SwiftData stores the file-path reference); 300×200 thumbnails are
generated for the gallery. No card data leaves the device.

### Security
Biometric authentication (Face ID or Touch ID) is required on launch and when returning from
the background, with a device-passcode fallback so a failed biometric scan never locks you out
of your own cards. On a device with no biometrics enrolled, the app opens directly. Content is
hidden behind an overlay until you authenticate.

### Apple Wallet (scaffolded, not enabled)
A PassKit integration exists in the codebase (`PassKitService`) that would POST card data to an
external pass-signing web service and present the native `PKAddPassesViewController`. It is
**not wired into the current build**: the "Add to Wallet" UI is dead code, the service URL is a
placeholder, and no network calls are made. See [Apple Wallet integration](#apple-wallet-integration)
below for the intended contract.

## Project Structure

```
Yeetcard/
└── Yeetcard/
    ├── YeetcardApp.swift              # App entry, SwiftData container, auth gate, screenshot harness
    ├── Info.plist                     # Permission usage strings, encryption declaration
    ├── Yeetcard.entitlements          # Pass Type ID entitlement (Wallet, currently unused)
    ├── Models/
    │   ├── Card.swift                 # SwiftData @Model for a card
    │   ├── CardGroup.swift            # SwiftData @Model for a group of cards
    │   └── BarcodeFormat.swift        # Supported formats + Wallet/generation capability
    ├── Services/
    │   ├── CardDataService.swift      # SwiftData CRUD operations
    │   ├── CameraService.swift        # AVFoundation camera management
    │   ├── BarcodeDetectionService.swift  # Vision barcode detection
    │   ├── BarcodeGeneratorService.swift  # Core Image barcode/QR generation
    │   ├── ImageStorageService.swift  # Documents-directory image + thumbnail storage
    │   ├── AudioDetectionService.swift    # Beep detection (AVAudioEngine RMS spike)
    │   ├── TapDetectionService.swift  # Tap/knock detection (CoreMotion accelerometer)
    │   ├── AuthenticationService.swift    # Biometric auth (LocalAuthentication)
    │   └── PassKitService.swift       # Wallet pass generation (scaffolded, not called)
    ├── ViewModels/
    │   ├── GalleryViewModel.swift
    │   ├── CardDetailViewModel.swift
    │   ├── ScannerViewModel.swift
    │   ├── ManualEntryViewModel.swift
    │   ├── PhotoImportViewModel.swift
    │   ├── FullScreenBarcodeViewModel.swift
    │   ├── GroupBarcodeViewModel.swift
    │   ├── GroupManagementViewModel.swift
    │   ├── AuthenticationViewModel.swift
    │   └── SettingsViewModel.swift
    └── Views/
        ├── MainTabView.swift          # Cards + Settings tabs
        ├── GalleryView.swift          # Card grid
        ├── CardDetailView.swift       # Single card, edit/delete
        ├── ScannerView.swift          # Camera scanning
        ├── ManualEntryView.swift      # Manual barcode entry
        ├── PhotoImportView.swift      # Import from photo library
        ├── FullScreenBarcodeView.swift    # Full-screen single card + brightness boost
        ├── GroupBarcodeView.swift     # Full-screen group swiper + auto-advance
        ├── GroupManagementView.swift  # Create/edit groups
        └── SettingsView.swift         # Security status, data, developer, about
```

## Data Model

### Card (SwiftData `@Model`)

| Property | Type | Description |
|---|---|---|
| id | UUID | Unique identifier, auto-generated |
| name | String | Card name |
| barcodeData | String | Raw barcode content |
| barcodeFormatRaw | String | Format raw value (exposed as `barcodeFormat: BarcodeFormat`) |
| imagePath | String | Full-size image filename in Documents |
| thumbnailPath | String | Thumbnail filename in Documents |
| isInWallet | Bool | Whether the card has been added to Wallet |
| isFavorite | Bool | Favorited by the user |
| notes | String | User notes |
| dateAdded | Date | Creation timestamp |
| lastUsed | Date? | Last time the card was viewed/used |
| group | CardGroup? | Optional group membership |

### CardGroup (SwiftData `@Model`)

| Property | Type | Description |
|---|---|---|
| id | UUID | Unique identifier |
| name | String | Group name |
| dateCreated | Date | Creation timestamp |
| cards | [Card] | Member cards (inverse of `Card.group`, `.nullify` on delete) |

## Frameworks

| Framework | Purpose |
|---|---|
| SwiftUI | All user interface |
| SwiftData | Local data persistence |
| AVFoundation | Camera capture and microphone/audio beep detection |
| Vision | Real-time barcode detection (`VNDetectBarcodesRequest`) |
| CoreImage | Barcode/QR image generation |
| PhotosUI | Photo-library import (`PHPicker`) |
| CoreMotion | Tap/knock detection (accelerometer) |
| LocalAuthentication | Face ID / Touch ID (`LAContext`) |
| PassKit | Apple Wallet integration (scaffolded, not enabled) |
| UIKit | Interop (image handling, settings deep-link) |

## Navigation

The app uses a `TabView` with two tabs:

1. **Cards** (`creditcard`) — the gallery grid with search, sort, and filter
2. **Settings** (`gear`) — security status, saved-card count, delete-all, developer options, about

The scanner is presented as a full-screen modal; manual entry as a sheet. Card detail,
full-screen barcode, group barcode, and group management are pushed via `NavigationStack`.

## Apple Wallet integration

The scaffolded `PassKitService` targets an external pass-signing web service (a separate
project). The service URL is a placeholder and the API key is read from the `YEETCARD_API_KEY`
environment variable — nothing is hardcoded, and the code path is currently unreachable.

**Intended API contract:**
- `POST /api/v1/passes` with a JSON body of card data
- `X-API-Key` header for authentication
- Returns a binary `.pkpass` with `Content-Type: application/vnd.apple.pkpass`

## Privacy

Yeetcard collects nothing and makes no network calls in normal use. All cards — images,
barcode data, names, and notes — are stored only on the device. Deleting the app removes all
of it. Permissions used, all on-device:

- **Camera** — to scan the barcodes/QR codes on your cards.
- **Microphone** — to detect a checkout beep that auto-advances cards in group view. No audio
  is recorded, stored, or transmitted.
- **Photos** — to import a card image you choose (via `PHPicker`).
- **Face ID** — to protect your cards behind biometric authentication.

## Build & Run

The project ships with **no signing team** so it isn't tied to any one Apple account. To build
it yourself:

1. Open `Yeetcard/Yeetcard.xcodeproj` in Xcode 26 or later.
2. Under **Signing & Capabilities**, select your own development team. Automatic signing is
   enabled, so Xcode will provision against your team.
3. Change the **bundle identifier** (currently `Yeetcard.yeetcard1`) to one in your own
   namespace — the committed value is registered to the original author's account and can't be
   reused. Do the same for the test targets if you run them on device.
4. Build and run. Camera, microphone/beep detection, tap detection, biometrics, and Wallet all
   require a **physical device** — the Simulator can't exercise them.

Because the app is open source, you build and submit it under **your own** Apple Developer
account, team, and bundle ID — not the original author's.

The `Info.plist` declares `ITSAppUsesNonExemptEncryption = false` and the following usage
strings: `NSCameraUsageDescription`, `NSMicrophoneUsageDescription`, and
`NSFaceIDUsageDescription`.

## Testing

- **Unit tests:** `YeetcardTests`
- **UI tests:** `YeetcardUITests`

Tests run on the iOS 27 Simulator (Xcode 27 or later); the app itself still deploys back to
iOS 26.1:

```sh
xcodebuild test -project Yeetcard/Yeetcard.xcodeproj -scheme Yeetcard \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
```

Always include `OS=` in the destination. Without it `xcodebuild` picks the newest installed
runtime and fails if that runtime has no simulator with the given name.

A DEBUG-only screenshot harness (compiled out of Release builds) can seed sample cards and
route directly to a screen via the `-screenshots` launch argument, for capturing App Store
screenshots on the Simulator.

## App Store

- **Price:** Free
- **Category:** Utilities / Productivity
- **Privacy:** No data collected; camera, microphone, and photos are processed on-device only.
- **Support:** GitHub Issues (https://github.com/yeetcard/ios-app/issues)
- **Legal:** Privacy Policy and Terms of Service hosted via GitHub Pages
  (https://yeetcard.github.io/ios-app/), sources under `docs/`.
