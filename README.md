# Pocket Outpost Tactics

**Small Squads. Big Strategies.** A bite-sized turn-based tactics + outpost-building game for iPhone (portrait, 3–5 minute battles), written in Swift with SwiftUI and SpriteKit.

- Website: https://surproductions.github.io/Pocket-Outpost-Tactics/
- Privacy policy: https://surproductions.github.io/Pocket-Outpost-Tactics/privacy.html
- Support: https://surproductions.github.io/Pocket-Outpost-Tactics/support.html
- Releases (signed IPA, checksum, screenshots): https://github.com/surproductions/Pocket-Outpost-Tactics/releases

## Design summary

| Pillar | Decision |
| --- | --- |
| Grid | **Square 7×9**, drawn as a 2.5D tabletop diorama. Compared with hexes, squares read better on a narrow portrait screen, give bigger touch targets (7 columns ≈ 52 pt each), and make range/flanking rules obvious (Manhattan distance). |
| Combat | Deterministic: `damage = attack − defense − cover` (minimum 1) + listed bonuses. Every attack is previewed before you confirm. |
| Terrain | Meadow/Trail (open), Forest (cover −1, costs 2), Ruins (cover −1), High Ground (+1 ranged damage), Snow (costs 2), Boulder/Water (impassable). Barricades block and give −1 damage to adjacent units. |
| Turn | Each unit may move (in several steps) and act once. Raiders act after you. |
| Objectives | **Eliminate** (defeat all raiders and reinforcements) and **Defend** (keep the gate standing for N rounds). |
| Stars | Win · lose no one · finish within par rounds. |

### Classes

| Class | HP / ATK / DEF / MOV / Range | Ability (cooldown) | Passive |
| --- | --- | --- | --- |
| Guardian | 16 / 5 / 2 / 3 / 1 | Shield Wall (3): +2 DEF, adjacent allies take −1 damage until your next turn | Frontliner |
| Ranger | 10 / 5 / 0 / 3 / 2–3 | Precision Shot (3): range 2–4, +2 damage, ignores cover | Can't hit adjacent; +1 from high ground |
| Scout | 11 / 4 / 1 / 5 / 1 | Dash (3): +3 movement and keep leftover movement after attacking | Flank: +2 if another ally touches the target |
| Engineer | 12 / 3 / 1 / 3 / 1–2 | Field Kit (2): build a barricade, or repair an ally or structure by 4 | Support |
| Raider | 8 / 4 / 0 / 4 / 1 | — | Hunts wounded/fragile targets |
| Raider Archer | 7 / 4 / 0 / 3 / 2–3 | — | Keeps its distance |
| Heavy Brute | 15 / 6 / 2 / 2 / 1 | Smash (3): +3 damage | Double damage to barricades and the gate |
| Thornjaw, Warlord | 24 / 6 / 2 / 3 / 1 | Smash (3) | Chapter-1 boss |

Levels 1–5 come from XP (+2 HP per level, +1 ATK at levels 2 and 4, +1 DEF at level 3).

### Enemy AI
`TacticalAI` is a deterministic utility AI. For every reachable tile it scores the best action from that tile (damage ×10, kill +50, wounded/fragile targets, gate pressure in Defend missions, Smash value) plus position (threat from the player's possible attacks next turn, cover, high ground, archers keeping range). With nothing in reach, units advance along a distance field toward the gate or the nearest hero, and walk "through" barricades at a high cost so Brutes break walls. The same AI plays the player's side in tests to prove missions are winnable.

### Campaign
- **Greenwood Frontier** (10 handcrafted): First Watch · Eyes in the Trees · Hold the Gate · Brookside Ambush · Archer's Ridge · The Long Night · Brute Force · Burning Barricades · Raider Camp · Warlord of the Wood.
- **Dustfall Canyon**, **Frostwatch Pass**, **Ember Ruins**: 5 seeded, connectivity-checked missions each (`MapGenerator`), with veteran enemy levels and a warlord finale. Each needs the previous chapter plus Command Center level 2/3/4.
- **Daily Skirmish**: the same seed for everyone each day; rewards once per day.

### First five minutes
1. Title → outpost diorama → "Raiders spotted!" → **First Watch**: a coached Guardian-only fight teaching select/move/attack.
2. Rewards (60 supplies) → guidance arrow on the **Watchtower** → upgrade with dust and sparkle (Rangers +1 damage). Ranger joins.
3. **Eyes in the Trees**: ranged-positioning tutorial on high ground.
4. Campaign map reveals the chapter path and the next outpost milestone. No ads or paywalls anywhere in onboarding.

### Economy
Coins (cosmetics), Supplies and Timber (upgrades), XP (squad levels). First clears pay in full; replays pay 40%. Building costs and effects are in `Outpost.swift`; tests check that chapter 1 pays for the Watchtower right away and for the Command Center by the end.

### Retention and monetization
Daily Skirmish, three-star mastery, upgrade goals and new regions. No forced ads, no energy, no streak penalties, and nothing for sale affects combat. Coins buy cosmetic banners; one optional **Supporter Pack** (StoreKit 2 non-consumable, product ID `<bundle id>.supporterpack`) unlocks a golden banner, with Restore Purchases. Rewarded ads are deliberately left out of v1.0 so the app stays SDK-free and "Data Not Collected"; the reward hooks (`applyVictory(bonusMultiplier:)`) are ready if they're added later.

## Architecture

```
Packages/GameCore/            Pure Swift, platform-independent, fully unit tested
  TacticalGrid/               GridPoint, Terrain, Structure
  Units/ Abilities/           Classes, stats, abilities
  BattleEngine/               BattleState: movement, targeting, damage, abilities, turns, outcome
  EnemyAI/                    Utility AI + auto-play simulator
  Missions/ Campaign/         Mission format, 10 handcrafted maps, seeded generator, chapters
  Outpost/ Economy/           Buildings, costs, effects, PlayerProfile (save file), rewards
  Progression/ Persistence/   XP curve, stat growth, atomic JSON saves
PocketOutpostTactics/         iOS app (SwiftUI + SpriteKit)
  App/                        App entry, GameStore (state/navigation), BattleController
  Scenes/                     Art (procedural Core Graphics art), BattleScene, OutpostScene
  Screens/                    Title, Outpost, Campaign, Battle HUD, Squad, Banners, Settings
  DesignSystem/ Audio/ Haptics/ Analytics/ Monetization/ Resources/
PocketOutpostTacticsUITests/  Critical-path UI tests
docs/                         GitHub Pages site: privacy policy, support, landing page
fastlane/metadata/            App Store listing text
scripts/                      CI signing, simulator picker, icon generator
```

All art (units, tiles, props, buildings, icon) is drawn procedurally in code, and all sound effects are synthesized at launch, so the game ships with no third-party or licensed assets.

## Build and test

Requirements: macOS with Xcode 26 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
swift test --package-path Packages/GameCore   # rules, AI, economy, saves, auto-play
xcodegen generate
open PocketOutpostTactics.xcodeproj           # set your team, then Run
```

## CI/CD and signing

`.github/workflows/ios.yml` runs on a macOS runner on every push to `main`: GameCore tests → UI tests on an iPhone simulator → App Store screenshots (6.9") → archive → export IPA → GitHub Release `v1.0.0` (IPA + SHA-256 + screenshots zip) → TestFlight upload.

Signing reads encrypted repository secrets (never committed). Either option works:

**A. Certificate + profile (manual signing)**
| Secret | Content |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | `base64 -i dist.p12` (Apple Distribution certificate + private key) |
| `P12_PASSWORD` | Password of the .p12 |
| `BUILD_PROVISION_PROFILE_BASE64` | `base64 -i profile.mobileprovision` (App Store or Ad Hoc) |
| `KEYCHAIN_PASSWORD` | Optional, any random string |

Team ID, bundle ID and export method (App Store vs Ad Hoc) are read from the profile.

**B. App Store Connect API key (automatic signing)**
| Secret | Content |
| --- | --- |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY` | Contents of `AuthKey_XXXX.p8` (raw or base64) |
| `APPLE_TEAM_ID` | 10-character Team ID |
| `APP_BUNDLE_ID` | Optional, defaults to `com.surproductions.pocketoutposttactics` |

Common alternative secret names are also recognised (see the workflow). The "Configure signing" step logs which inputs were found, never their values. With an API key present, App Store builds are also uploaded to TestFlight (the app record must exist in App Store Connect first).

An App Store-signed IPA installs through TestFlight/App Store only. An Ad Hoc IPA installs only on devices registered in its profile.

See [APP_STORE.md](APP_STORE.md) for the submission checklist.
