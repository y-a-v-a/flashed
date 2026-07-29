# Installing on your own iPhone — without the App Store

Morse Beacon does not need the App Store. Apple supports installing an
app you built yourself onto a device you own — *development installing*,
colloquially sideloading — using nothing but Xcode and an Apple ID. The
free tier is enough; a paid Apple Developer membership only relaxes the
limits (see [the fine print](#the-fine-print)).

This is the intended way to run the app today: clone, build, install on
your own phone. No account with us (there is no "us" backend), no
review queue, no waiting.

## What you need

- A **Mac** with **Xcode 15 or newer** (free, from the Mac App Store).
  There is no Xcode for Windows/Linux; building iOS apps requires a Mac.
- An **iPhone running iOS 17+**, and a **USB cable** for the first
  connect (wireless works after that).
- An **Apple ID**. A free one works; you do *not* need the $99/year
  Developer Program to put the app on your own phone.

## One-time setup

1. **Add your Apple ID to Xcode.** Xcode → Settings → Accounts → `+` →
   Apple ID. This creates a free "Personal Team" used to sign the app.
2. **Enable Developer Mode on the iPhone** (iOS 16+ requires it for
   development installs): Settings → Privacy & Security → Developer
   Mode → on, then restart the phone and confirm. If the toggle isn't
   visible, connect the phone to Xcode once — iOS reveals it after the
   first development request.
3. **Trust the Mac** on the phone when the "Trust This Computer?"
   prompt appears.

## Install with Xcode (recommended)

1. Clone and open:

   ```sh
   git clone https://github.com/y-a-v-a/flashed.git
   cd flashed
   open MorseBeacon.xcodeproj
   ```

2. Select the project root → **MorseBeacon** target → **Signing &
   Capabilities**:
   - **Team**: your Personal Team (or real team).
   - **Bundle Identifier**: change `com.example.morsebeacon` to
     something globally unique, e.g. `com.yourname.morsebeacon`.
     Free-tier App IDs are first-come-first-served, so the committed
     placeholder will collide sooner or later.
3. Pick your iPhone in the device selector (top bar) and press **⌘R**.
4. First launch only: iOS blocks the unknown developer. Go to
   Settings → General → VPN & Device Management → your Apple ID →
   **Trust**, then launch again.

That's it — the app is on your home screen and works offline forever
(modulo the free-tier 7-day signature, below).

For subsequent installs without the cable: Window → Devices and
Simulators → your phone → tick **Connect via network**.

## Install from the command line

`scripts/install-on-device.sh` wraps the same flow headlessly — build
with `xcodebuild`, install and launch with `devicectl` (Xcode 15+):

```sh
# First run: pass your team ID (Xcode → Settings → Accounts, or
# developer.apple.com → Membership) and a unique bundle ID.
TEAM_ID=ABCDE12345 BUNDLE_ID=com.yourname.morsebeacon ./scripts/install-on-device.sh

# Later runs, once signing is remembered in the project:
./scripts/install-on-device.sh
```

The script auto-detects a single connected iPhone; with several
connected, set `DEVICE=<identifier>` from `xcrun devicectl list devices`.

## The fine print

Apple enforces these limits on the signing certificate, not the app:

| | Free Apple ID | Paid Developer Program |
|---|---|---|
| App runs for | **7 days**, then must be reinstalled (data survives) | 1 year |
| Sideloaded apps per device | 3 | effectively unlimited |
| New App IDs | 10 per 7 days | unlimited |
| Distribute to other people | no | ad-hoc (100 devices) / TestFlight |

"Reinstalled" just means: plug in and press ⌘R (or re-run the script)
once a week. Settings, last message, and the safety acknowledgement are
preserved — only the code signature expires.

## Giving it to someone else without the App Store

- **They build it themselves** — the canonical path for an MIT-licensed
  app. Send them this document.
- **Ad-hoc distribution** (paid account): register their device UDID,
  export an `.ipa` signed for that device, share the file. Caps at 100
  devices/year; installs via Finder or Apple Configurator.
- **TestFlight** (paid account): up to 10,000 testers via a link, builds
  live for 90 days. Technically App Store infrastructure, but no App
  Store listing or full review.
- Third-party sideloading tools (AltStore, Sideloadly) automate the
  same free-tier signing for people without Xcode — but they need a
  prebuilt `.ipa`, which this project deliberately doesn't ship.
  Building from source is the supported route.

## Troubleshooting

- **"Untrusted Developer" on launch** — Settings → General → VPN &
  Device Management → Trust. Reappears whenever the signing identity
  changes.
- **"Failed to register bundle identifier"** — the bundle ID is taken;
  pick another (and mind the 10-IDs-per-week free-tier cap).
- **Xcode can't see the phone** — unlock it, accept the trust prompt,
  check the cable is a data cable; then Window → Devices and Simulators.
- **"The developer disk could not be mounted" / Developer Mode missing**
  — complete step 2 of the one-time setup including the restart.
- **App gone/greyed after a week (free tier)** — the 7-day signature
  expired; reinstall from Xcode or the script.
