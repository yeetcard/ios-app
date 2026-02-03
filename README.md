# Yeetcard iOS App

Yeetcard is an iOS application that lets users scan, store, and manage loyalty cards and credentials. Users can capture barcodes and QR codes with their camera, store card images locally, and add compatible cards to Apple Wallet.

## Technical Stack

- **Platform:** iOS 17.0+
- **Language:** Swift
- **UI Framework:** SwiftUI
- **Architecture:** MVVM (Model-View-ViewModel)
- **Data Persistence:** SwiftData (local only, no cloud sync)
- **Authentication:** Face ID / Touch ID via LocalAuthentication
- **Apple Wallet:** PassKit integration with external pass signing service

## Core Features

### Card Scanning
Scan barcodes and QR codes using the device camera with real-time detection via Apple's Vision framework. Supported formats: QR Code, Code 128, Code 39, EAN-13, EAN-8, UPC-A, UPC-E, PDF417, Aztec, Data Matrix. Auto-capture triggers when a barcode is stable for 1 second. Manual capture is always available.

### Manual Entry
Fallback for damaged or hard-to-scan cards. Users type the barcode number and select the format. Input is validated per format requirements. A barcode image is generated using Core Image filters so the card is still scannable from the app.

### Apple Wallet Integration
Compatible cards (QR, Code128, PDF417, Aztec formats) can be added to Apple Wallet. The app sends card data to an external pass signing web service, receives a signed .pkpass file, and presents the native PKAddPassesViewController. Cards that aren't Wallet-compatible are stored as images only, with clear messaging explaining why.

### Local Storage
All data is stored locally on the device using SwiftData. Card images are saved to the app's Documents directory with SwiftData storing file path references. Thumbnails (300x200px) are generated for the gallery view. No data leaves the device except when generating Wallet passes via the signing service.

### Security
Biometric authentication (Face ID or Touch ID) is required on every app launch and when returning from background. A blurred overlay hides content during authentication. There is no option to disable authentication in v1.0.

## Project Structure

```
Yeetcard/
├── App/
│   └── YeetcardApp.swift              # App entry point, SwiftData container setup
├── Models/
│   ├── Card.swift                     # SwiftData @Model for card entities
│   └── PassConfiguration.swift        # Pass appearance configuration
├── Views/
│   ├── GalleryView.swift              # Main card grid view
│   ├── CardDetailView.swift           # Individual card view with actions
│   ├── ScannerView.swift              # Camera scanning interface
│   ├── ManualEntryView.swift          # Manual barcode entry form
│   ├── SettingsView.swift             # App settings and data management
│   └── Components/
│       ├── CardThumbnailView.swift    # Reusable card thumbnail component
│       ├── CameraPreview.swift        # UIViewRepresentable camera wrapper
│       ├── DetectionOverlay.swift     # Barcode detection visual overlay
│       └── AuthenticationOverlay.swift # Security blur overlay
├── ViewModels/
│   ├── GalleryViewModel.swift         # Gallery state, search, sort, filter
│   ├── CardDetailViewModel.swift      # Card detail state and actions
│   └── ScannerViewModel.swift         # Camera and detection state
├── Services/
│   ├── CardDataService.swift          # SwiftData CRUD operations
│   ├── CameraService.swift            # AVFoundation camera management
│   ├── BarcodeDetectionService.swift  # Vision framework barcode detection
│   ├── ImageStorageService.swift      # File system image management
│   ├── PassKitService.swift           # Wallet pass generation via web service
│   └── AuthenticationService.swift    # Biometric auth via LocalAuthentication
└── Utilities/
    ├── ImageProcessor.swift           # Crop, enhance, compress images
    ├── BarcodeValidator.swift         # Validate barcode data per format
    └── BarcodeImageGenerator.swift    # Generate barcode images via Core Image
```

## Data Model

### Card (SwiftData @Model)

| Property | Type | Description |
|---|---|---|
| id | UUID | Unique identifier, auto-generated |
| name | String | User-editable card name |
| dateAdded | Date | Creation timestamp, auto-set |
| lastUsed | Date? | Last time card was viewed/used |
| isFavorite | Bool | Favorited by user, default false |
| notes | String | User-editable notes |
| barcodeData | String | Raw barcode content |
| barcodeFormat | String | Format type (QR, Code128, etc.) |
| imagePath | String | Path to full-size image in Documents |
| thumbnailPath | String | Path to 300x200 thumbnail in Documents |
| isInWallet | Bool | Whether card has been added to Wallet |
| passTypeIdentifier | String? | Pass Type ID if in Wallet |
| serialNumber | String? | Pass serial number if in Wallet |

## Frameworks

| Framework | Purpose |
|---|---|
| SwiftUI | All user interface |
| SwiftData | Local data persistence |
| AVFoundation | Camera access and photo capture |
| Vision | Real-time barcode detection (VNDetectBarcodesRequest) |
| PassKit | Apple Wallet integration (PKAddPassesViewController) |
| LocalAuthentication | Face ID / Touch ID (LAContext) |
| CoreImage | Barcode image generation from data |

## Navigation

The app uses a TabView with two tabs:

1. **Gallery** (square.grid.2x2) — Main card grid with search, sort, and filter
2. **Settings** (gear) — Security status, about section, data management

The scanner is presented as a full-screen modal from the Gallery tab. Card detail is pushed via NavigationStack from the gallery.

## External Dependencies

### Pass Signing Web Service
The app communicates with a separate web service to generate signed .pkpass files for Apple Wallet. The service URL and API key are configured in the app. See the `yeetcard-pass-service` project for the web service implementation.

**API Contract:**
- `POST /api/v1/passes` with JSON body containing card data
- Returns binary .pkpass file with Content-Type: application/vnd.apple.pkpass
- Authentication via X-API-Key header

## Apple Developer Requirements

- **Apple Developer Account** ($99/year)
- **Bundle ID:** com.[company].yeetcard
- **Pass Type ID:** pass.com.[company].yeetcard
- **Certificates:** Development, Distribution, Pass Type ID
- **Provisioning Profiles:** Development, Distribution
- **Capabilities:** Camera, Face ID

## Info.plist Entries

```
NSCameraUsageDescription: "Yeetcard needs camera access to scan your loyalty cards and barcodes"
NSFaceIDUsageDescription: "Yeetcard uses Face ID to keep your cards secure"
```

## Build & Run

1. Open `Yeetcard.xcodeproj` in Xcode 15+
2. Select your development team in Signing & Capabilities
3. Set deployment target to iOS 17.0
4. Build and run on simulator or physical device
5. Note: Camera and biometrics require a physical device for full testing

## Testing

- **Unit tests:** Models, Services, ViewModels, Utilities (target >80% coverage)
- **UI tests:** Critical user flows (launch, scan, view, edit, delete)
- **Manual testing:** Physical device required for camera, biometrics, and Wallet
- **Device testing:** iPhone SE (small), iPhone 15 Pro (standard), iPhone 15 Pro Max (large)
- **iOS versions:** iOS 17.0 through latest

## App Store

- **Price:** Free
- **Category:** Utilities or Productivity
- **Privacy:** Camera, Photos/Videos, User Content — all local, not linked to user, not used for tracking
- **Support:** support@[domain].com
- **Legal:** Privacy Policy and Terms of Service hosted at [domain].com
