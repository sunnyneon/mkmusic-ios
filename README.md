# MKmusic for iPhone

A small iPhone app that opens the fan app at **mkmusic.app/app** — the same screens as the Android app.

- Songs keep playing with the screen locked, with play/pause on the lock screen.
- Opens `mkmusic.app/app?source=ios`, so the website hides Buy, Join Premium and shop links (Apple rule).
  Premium members still get everything when they sign in.
- Links to other websites open in Safari.
- Shows a "Try again" screen when there's no internet.
- Offline: Premium members can download songs (stored by the website code in the app's storage).
  `WKAppBoundDomains` in Info.plist turns on the website's service worker inside the app, so it opens with no internet.

## How it gets built (no Mac needed)

Every push to `main` runs **Actions › Build iPhone app** on a GitHub Mac:
1. Makes the Xcode project from `project.yml`.
2. Builds the app.
3. If the 4 Apple secrets are set, signs it and sends it to **TestFlight**.

You can also run it by hand: **Actions › Build iPhone app › Run workflow**.

## Apple secrets (Settings › Secrets and variables › Actions)

| Name | What it is |
|---|---|
| `ASC_KEY_ID` | App Store Connect API key ID (10 letters/numbers) |
| `ASC_ISSUER_ID` | Issuer ID shown above the keys list |
| `ASC_KEY_P8` | The whole text of the downloaded `AuthKey_XXXX.p8` file |
| `APPLE_TEAM_ID` | Team ID from developer.apple.com › Account › Membership details |

## Settings

- App name: **MKmusic** · Bundle ID: **app.mkmusic** · iPhone only · iOS 16+
- Version: `MARKETING_VERSION` in `project.yml`. Build number = the Actions run number (goes up by itself).
- App icon: `MKmusic/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (1024×1024, no transparency).
