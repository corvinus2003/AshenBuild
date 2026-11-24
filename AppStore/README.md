# TestFlight and App Store

Ashen Build ships to **TestFlight first**. App Review guideline 2.2 keeps betas off the App Store, so the alpha stays on TestFlight until the catalogs and the attack-rating model are complete.

| | |
| --- | --- |
| Bundle ID | `io.github.corvinus2003.ashenbuild` (can never change once published) |
| Team | 83S5G3QWTM |
| App Store Connect app ID | 6837857514 |
| TestFlight public link | https://testflight.apple.com/join/xMFAM1cS (group "Public Alpha") |
| Version | 1.0 (build 3) submitted to App Review 2026-11-24; TestFlight alpha 0.1.0 (2) |
| Store texts | [metadata/en-US.md](metadata/en-US.md) |
| Screenshots 1.0 | [screenshots-1.0/](screenshots-1.0/) (6.9", 1320×2868) and [screenshots-1.0-6.3/](screenshots-1.0-6.3/) (6.3", 1206×2622, required) |
| Privacy policy | [docs/privacy.md](../docs/privacy.md) |
| Privacy manifest | `AshenBuild/PrivacyInfo.xcprivacy` (UserDefaults, reason CA92.1; no data collected) |

## Build

```sh
scripts/testflight.sh            # signed package in ~/Library/Developer/AshenBuild/export
scripts/testflight.sh --upload   # same, then upload to App Store Connect
```

Builds go outside OneDrive on purpose: OneDrive locks freshly written files and the export step times out.
Raise `CURRENT_PROJECT_VERSION` (build number) before every new upload.

## Checklist

App Store Connect, once
- [x] My Apps ▸ + ▸ New App: iOS, name "Ashen Build", language English (U.S.), bundle ID `io.github.corvinus2003.ashenbuild`, SKU `ashenbuild`
- [x] App Privacy: Data Not Collected, published; privacy policy URL from metadata
- [x] Age rating: 13+ (references to weapons: Frequent; everything else None)
- [x] Category Reference / Utilities, price Free, Content Rights: yes

Each build
- [x] `scripts/testflight.sh --upload` (0.1.0 build 1)
- [ ] Answer export compliance if asked (the app sets `ITSAppUsesNonExemptEncryption = NO`)

TestFlight external testing
- [x] Test Information: beta description, what to test, feedback email, privacy URL (texts in metadata)
- [x] Create an external group, add the build, submit for Beta App Review (internal group "Team" too)
- [x] Turn on the public link and share it

Before App Store 1.0
- [ ] Full weapon and armor catalogs, exact attack-rating model
- [x] Version 1.0, App Store texts and screenshots, submitted for review (2026-11-24)
- [ ] Keep "Dark Souls" out of the name, subtitle, keywords and screenshots (guideline 5.2.1)
