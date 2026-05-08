# Privacy Policy — Morse Beacon

**Effective date:** [date of first App Store release]
**Author:** Vincent Bruijn (info@vincentbruijn.nl)

This is the privacy policy for the iOS app **Morse Beacon**. It is
short because the app collects nothing and sends nothing.

## What data we collect

**None.**

Specifically:

- We do **not** collect any personal information.
- We do **not** collect any usage data, analytics, or telemetry.
- We do **not** track you across apps or websites.
- We do **not** use cookies, advertising identifiers, or any other
  identifiers.
- We do **not** use the camera, microphone, location services,
  contacts, photos, or any other sensitive data source.
- We do **not** use any third-party SDKs or libraries.

## What data we store

**Locally on your device only:**

- Your last typed message (so it's there when you reopen the app).
- Your timing preferences (PARIS or Farnsworth, words-per-minute).
- A flag recording that you've acknowledged the photosensitivity
  warning, so we don't show it on every launch.

These are stored using Apple's standard `UserDefaults` mechanism,
which writes them to your device's local app sandbox. They never
leave your device. There is no cloud sync, no backup to our servers
(we have no servers), and no way for us to access this data.

## What we send over the network

**Nothing.**

The app makes no network calls of any kind. This is enforced at the
build level: a CI check (`scripts/check-no-network.sh`) fails the
build if any networking primitive (`URLSession`, `URLRequest`,
`Network` framework, etc.) is referenced anywhere in the source code.

The only `URL` the app uses is `mailto:info@vincentbruijn.nl` on the
About screen. Tapping that opens your device's Mail app; the
Morse Beacon app itself does not send the email.

## Children's privacy

The app is suitable for all ages. It collects no data, so the
COPPA / GDPR-K rules around children's data simply do not apply.

The app does include a photosensitivity warning at first launch
because rapid flashing light can trigger seizures in people with
photosensitive epilepsy. The warning must be explicitly acknowledged
before any flashing occurs. Adult supervision of younger users is
recommended for any app or content with flashing visuals.

## Changes to this policy

If a future version of the app starts collecting data (it won't, but
just in case), this policy will be updated and the change date noted
above. The first release commits to the "no data collection" stance
described here.

## Contact

Privacy questions: **info@vincentbruijn.nl**
