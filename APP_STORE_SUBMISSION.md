# Yeetcard — App Store Submission

Everything needed to take Yeetcard from "TestFlight builds that expire every 90 days"
to a permanent, official App Store release. The code side is ready; the remaining work
is metadata + review, which happens in **App Store Connect** (web) and **Xcode Organizer**.

> Goal for this pass: get v1.0 approved so you have a non-expiring install. Apple Wallet
> / pass-signing backend is intentionally **out of scope** for this version and is not
> mentioned anywhere in the metadata (the button is removed, no network calls are made).

---

## 0. Two hard blockers to clear first

1. **GitHub Pages must be enabled.** Apple rejects any submission whose privacy URL 404s.
   The privacy policy, terms, and a support/landing page are committed under `docs/`, and
   the app now links to `https://yeetcard.github.io/ios-app/...`. Turn them on:
   GitHub → repo **Settings → Pages → Source: Deploy from a branch → Branch `main` / `/docs`
   → Save**. The repo must be **public** (which is the plan — open-sourcing it). Wait ~1 min,
   then confirm `https://yeetcard.github.io/ios-app/privacy/` loads. No DNS or backend needed.
2. **The build must contain the auth fix.** This finalization added a device-passcode
   fallback to the Face ID lock (see §5). That's a code change, so you must archive and
   upload a **new build with an incremented build number** — you can't ship an old
   TestFlight build. Bump `CURRENT_PROJECT_VERSION` to the next unused number before archiving.

---

## 1. App record facts (must match the project)

| Field | Value |
|---|---|
| App name | **Yeetcard** |
| Bundle ID | `Yeetcard.yeetcard1` |
| SKU | `yeetcard-ios` (any unique string) |
| Version string | `1.0` (`MARKETING_VERSION`) |
| Build | next unused `CURRENT_PROJECT_VERSION` (currently `1`) |
| Team | `99T37T366A` |
| Min iOS | 26.1 (unchanged — reach is intentionally not a concern) |
| Price | Free |
| Primary category | Utilities |
| Secondary category | Productivity |
| Age rating | 4+ (no objectionable content) |

---

## 2. Paste-ready metadata

**Subtitle** (≤30): `Scan & store loyalty cards`

**Promotional text** (≤170, editable anytime without review):
`Keep every loyalty and membership card in one place. Scan once, then pull up any barcode full-screen at checkout — brightness boosted so it always scans.`

**Keywords** (≤100, comma-separated, no spaces after commas):
`loyalty card,barcode,QR code,scanner,membership,rewards,store card,card wallet,offline,grocery`

**Description** (≤4000):
```
Yeetcard keeps all your loyalty, membership, and rewards cards in one private place —
so you can leave the plastic at home.

SCAN ONCE
Point your camera at any barcode or QR code and Yeetcard captures it automatically.
Supports QR, Code 128, Code 39, EAN-13, EAN-8, UPC-A, UPC-E, PDF417, Aztec, and Data Matrix.

CAN'T SCAN IT? TYPE IT
Damaged or hard-to-read card? Enter the number by hand and Yeetcard regenerates a clean,
scannable barcode for you.

READY AT CHECKOUT
Pull up any card full-screen with the brightness boosted automatically, so the register
scans it on the first try. Group related cards together and move through them hands-free.

PRIVATE BY DESIGN
Everything stays on your device. No account, no sign-up, no tracking, and nothing is ever
uploaded to a server. Your cards are protected behind Face ID or Touch ID every time you
open the app.

Yeetcard does one thing well: your cards, always with you, always private.
```

**Support URL:** `https://yeetcard.github.io/ios-app/`
**Marketing URL** (optional): `https://yeetcard.github.io/ios-app/`
**Copyright:** `2026 Rishi Malik`

> Do **not** mention Apple Wallet — that feature isn't in this build. Describing a feature
> the reviewer can't find is a common rejection reason.

---

## 3. App Privacy (nutrition label)

The shipped app collects nothing and makes no network calls (verified: no analytics SDKs,
and the only networking code path — the pass service — is unreachable in this build).

- **Data Collection:** answer **"No, we do not collect data from this app."**

That's the entire privacy section. Camera, Photos, and Microphone are *permissions*, not
*data collection* — they're processed on-device and never leave it, so they don't appear here.

---

## 4. App Review notes (paste into "Notes" for the reviewer)

```
No account or login is required — the app opens straight to the card gallery.

SECURITY LOCK: Yeetcard locks behind Face ID / Touch ID on launch. On a device with no
biometrics enrolled, the app opens directly. On a device with biometrics, a device-passcode
fallback is available if the biometric scan fails, so you will never be locked out.

PERMISSIONS:
- Camera: used only to scan barcodes/QR codes on the user's own cards.
- Microphone: used only on-device to detect a "beep" that auto-advances cards in group
  view. No audio is ever recorded, stored, or transmitted.
- Photos: used only to import an existing card image the user selects.

DATA: All cards are stored locally on the device. Nothing is collected or sent to any server.

Apple Wallet integration is not part of this version.
```

---

## 5. Code changes made in this finalization pass

- **`AuthenticationService.swift`** — the unlock now uses `.deviceOwnerAuthentication`
  instead of `.deviceOwnerAuthenticationWithBiometrics`, adding a device-passcode fallback
  when Face ID / Touch ID fails. Prevents being permanently locked out of your own cards
  and removes a review edge case. This is the only behavioral change; it needs a fresh build.

- **`SettingsView.swift`** — the About links now point at GitHub Pages
  (`yeetcard.github.io/ios-app/privacy/` and `/terms/`) instead of the unwired
  `yeetcard.rocks` domain, and "Contact Support" now opens GitHub Issues.
- **`docs/`** — added `index.html` (support/landing), `privacy/index.html`, and
  `terms/index.html`, served via GitHub Pages. No custom domain or backend required.

Left intentionally unchanged:
- Deployment target stays at iOS 26.1 (reach is not a concern — personal use).
- `walletSection` in `CardDetailView.swift` is dead code (not rendered) and the Wallet
  entitlement remains — both are ready to reconnect when the pass-signing backend ships.
- `PassKitService` still points at a placeholder URL; harmless because it's never called.

---

## 6. Legal / support pages (already written, hosted via GitHub Pages)

These are committed in the repo — you only need to enable Pages (§0, blocker 1):

| Page | File | Live URL |
|---|---|---|
| Support / landing | `docs/index.html` | `https://yeetcard.github.io/ios-app/` |
| Privacy Policy | `docs/privacy/index.html` | `https://yeetcard.github.io/ios-app/privacy/` |
| Terms of Service | `docs/terms/index.html` | `https://yeetcard.github.io/ios-app/terms/` |

Support/contact routes to GitHub Issues (`github.com/yeetcard/ios-app/issues`) — no email
inbox to maintain, which fits open-sourcing the repo.

---

## 7. Submission checklist (order matters)

- [ ] Make the repo **public** and enable GitHub Pages (Settings → Pages → `main` / `/docs`);
      confirm `https://yeetcard.github.io/ios-app/privacy/` loads (§0, blocker 1).
- [ ] Open Xcode.app once and let it "install additional required components" (fixes the
      stale command-line toolchain — see note below).
- [ ] Bump `CURRENT_PROJECT_VERSION` to the next unused build number.
- [ ] Product → Archive (Any iOS Device). Confirm the archive validates.
- [ ] Distribute App → App Store Connect → Upload. Wait for it to finish processing.
- [ ] In App Store Connect, create the **1.0** App Store version (the app record already
      exists from TestFlight).
- [ ] Fill in metadata from §2, privacy from §3, review notes from §4.
- [ ] Upload screenshots — required: **6.9"/6.7" iPhone**. Add iPad (12.9") if you want it
      offered on iPad. Take them on Simulator or device: gallery, a full-screen barcode,
      the scanner, settings.
- [ ] Set **Price: Free** and pick availability (all countries, or just yours).
- [ ] Answer the **Age Rating** questionnaire → resolves to 4+.
- [ ] Select the build you uploaded. Export compliance auto-resolves (Info.plist already
      declares `ITSAppUsesNonExemptEncryption = false`).
- [ ] Submit for Review.

### Note on the local toolchain
Command-line `xcodebuild` currently fails to load `IDESimulatorFoundation` because the
privileged `DVTDownloads.framework` in `/Library/Developer/PrivateFrameworks` is from an
older Xcode than the active 26.6. Launching Xcode.app and accepting the "install additional
components" prompt (or running `sudo xcodebuild -runFirstLaunch`) reinstalls it. This does
**not** affect the GUI Archive/Distribute flow you'll use to submit.
```
