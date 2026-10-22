# App Store submission checklist: Pocket Outpost Tactics 1.0.0

Everything you need to fill into App Store Connect. Text fields are also in `fastlane/metadata/en-US/` for copy and paste (or for `fastlane deliver`).

## 1. App record (App Store Connect → Apps → +)
| Field | Value |
| --- | --- |
| Platform | iOS |
| Name | Pocket Outpost Tactics |
| Primary language | English (U.S.) |
| Bundle ID | The one in your provisioning profile / `APP_BUNDLE_ID` secret (default `com.surproductions.pocketoutposttactics`) |
| SKU | `pocket-outpost-tactics-1` |

## 2. App information
| Field | Value |
| --- | --- |
| Subtitle | Small Squads. Big Strategies. |
| Category | Games → Strategy (secondary: Games → Board) |
| Content rights | Does not contain third-party content (all art and audio are generated in code) |
| Age rating questionnaire | Cartoon or Fantasy Violence: **Infrequent/Mild**. Everything else: **None**. No user-generated content, no web access, no gambling, no contests. Expected rating **9+**. |
| Privacy Policy URL | https://github.com/surproductions/Pocket-Outpost-Tactics/blob/main/PRIVACY.md |

## 3. App Privacy ("nutrition label")
Answer **"No, we do not collect data from this app."** That gives **Data Not Collected**. This matches the code (no analytics, no ads, no network calls; saves are local) and the bundled `PrivacyInfo.xcprivacy` (no tracking, no collected data types).

## 4. Pricing and availability
Free (recommended), or set a price tier. Choose territories.

## 5. In-app purchase (optional)
If you want the Supporter Pack live at launch:
- Type: **Non-Consumable**
- Product ID: `<your bundle id>.supporterpack` (for example `com.surproductions.pocketoutposttactics.supporterpack`)
- Reference name: Supporter Pack. Display name: Supporter Pack. Description: "Raise the golden Sunburst banner over your outpost. Cosmetic only."
- Price: Tier 2 ($1.99) suggested
- Review screenshot: the Banners screen
- Submit it **with** the 1.0 build (Version page → In-App Purchases → +)

If the product doesn't exist, the game simply hides the purchase card. Nothing breaks.

## 6. Version 1.0.0 page
| Field | Source |
| --- | --- |
| Screenshots (6.9" iPhone, 1320×2868) | `AppStoreScreenshots-6.9in.zip` on the GitHub Release, or the CI artifact `screenshots-and-logs`. Upload 01–06 in order. |
| Promotional text | `fastlane/metadata/en-US/promotional_text.txt` |
| Description | `fastlane/metadata/en-US/description.txt` |
| Keywords | `fastlane/metadata/en-US/keywords.txt` |
| Support URL | https://github.com/surproductions/Pocket-Outpost-Tactics/blob/main/SUPPORT.md |
| Marketing URL | https://github.com/surproductions/Pocket-Outpost-Tactics (optional) |
| Copyright | 2026 SUR Productions |
| Build | Select the TestFlight build uploaded by CI |
| App Review notes | `fastlane/review_notes.txt`; no demo account needed |
| Sign-in required | No |

The app is iPhone-only (`TARGETED_DEVICE_FAMILY = 1`), so iPad screenshots aren't required.

## 7. Export compliance
`ITSAppUsesNonExemptEncryption = NO` is set in Info.plist, so builds skip the encryption questionnaire.

## 8. Release
Submit for review → choose manual or automatic release.

## Already handled in the project
- App icon 1024×1024 (no alpha) in `Assets.xcassets`
- Launch screen (`UILaunchScreen`)
- Portrait-only, full screen, status bar hidden
- Privacy manifest `PrivacyInfo.xcprivacy`
- StoreKit 2 purchase + Restore Purchases (Settings and Banners screens)
- Version 1.0.0; the build number is the CI run number, so every upload is unique
- Built with the newest stable Xcode on the `macos-26` runner (iOS 26 SDK, as App Store Connect requires)
