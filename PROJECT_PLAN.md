# Yeetcard iOS — Project Plan

## Overview

This document defines the development plan for the Yeetcard iOS application from empty repository through App Store launch and post-launch support.

## Timeline

Estimated 13-15 weeks from project start to App Store availability.

### Phase 1: Foundation (Week 1-2)
Set up Apple Developer account, certificates, provisioning profiles, Xcode project, Git repository, and legal documents. Register Pass Type ID for Wallet integration. This phase is entirely blocking — nothing else can begin until the Xcode project builds and runs.

### Phase 2: Data Layer (Week 3)
Implement SwiftData model, CardDataService for CRUD operations, and ImageStorageService for file system image management. This is the foundation every feature depends on.

### Phase 3: Camera & Scanning (Week 4-5)
Build CameraService with AVFoundation, BarcodeDetectionService with Vision framework, scanner UI with live preview and detection overlay, auto-capture logic, and image processing utilities. Test on physical device.

### Phase 4: Manual Entry (Week 5-6, parallel with late camera work)
Build manual entry form, barcode validation, barcode image generation from Core Image, and integration with the scanner flow. This is a parallel workstream that can overlap with camera testing.

### Phase 5: Apple Wallet (Week 6-7)
Build PassKitService to communicate with the pass signing web service. Implement Wallet compatibility detection, pass generation flow, PKAddPassesViewController presentation, status indicators, and error handling. **Requires the pass signing web service to be deployed first.**

### Phase 6: User Interface (Week 8-9)
Build all remaining UI: Gallery view with grid layout, search, sort, and filter. Card detail view with editing, deletion, sharing, and brightness boost. Settings view with security status, about section, and data management. Navigation structure, loading states, animations, and dark mode support.

### Phase 7: Security (Week 10)
Implement AuthenticationService with LocalAuthentication, app launch authentication, background overlay, edge case handling, and settings integration. Test on physical devices with Face ID and Touch ID.

### Phase 8: Testing (Week 11-12)
Unit tests for models, services, viewmodels, and utilities. UI test suite for critical flows. Manual testing on physical devices: happy path, edge cases, performance, accessibility, and device compatibility. TestFlight beta distribution.

### Phase 9: Submission (Week 13-15)
App icon, launch screen, screenshots, App Store description, keywords, privacy details, review information. Final code review, production build, upload, metadata completion, and submission. Monitor review, handle rejection if needed, release.

## Critical Path

These items must complete in sequence. A delay on any one delays the entire project.

```
Apple Developer Account
  → Pass Type ID Certificate
    → Xcode Project + Certificates
      → SwiftData Model
        → CardDataService + ImageStorageService
          → CameraService + BarcodeDetectionService
            → PassKitService (requires web service deployed)
              → All UI Views
                → Authentication
                  → Testing
                    → App Store Submission
```

## Parallel Work Opportunities

These workstreams can run simultaneously to compress the timeline:

| Parallel Track A | Parallel Track B |
|---|---|
| Camera implementation (Week 4-5) | Manual entry implementation (Week 5-6) |
| Core UI views (Week 8) | App icon and launch screen design |
| Testing (Week 11-12) | App Store metadata preparation |
| Legal documents (Week 1) | Domain registration (Week 1) |

The pass signing web service (separate project) should ideally be started in Week 1-2 so it's ready by Week 6 when Wallet integration begins.

## Dependencies on External Project

The Yeetcard iOS app depends on the `yeetcard-pass-service` web service for Apple Wallet functionality:

- **When needed:** Week 6 (Wallet integration begins)
- **What's needed:** Deployed, accessible API endpoint that accepts card data and returns signed .pkpass files
- **API contract:** POST /api/v1/passes, X-API-Key auth, returns application/vnd.apple.pkpass
- **If delayed:** All Wallet-related tasks (Epic 6) are blocked, but the rest of the app can proceed

## Risk Register

### High Risk
1. **App Store rejection** — Mitigate by following guidelines exactly, thorough testing, and clear documentation for reviewers about Wallet functionality.
2. **Pass signing service unavailability** — Mitigate by building the web service early and having robust error handling in the app when the service is down.
3. **Barcode detection unreliability** — Mitigate by providing manual entry fallback and testing with many real-world cards.

### Medium Risk
4. **Wallet compatibility confusion** — Users may expect all cards to work in Wallet. Mitigate with clear UI messaging about which formats are supported.
5. **Performance with large card collections** — Mitigate by using lazy loading, thumbnail generation, and testing with 100+ cards.
6. **Certificate expiration** — Pass Type ID certificates expire. Document renewal process.

### Low Risk
7. **iOS version compatibility** — iOS 17+ is well-adopted. Test on minimum version.
8. **Device screen size issues** — SwiftUI handles most adaptation. Test on SE, Pro, Pro Max.

## Definition of Done

A task is done when:
1. All acceptance criteria are met
2. Code compiles without warnings
3. Unit tests pass (where applicable)
4. Code is committed and pushed
5. Code has been self-reviewed (no debug code, no TODOs)
6. Feature works on simulator and/or physical device as specified

## Sprint Structure

Two-week sprints, targeting 20 story points per sprint for full-time work or 10 points for part-time.

- **Sprint 1 (Week 1-2):** Foundation setup — all Epic 1 tasks
- **Sprint 2 (Week 3-4):** Data layer + Camera start — Epic 2 + Epic 3 start
- **Sprint 3 (Week 5-6):** Camera complete + Manual entry + Wallet start — Epic 3 finish + Epic 4 + Epic 5 start
- **Sprint 4 (Week 7-8):** Wallet complete + UI start — Epic 5 finish + Epic 6 start
- **Sprint 5 (Week 9-10):** UI complete + Security — Epic 6 finish + Epic 7
- **Sprint 6 (Week 11-12):** Testing — Epic 8
- **Sprint 7 (Week 13-14):** App Store prep + Submission — Epic 9 + Epic 10

## Environments

| Environment | Purpose |
|---|---|
| Simulator | Day-to-day UI development and unit tests |
| Development Device | Camera, biometrics, Wallet, performance testing |
| TestFlight Internal | Team testing before beta |
| TestFlight External | Beta testing with outside users |
| App Store | Production release |

## Versioning

- **Version format:** Major.Minor.Patch (semantic versioning)
- **v1.0.0:** Initial App Store release
- **v1.0.x:** Bug fix releases
- **v1.1.0:** First feature update (based on user feedback)
- **Build numbers:** Increment with every TestFlight upload

## Success Criteria

### Launch
- App approved by Apple on first or second submission
- Zero critical bugs
- All core features functional on physical device
- Biometric auth working reliably
- Wallet integration working for compatible cards

### 30 Days Post-Launch
- <1% crash rate
- 4+ star average rating
- Support email volume manageable
- No security issues reported

### 90 Days Post-Launch
- 500+ downloads
- Positive user feedback on core scanning and storage
- Clear signal on what to build for v1.1
