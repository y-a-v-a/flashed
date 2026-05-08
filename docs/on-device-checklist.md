# On-device verification checklist

This is the handoff for everything the headless dev loop cannot verify.
Work through it on a physical iPhone (12 or newer per PRD NFR-1) before
the first TestFlight beta and before submitting to the App Store.

Each section has:
- **Setup** — how to get into the right state.
- **Procedure** — what to do.
- **Pass criteria** — what to look for.
- **Capture on failure** — what to grab if the test fails (screen
  recording, sysdiagnose, etc.) so the bug is reproducible.

---

## 0. Pre-flight (one-off)

### 0.1 Replace the placeholder bundle ID

The committed pbxproj uses `com.example.morsebeacon` so the project
builds for any developer. Your real bundle ID needs to be set in two
places:

```sh
# In MorseBeacon.xcodeproj/project.pbxproj, replace both occurrences
# (Debug + Release configs of the MorseBeacon target):
sed -i '' 's/com\.example\.morsebeacon/com.YOURTEAM.morsebeacon/g' \
  MorseBeacon.xcodeproj/project.pbxproj
```

Also update `docs/app-store.md`'s bundle-ID line for consistency.
Verify:
```sh
grep -n PRODUCT_BUNDLE_IDENTIFIER MorseBeacon.xcodeproj/project.pbxproj
```

### 0.2 Configure signing

In Xcode (one-time GUI step):
- Open `MorseBeacon.xcodeproj`.
- Select the project root → **MorseBeacon** target → **Signing &
  Capabilities**.
- Set **Team** to your Apple Developer team.
- Leave **Automatically manage signing** ticked.

Or set via CLI:
```sh
# DEVELOPMENT_TEAM is your 10-character team ID from Apple Developer.
xcodebuild -scheme MorseBeacon -destination 'generic/platform=iOS' \
  build DEVELOPMENT_TEAM=ABCDE12345
```

### 0.3 Archive + install

```sh
# Archive Release.
xcodebuild archive \
  -scheme MorseBeacon \
  -project MorseBeacon.xcodeproj \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/MorseBeacon.xcarchive

# From Xcode Organizer (Window → Organizer): Distribute App →
# Development → install on a connected iPhone.
# Or use xcodebuild -exportArchive with an exportOptionsPlist.
```

For a TestFlight build, choose **App Store Connect** distribution
instead of **Development**.

### 0.4 Device prep

Before each test session:
- Settings → Display & Brightness: **Auto-Brightness OFF**, set
  brightness to around 50%. (We need a known starting point so we can
  see whether the app's `1.0` setting actually engages.)
- Settings → Display & Brightness: **True Tone OFF**, **Night Shift
  OFF**. Both warm the white point and would make the flash less
  bright/blue.
- Settings → Battery: **Low Power Mode OFF**.
- Settings → Accessibility → Motion: **Reduce Motion OFF** (we'll
  toggle this for FR-22 testing).
- Make sure the device is **cool** before timing tests — thermal
  throttling can affect DispatchSourceTimer accuracy.

---

## 1. Smoke test (~5 minutes)

Just confirm the app starts and the basic flow works.

- [ ] App launches from home screen, displays photosensitivity warning
      on first run.
- [ ] Tapping "I understand" dismisses the warning permanently
      (subsequent launches go straight to the input view).
- [ ] Typing a message updates the character counter live.
- [ ] Typing an unsupported character (`#`, `%`) shows the red
      validation error and disables the Transmit button.
- [ ] Tapping the gear icon pushes Settings; tapping (i) pushes About;
      back chevrons return cleanly.
- [ ] Settings → toggle PARIS/Farnsworth: the Effective WPM section
      appears/disappears.
- [ ] Tap **Transmit**: countdown appears, counts 5→1, transitions
      into flashing. Tapping during countdown returns to Input.
- [ ] Tap during flash: returns to Input.
- [ ] Let a short message complete: "Transmission complete" view
      appears with Transmit again / Done buttons. Both work.

If any of the above fail, do not proceed to the AC tests — the bug
is upstream and will mask the timing measurements.

---

## 2. Acceptance criteria

### AC-1 — SOS @ 10 WPM end-to-end within ±50 ms

**Setup.**
- Settings → PARIS, Character WPM = 10.
- Input message: `SOS`.

**Procedure.**
1. On a separate device with a stopwatch (or use a 60fps screen
   recording on the test phone itself and count frames):
   start timing the moment the first flash fires.
2. Stop timing the moment the last flash ends.

**Pass criteria.**
- Total transmission duration: **3240 ms ± 50 ms** (Core test asserts
  exactly 3240 ms; allow ±50 ms for end-to-end including UI rendering
  overhead).

If you record at 60fps: 3240 ms ≈ 194 frames. Acceptable range:
191–197 frames.

**Capture on failure.** 240fps slo-mo recording of the flash sequence,
side-by-side with the device's clock app showing milliseconds (Voice
Memos can be used as a coarse timer too).

---

### AC-2 — Tap-to-abort returns to input < 200 ms with brightness restored

**Setup.**
- Settings → PARIS, Character WPM = 5 (slow, so you have time to tap
  mid-transmission).
- Input: `HELLO WORLD HELLO WORLD HELLO WORLD` (long enough that you
  can tap during transmission).
- Note the device's current brightness level (~50%).

**Procedure.**
1. Tap Transmit, wait through the countdown.
2. During flashing, tap anywhere on screen.
3. Observe: the input view should reappear "instantly".

**Pass criteria.**
- Input view visible within ~200 ms of the tap (visual judgement is
  fine; if it feels laggy, record at 60fps and count frames —
  200 ms = 12 frames).
- Device brightness back to ~50% (the value before transmission).
- No flashing artefacts after the tap.

**Capture on failure.** 60fps screen recording of the tap → return.
Note current Auto-Brightness state — if it's ON, brightness might
drift after restoration which is **a documented gotcha**, not a bug.

---

### AC-3 — HUD highlight stays in lockstep with flash

**Setup.**
- Same as AC-1: SOS @ 10 WPM PARIS.
- Use a second device to record the test phone at **240fps slo-mo**
  (any iPhone 6s or newer Camera app supports this).

**Procedure.**
1. Start the slo-mo recording on the second device.
2. On the test phone, tap Transmit.
3. Let the full SOS sequence complete.
4. Stop recording.

**Pass criteria.**
- For every dit/dah in the slo-mo video:
  - The flash area transitions from black to white at frame *N*.
  - The HUD highlight is on the corresponding character/element at
    or before frame *N* (max one frame of lead/lag = ~4 ms at 240fps).
- During gaps (charGap, wordGap), the HUD shows no highlight and the
  flash area is black.

The HUD will visibly **blink** between highlighted and un-highlighted
during gaps — this is per spec (PRD §7a R4) and not a bug.

**Capture on failure.** The slo-mo recording itself is the artefact.
Frame-by-frame analysis can be done in QuickTime (J/L for prev/next
frame) or Final Cut.

---

### AC-5 — Backgrounding mid-transmission aborts cleanly, brightness restored on foreground

**Setup.**
- Same as AC-2 setup (long message, slow WPM).

**Procedure.**
1. Tap Transmit. Let the countdown finish; let the flashing start.
2. Press the **home indicator** (swipe up) to background the app.
3. Wait 5 seconds.
4. Reopen the app from the App Switcher or home screen.

**Pass criteria.**
- Brightness restored as soon as the app is backgrounded (you can see
  this in Control Center swipe-down which shows the slider).
- On reopening, the app is on the input view (NOT mid-flash).
- The text field still shows the message you just transmitted (FR-4).

**Capture on failure.** Sysdiagnose for any UI glitches, screen
recording showing the background → foreground sequence.

---

## 3. Functional requirements

### FR-10 / FR-11 — Brightness and idle-timer state

**FR-10:** During transmission, brightness must be 1.0 and idle
timer disabled.

**Setup.** Brightness ~50%, Auto-Brightness OFF, plug in to charging
so screen stays on for the duration of the test.

**Procedure.**
1. Note brightness slider position in Control Center.
2. Start a long transmission (~10 seconds at 5 WPM).
3. Mid-transmission, swipe down for Control Center.

**Pass criteria.**
- Brightness slider is at the maximum (right edge).
- Idle timer doesn't fire during transmission (the screen doesn't
  dim or auto-lock even if you'd normally have a 30s timeout). Test
  with a long message and Settings → Display → Auto-Lock = 30
  Seconds; transmission must complete without lock.

**FR-11:** On end (natural or aborted), both must be restored.

**Procedure.** Same as above; observe Control Center brightness
slider after the transmission ends or after a tap-to-abort.

**Pass criteria.** Brightness slider returns to whatever it was
before; auto-lock resumes its previous timeout.

---

### FR-12 — Per-flip jitter < 10 ms

This is the timing fidelity test. Procedure documented in detail in
`docs/timing.md` §3 ("On-device measurement procedure"). Quick
summary:

1. Add temporary `os_log`-based instrumentation around the
   `applyIfCurrent` block in `Transmitter.swift`:
   ```swift
   import os
   private let timingLogger = Logger(subsystem: "morsebeacon",
                                     category: "timing")
   // inside the scheduled callback:
   let now = DispatchTime.now().uptimeNanoseconds
   let expectedNs = UInt64(target) * 1_000_000
   let deltaUs = (Int64(now) - Int64(expectedNs)) / 1000
   timingLogger.log("tick \(tick.elementIndexInMessage) Δ=\(deltaUs)µs")
   ```

2. Build Release, install, transmit `PARIS PARIS PARIS PARIS PARIS` at
   20 WPM.

3. Collect logs:
   ```sh
   xcrun simctl spawn booted log show --predicate \
     'subsystem == "morsebeacon"' --info --last 5m \
     > timing.txt
   ```
   (For physical device: `log collect --device <udid>` then open the
   logarchive in Console.app and filter by subsystem.)

4. Parse and compute percentiles:
   ```sh
   awk -F'Δ=' '/Δ=/ {print $2}' timing.txt \
     | sed 's/µs//' \
     | sort -n \
     | awk 'BEGIN{n=0}
            {a[n++]=$1}
            END{
              print "max:", a[n-1], "µs"
              print "p99:", a[int(n*0.99)], "µs"
              print "p95:", a[int(n*0.95)], "µs"
              print "p50:", a[int(n*0.50)], "µs"
            }'
   ```

**Pass criteria.**
- p99 |Δ| < 10 000 µs (10 ms).
- max |Δ| < 25 000 µs (25 ms) — outliers tolerated as long as p99
  is clean.

**Capture on failure.** The full `timing.txt`. Re-run with `Logger`
calls also recording thermal state (`ProcessInfo.thermalState`) and
low-power-mode state (`isLowPowerModeEnabled`) so we can correlate.

**Repeat under stress.**
- Hot device: leave the phone in the sun or run a CPU benchmark for
  10 minutes first.
- Low Power Mode ON.
- App is foregrounded but actively scrolling some other app's content
  (force a busy main queue).

If p99 fails under one of these, that's data for `docs/timing.md`'s
"known constraints" section — likely an acceptable failure mode rather
than a bug.

**Don't forget to remove the instrumentation before merging.**

---

### FR-22 — Reduce Motion caps WPM at 10

**Setup.** Settings → Accessibility → Motion → **Reduce Motion ON**.

**Procedure.**
1. Open Morse Beacon → Settings.
2. Try to drag the Character WPM slider above 10.

**Pass criteria.**
- Slider's max stops at 10, regardless of stored value.
- Caption "Capped at 10 WPM because Reduce Motion is on." visible.
- If the stored value was previously > 10 (e.g., 20), the value
  clamps down to 10 on appearance (`enforceCaps()` runs).

**Procedure 2.**
1. Toggle Reduce Motion OFF.
2. Re-open Settings.

**Pass criteria.** Slider now goes to 20; caption gone.

---

## 4. Non-functional requirements

### NFR-1 — Launch time < 500 ms on iPhone 12+

**Setup.** Cold launch — kill the app from App Switcher first.
Charging cable plugged in (so we eliminate low-power throttling).

**Procedure.**
1. Connect device, open Xcode → Product → Profile (Cmd-I).
2. Choose **App Launch** template.
3. Record one launch.

**Pass criteria.** Time-to-first-frame < 500 ms.

For a less-formal check, time it manually: tap home screen icon and
count Mississippi to first visible content. Should be < 0.5s, i.e.,
clearly faster than "one Mississippi".

**Capture on failure.** Save the Instruments trace. Common culprits
on a project this small would be:
- DispatchClock initialization triggering `DispatchTime.now()` cold
  paths. Should be sub-ms; if it's not, something else is wrong.
- `UserDefaults` first read for `safetyAcknowledgedV1` blocking on
  preferences daemon. Negligible.

---

### NFR-4 — Installed app size < 5 MB

**Setup.** Archive Release; install via Xcode Organizer.

**Procedure.**
- Settings → General → iPhone Storage → find Morse Beacon → note "App
  Size".

**Pass criteria.** App size < 5 MB.

(Simulator measurement is 1.9 MB; device may be slightly different
due to architecture-specific stripping.)

---

## 5. Documented gotchas (CLAUDE.md)

These are not bugs to file — they're documented constraints that need
note in the App Store description / first-run notes if they affect
user perception.

### 5.1 Auto-Brightness override

Settings → Display & Brightness → Auto-Brightness ON.

**Behavior.** During transmission, our `brightness = 1.0` engages, but
iOS may smoothly drift the brightness back toward what it thinks is
appropriate for the ambient light. The flash area starts pure white
but may dim slightly over a long transmission.

**Acceptance.** Document in app description. Cannot be programmatically
disabled (Apple removed that API in iOS 11+).

### 5.2 True Tone / Night Shift warming

Settings → Display & Brightness → True Tone, Night Shift.

**Behavior.** Both warm the white point. Pure white from our flash
area becomes yellowish at high warmth settings. Affects optical
detectability at distance.

**Acceptance.** First-run notes / About screen could mention these
should be off for best signaling range. (Not done in v1; consider
for v1.1.)

### 5.3 Low Power Mode brightness clamp

Settings → Battery → Low Power Mode ON.

**Behavior.** iOS clamps maximum brightness to ~80% in Low Power Mode.
Our `1.0` request is honored as "as bright as the system will let us",
not literally 100%.

**Acceptance.** Document. Possibly detect `ProcessInfo.processInfo
.isLowPowerModeEnabled` and warn the user before transmission. Not
done in v1.

### 5.4 Thermal throttling

After ~5 minutes of sustained 1.0 brightness on a phone in a warm
environment, iOS may dim the screen.

**Procedure to verify.** Run a continuous loop of 30-second
transmissions for 10 minutes. Observe whether brightness stays at
maximum throughout.

**Acceptance.** Outside v1 scope. If reported as a problem, mitigation
is to limit single-transmission length or auto-cooldown between
transmissions.

---

## 6. Edge cases / interruptions

### 6.1 Phone call mid-transmission

**Setup.** Have someone call the test phone, or use FaceTime from
another device.

**Procedure.**
1. Start a long transmission.
2. Have the call come in mid-transmission.

**Pass criteria.**
- Call UI appears.
- Brightness restored (the call UI is at normal brightness).
- After call ends/declined, app is on input view, not mid-transmission.

The current implementation handles this via
`UIApplication.didEnterBackgroundNotification` triggering
`Transmitter.abort()`. AVAudioSession-based interruptions specifically
are not yet wired (we don't use audio in v1) — defer until Phase 3.

### 6.2 Notification banner mid-transmission

**Setup.** Send yourself a Slack/Mail/etc. notification.

**Procedure.** Have the notification arrive during transmission.

**Pass criteria.** Banner appears as overlay; transmission continues
underneath. Not a bug if so — banners don't background the app.

### 6.3 Lock button mid-transmission

**Procedure.** Press the side/lock button during transmission.

**Pass criteria.** Same as backgrounding (AC-5): screen turns off,
brightness restored, app on input view when reopened.

### 6.4 Charge cable plug/unplug

Should have no effect. Test it anyway just to confirm.

### 6.5 Low-battery warning

**Setup.** Drain to ~20%; the system will offer Low Power Mode.

**Procedure.** Tap "Continue" on the LPM dialog, then transmit.

**Pass criteria.** Modal dismisses, app continues. Brightness clamped
per §5.3 above.

---

## 7. Sign-off

When all of the above pass:

- [ ] Smoke test (§1) all green
- [ ] AC-1, AC-2, AC-3, AC-5 (§2) verified on iPhone 12 or newer
- [ ] FR-10, FR-11, FR-12, FR-22 (§3) verified
- [ ] NFR-1, NFR-4 (§4) verified
- [ ] Gotchas (§5) documented or accepted
- [ ] Edge cases (§6) tested
- [ ] Timing instrumentation removed from `Transmitter.swift`
- [ ] Bundle ID is the real production one, not `com.example.morsebeacon`
- [ ] Privacy policy hosted at the URL in App Store Connect
- [ ] Screenshots regenerated at App Store-required resolutions
      (`./scripts/take-screenshots.sh` after booting a 6.7" sim)
- [ ] First TestFlight build distributed to at least one external
      tester for a real-world night-time line-of-sight test

Then submit to App Store Connect.

---

## What's intentionally NOT in this checklist

- **Watch companion** — out of scope for v1 per PRD §2 non-goals.
- **Haptic / audio channels** — Phase 2 / 3 per PRD §10 / §11.
- **Camera flash transmission** — out of scope.
- **VoiceOver full walkthrough** — labels are in place but full a11y
  audit is a separate concern; defer until first user report.
- **Localization** — English-only in v1.
