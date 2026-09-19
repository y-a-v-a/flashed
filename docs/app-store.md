# App Store metadata

Drafts of every text field needed for App Store Connect submission.
Update version-specific fields (changelog, version number) per release.

## App information

| Field                  | Value                                  | Notes                                                      |
| ---------------------- | -------------------------------------- | ---------------------------------------------------------- |
| **App Name** | Flashed: Morse Beacon | Max 30 chars; using 21. "Morse Beacon" alone was taken; the home-screen name stays "Morse Beacon". |
| **Subtitle**           | Optical Morse signaling                | Max 30 chars; using 23.                                    |
| **Bundle ID** | `nl.vincentbruijn.morsebeacon` | Registered in the developer portal. |
| **Primary Category**   | Utilities                              |                                                            |
| **Secondary Category** | (none)                                 |                                                            |
| **Content Rights**     | Original work; no third-party content. |                                                            |
| **Pricing**            | Free                                   | No IAP.                                                    |
| **Availability**       | Worldwide                              | No reason to restrict.                                     |

## Description (max 4000 chars)

> A transmit-only optical Morse beacon. Type a short message; after a
> 5-second countdown, your phone screen flashes that message in
> International Morse Code at full brightness — bright enough to be
> spotted at line-of-sight distance.
>
> A live HUD strip at the top of the screen shows the source text and
> the rendered Morse alongside the flashing area, with the current
> character and dit/dah element highlighted in amber as they transmit.
>
> Two timing models:
> • PARIS — the standard ITU 1 WPM = "PARIS " per minute.
> • Farnsworth — fast individual characters with stretched gaps,
> suitable for slower receivers.
>
> WPM range: 5 to 20. If Reduce Motion is enabled in iOS Accessibility
> settings, the maximum is automatically capped at 10.
>
> The app is intentionally minimal. It does not receive Morse, does not
> use the camera flash, does not use the network, does not collect any
> data, and has no accounts. It is a single-purpose tool: optical
> Morse out, nothing else.
>
> ⚠️ PHOTOSENSITIVITY WARNING
> This app produces rapid flashing light that may trigger seizures in
> people with photosensitive epilepsy. Do not use if you or anyone
> nearby is affected. The app shows this warning on first launch and
> requires explicit acknowledgement.

## Promotional Text (max 170 chars)

> Type a message; your screen flashes it in Morse code at full
> brightness with a live HUD showing dits and dahs in lockstep with
> the flash.

## Keywords (max 100 chars, comma-separated)

```
morse,beacon,signal,flashlight,communication,line of sight,emergency,utility,torch,paris,farnsworth
```

(11 keywords, 96 chars)

## What's New (per release)

### 0.1 (initial)

> First release. Optical Morse transmission with live HUD,
> PARIS / Farnsworth timing, 5–20 WPM, photosensitivity safety gate.

## URLs

| Field                  | Value                                                                                                                                                                                                                       |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Support URL**        | (set to project repo or `mailto:vincent@vincentbruijn.nl`)                                                                                                                                                                  |
| **Marketing URL**      | (optional; leave blank for v1)                                                                                                                                                                                              |
| **Privacy Policy URL** | `https://www.vincentbruijn.nl/morse-beacon/privacy/privacy-policy.html` — source in `docs/privacy-policy.md`, rendered copy in `docs/privacy-policy.html`. Re-upload both after any edit. |

## Privacy nutrition label

Apple's data-collection questionnaire. Every category answers
**"Data Not Collected"**:

- ❌ Contact Info
- ❌ Health & Fitness
- ❌ Financial Info
- ❌ Location
- ❌ Sensitive Info
- ❌ Contacts
- ❌ User Content
- ❌ Browsing History
- ❌ Search History
- ❌ Identifiers
- ❌ Purchases
- ❌ Usage Data
- ❌ Diagnostics
- ❌ Other Data

This is enforced in code:

- No `URLSession` / `URLRequest` / `Network` / `CFNetwork` references
  (verified by `scripts/check-no-network.sh`, run in CI).
- No analytics SDKs (no third-party deps at all).
- The only `URL` in the app is `mailto:vincent@vincentbruijn.nl` in
  `AboutView`, which opens the user's mail client; the app itself
  does not send anything.

## Age rating

Apple's age-rating questionnaire doesn't have a "photosensitivity"
field. Answer all categories honestly:

- Cartoon or Fantasy Violence: None
- Realistic Violence: None
- Prolonged Graphic or Sadistic Realistic Violence: None
- Profanity or Crude Humor: None
- Mature/Suggestive Themes: None
- Horror/Fear Themes: None (the flashing is functional, not horror)
- Medical/Treatment Information: None
- Alcohol, Tobacco, or Drug Use or References: None
- Simulated Gambling: None
- Sexual Content or Nudity: None
- Graphic Sexual Content and Nudity: None
- Unrestricted Web Access: No
- Gambling and Contests: No

Expected rating: **4+**. The photosensitivity warning is communicated
in the description and at first-launch in-app, not via age rating.

## Screenshots

App Store Connect requires one mandatory iPhone set at the 6.9" size
(1320 × 2868, i.e. an iPhone 17 Pro Max simulator). Apple scales it
down for every smaller display. iPad is not needed since the app is
iPhone-only (`TARGETED_DEVICE_FAMILY = 1`).

`scripts/take-screenshots.sh` produces the full set in `docs/screenshots/`
at that size, preferring a Pro Max simulator automatically. Upload
files 0–5 from there; a good order is 1, 4, 3, 2, 0, 5 (input first,
then the beacon in action, then the safety gate).

App Store Connect shows one screenshot slot per display size, and the
slot it opens by default is not always the 6.9" one. If the upload
error lists 1242 × 2688 / 1284 × 2778, you are in the 6.5" slot: either
switch to the 6.9" slot ("View All Sizes in Media Manager") or use the
derived 1284 × 2778 set in `docs/screenshots/6.5-inch/`, which is the
6.9" set scaled to width and cropped by 6 px top and bottom.

Under the hood each screen is reached via:

```sh
SIMCTL_CHILD_MB_LAUNCH_TO=<route> xcrun simctl launch booted <bundle id>
xcrun simctl io booted screenshot screenshot-N.png
```

1. **Input view** with a sample message typed in (`MB_LAUNCH_TO=input`,
   pre-set `settings.lastMessage` via `simctl spawn defaults write`).
2. **Beacon transmitting** — HUD strip showing amber-highlighted
   character + flash area white (`MB_LAUNCH_TO=beacon`).
3. **Settings** showing PARIS / Farnsworth picker
   (`MB_LAUNCH_TO=settings`).
4. **Photosensitivity warning** — required by App Store reviewers to
   demonstrate the safety gate (delete `safetyAcknowledgedV1` first,
   then default route).
5. **Countdown** — large numeral on black (`MB_LAUNCH_TO=countdown`).

## Reviewer notes (App Review Information field)

> This app is a transmit-only optical Morse beacon: it flashes the
> screen in Morse code based on user-typed text. No camera, no
> network, no accounts. The first-launch screen is a photosensitivity
> warning that must be explicitly acknowledged before any flashing
> can occur. Demo: type any short message in the input view, tap
> Transmit, observe the 5-second countdown, then the screen flashes
> the message. Tap anywhere during the countdown or transmission to
> abort. Settings (gear icon) lets you adjust WPM and timing model.

## Required-by-Apple checks before submission

- [x] Bundle ID set to `nl.vincentbruijn.morsebeacon`.
- [x] Signing team set in Xcode project.
- [x] App icon: `MorseBeacon/Assets.xcassets/AppIcon.appiconset/icon-1024.png`
      is 1024×1024 with no alpha channel (App Store Connect rejects
      transparency). `./scripts/generate-app-icon.swift` regenerates it.
- [x] Privacy manifest `MorseBeacon/PrivacyInfo.xcprivacy` declares the
      `UserDefaults` required-reason API (CA92.1). Without it the upload
      is rejected with ITMS-91053.
- [x] `ITSAppUsesNonExemptEncryption = NO` in `Info.plist`, so App Store
      Connect never asks the export-compliance question per build.
- [ ] Version + build numbers in pbxproj match what Apple expects
      (every build uploaded to App Store Connect must have a unique
      `CURRENT_PROJECT_VERSION`).
- [x] Screenshots captured per "Screenshots" section above (6.9" set).
- [x] Privacy Policy URL hosted at
      `https://www.vincentbruijn.nl/morse-beacon/privacy/privacy-policy.html`.
- [ ] First TestFlight build submitted and self-tested on a real
      device for FR-12 jitter (TASKS 2.2.10) and AC-1/AC-2/AC-3/AC-5
      verification (TASKS 5.1–5.5).
