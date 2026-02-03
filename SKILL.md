---
name: yeetcard-ios
description: >
  iOS app development skill for Yeetcard, a loyalty card scanning and storage app.
  Use when working on any Yeetcard iOS development tasks including: SwiftUI views,
  SwiftData models, AVFoundation camera integration, Vision framework barcode detection,
  PassKit Apple Wallet integration, LocalAuthentication biometrics, image processing,
  or any feature/bug/test work on the Yeetcard iOS codebase. Also use when discussing
  Yeetcard iOS architecture, data flow, or implementation decisions.
---

# Yeetcard iOS Development

## Tech Stack

- iOS 17.0+, Swift, SwiftUI, MVVM architecture
- SwiftData for local persistence (no cloud sync)
- AVFoundation for camera, Vision for barcode detection
- PassKit for Apple Wallet, LocalAuthentication for Face ID/Touch ID
- Core Image for barcode generation from manual entry data

## Architecture

MVVM with three layers:

1. **Views** (SwiftUI) — Render UI, bind to ViewModel published properties
2. **ViewModels** — Hold view state, call Services, expose @Published properties
3. **Services** — Business logic, data access, framework wrappers

Views never call Services directly. ViewModels never access SwiftUI types.

## Data Model

Single entity: `Card` (@Model)

Key properties: id (UUID), name (String), barcodeData (String), barcodeFormat (String), imagePath (String), thumbnailPath (String), isInWallet (Bool), isFavorite (Bool), notes (String), dateAdded (Date), lastUsed (Date?)

Images stored in Documents directory. SwiftData stores path references only. Thumbnails are 300x200px JPEG at 80% quality.

## Services

### CardDataService
CRUD wrapper for SwiftData. All Card operations go through this service. Coordinates with ImageStorageService for image cleanup on delete.

### CameraService
AVCaptureSession management. Back camera only. Provides startSession(), stopSession(), capturePhoto(), toggleFlash(). Handles permission checks.

### BarcodeDetectionService
Vision framework VNDetectBarcodesRequest. Real-time detection from CVPixelBuffer. Returns barcode data, format, and bounding box. Supports: QR, Code128, Code39, EAN-13, EAN-8, UPC-A, UPC-E, PDF417, Aztec, Data Matrix.

### ImageStorageService
File system operations for card images. Save, load, delete, generate thumbnails. Uses Documents directory with UUID-based filenames.

### PassKitService
Communicates with external pass signing web service. POST to /api/v1/passes with card data, receives .pkpass binary. Handles network errors, timeouts (10s), retry logic. Only called for Wallet-compatible formats (QR, Code128, PDF417, Aztec).

### AuthenticationService
LocalAuthentication wrapper. Checks biometric availability (Face ID vs Touch ID vs None). Authenticates on launch and foreground return. No disable option in v1.0.

## Key Implementation Notes

### Camera + Vision Pipeline
CameraService provides AVCaptureVideoDataOutput frames to BarcodeDetectionService. Detection runs on every frame. When same barcode detected for 1 second, auto-capture triggers. ScannerViewModel coordinates this flow and updates published state.

### Wallet Flow
1. CardDetailView shows "Add to Wallet" only if `isWalletCompatible(card)` returns true
2. User taps button → PassKitService calls web service → receives .pkpass
3. PKAddPassesViewController presented → user accepts or cancels
4. On accept: card.isInWallet = true, saved to SwiftData

### Authentication Flow
1. App launch → AuthenticationOverlay shown (blurred)
2. LAContext.evaluatePolicy called automatically
3. Success → overlay dismissed, app usable
4. Failure → retry prompt or close app
5. App backgrounds → overlay shown immediately
6. App foregrounds → authenticate again

### Image Processing
- Full-size images: JPEG at 80% quality, stored in Documents
- Thumbnails: 300x200px, JPEG at 80%, stored alongside
- Barcode region extraction: Crop to VNBarcodeObservation bounding box
- Contrast enhancement: CIColorControls filter for barcode visibility

### Manual Entry Barcode Generation
Core Image CIFilter generators: CIQRCodeGenerator, CICode128BarcodeGenerator, CIPDF417BarcodeGenerator, CIAztecCodeGenerator. Generate UIImage from data string, save same as scanned images.

## Navigation Structure

```
TabView
├── Gallery Tab (NavigationStack)
│   ├── GalleryView (LazyVGrid, search, sort, filter)
│   │   └── push → CardDetailView (image, barcode, edit, delete, wallet, share)
│   └── modal → ScannerView (camera, detection, capture)
│       └── sheet → ManualEntryView (form, validation, save)
└── Settings Tab
    └── SettingsView (security, about, data management)
```

## Pass Signing Web Service API

The iOS app calls this API for Wallet pass generation:

```
POST /api/v1/passes
Headers: X-API-Key: <key>, Content-Type: application/json
Body: {
  "cardName": "Costco Membership",
  "barcodeData": "123456789",
  "barcodeFormat": "Code128",
  "foregroundColor": "#FFFFFF",
  "backgroundColor": "#1A1A2E"
}
Response: 200 OK, Content-Type: application/vnd.apple.pkpass, Body: binary .pkpass
Errors: 400 (validation), 401 (auth), 500 (server error) — JSON body with error message
```

## Common Patterns

### Adding a New View
1. Create View file in Views/
2. Create ViewModel in ViewModels/ with @Published properties
3. Inject services via init or environment
4. Wire navigation in parent view
5. Add unit tests for ViewModel

### Adding a New Service
1. Create Service file in Services/
2. Define public interface (protocol optional for testability)
3. Implement with error handling
4. Write unit tests with mocks
5. Inject into ViewModels that need it

### Error Handling
All user-facing errors should be clear, non-technical messages. Log technical details for debugging. Never crash on recoverable errors. Network errors for Wallet: suggest checking internet connection.
