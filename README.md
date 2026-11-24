# Ashen Build

> **Alpha.** Ashen Build is incomplete and under active development, and version 1.0 is in App Store review. Attack rating and spell buff now use the game's own parameters, but some parts are still simplified (see [Accuracy and data](#accuracy-and-data)). Treat the numbers as a planning aid.

**A unified min-max builder for Dark Souls III, on iPhone.**

Ashen Build is a model for optimization in games. Every choice that shapes a character (starting class, attributes, weapon, infusion, armor, rings) feeds one calculator, and an optimizer searches the alternatives around it. You can test your own methods and theories on paper (a respec, a ring setup, a heavier armor set) without spending souls, Pale Tongues, upgrade materials or hours of play.

The question it answers: **is my build optimized enough, and what would be better?**

**Try the alpha on iPhone:** [TestFlight public link](https://testflight.apple.com/join/xMFAM1cS) (opens once Apple approves the first beta build).

<p>
  <img src="docs/screenshots/1-start.png" width="180" alt="Start screen">
  <img src="docs/screenshots/2-stats.png" width="180" alt="Attributes you can type">
  <img src="docs/screenshots/3-optimize.png" width="180" alt="Optimization score and findings">
  <img src="docs/screenshots/4-weapons.png" width="180" alt="Weapon grid with attack rating for your character">
  <img src="docs/screenshots/5-summary.png" width="180" alt="What each ring changes">
</p>

## What works today

| Area | Status |
|---|---|
| Starting classes (all 10) with correct base stats and starting gear (weapons, shield, catalyst, spells, armor, ring) | Done |
| Attributes: type a value or use the stepper; values below the class base are refused | Done |
| HP, FP, stamina, equip load, roll thresholds (fast / mid / fat) | Done, per-level wiki tables |
| Rings: pick a ring, then its +1 / +2 / +3 level; no duplicates | Done (76 variants) |
| Ring effects for *your* build, e.g. "AR 121 → 145 at or below 20% HP" | Done |
| Weapon grid showing the attack rating your character would get with each weapon | Done (284 weapons, shields, catalysts and ranged weapons, base game and both DLCs) |
| Three slots per hand; tap a slot in Summary to hold it and every number follows | Done |
| Upgrade level typed directly (+0 to +10, or +5 for unique weapons) | Done |
| Attack rating from the game's parameters: every infusion, every upgrade level, scaling curves | Done |
| Catalysts (staves, talismans, chimes, pyromancy flames): spell buff per school | Done |
| Spells: attunement slots, FP cost, requirements, which catalyst can cast them | Done (106 spells) |
| Weapon buffs (spell buffs and resins), with a check for which weapons can take a buff | Done |
| Armor sorted by any stat (poise, lightning, bleed, weight…), absorption combined as in the game | Done (360 pieces) |
| Optimizer: score, findings, Rosaria respec, best infusion, strongest weapons | Done |
| Armor min-max search for a target roll and poise floor | Done |
| Spell damage per cast, damage against enemy defenses | Not yet |
| Damage penalty when stat requirements are not met | Not yet (the app warns instead) |

## How the optimizer works

**Respec at Rosaria.** Soul Level and starting class stay fixed. The optimizer first sets the floors: the class base, your own targets for Vigor, Endurance and Attunement, enough Vitality for the roll you want, and the stat requirements of both weapons (ring bonuses included, two-handing counted). Each remaining point then goes to the damage stat that adds the most attack rating. Scaling only flattens as a stat rises and each stat contributes independently, so this greedy pass finds the best split for the model. Points that add almost no damage go to Vigor, then Endurance.

**Verdict.** Your current attack rating is compared with the best respec that keeps the same Vigor, Endurance, Attunement and Vitality. The app also flags wasted points, stats past their soft caps, how far you are from the next roll threshold, and which starting class would have reached the same stats at a lower level.

**Alternatives.** Every infusion of your weapon, and every weapon in the catalog with its best infusion, is evaluated with its own respec at the same upgrade progress and roll.

**Armor.** For a chosen stat, roll and optional poise floor, the search checks every combination of the four armor slots after removing pieces that another piece in the same slot beats on weight, the chosen stat and poise at once.

The same approach (a calculator for derived stats, constraints, an objective and a search) is not specific to one game, which is why the project is framed as a model for game optimization.

## Accuracy and data

- **Weapons, catalysts and scaling curves** come from the game's parameter files (patch 1.15.2, regulation 1.35) as extracted by [heyobi/ds3-frame-dps](https://github.com/heyobi/ds3-frame-dps) (MIT). Attack rating uses the game formula: base damage per upgrade level, scaling correction and the stat curve for each damage type. Unit tests check it against known in-game values (for example a +10 Longsword at 40/40, and Pyromancy Flame / Saint's Talisman spell buff).
- **Armor** values (absorption, poise, resistances, weight) come from the game data collected in [3dots/ds3optimizer](https://github.com/3dots/ds3optimizer).
- **Shields, bows, spells, weights and starting gear**, and the HP / FP / stamina / equip-load tables, were checked against the community [Fextralife Dark Souls III wiki](https://darksouls3.wiki.fextralife.com/) (November 2026).
- Values are numbers and game facts; descriptions in the app are written for this project.
- Known gaps: spell damage per cast is not modelled (catalysts show spell buff); shields and ranged weapons show base attack only; the damage penalty for unmet requirements is not modelled; the Follower Torch weight is unverified.

## Build and run

Requirements: Xcode 26 or later, iOS 17+ simulator or device.

```bash
open AshenBuild.xcodeproj
```

Tests:

```bash
xcodebuild test -project AshenBuild.xcodeproj -scheme AshenBuild -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Code map: game data in `AshenBuild/GameData/*.json`, stat curves in `Formulas.swift`, build math in `BuildCalculator.swift`, search and verdict in `Optimizer.swift`, SwiftUI screens in `AshenBuild/Views`.

## Roadmap

1. Spell damage per cast and the requirement penalty.
2. Damage against enemy defenses and motion values.
3. TestFlight beta ([public link](https://testflight.apple.com/join/xMFAM1cS), see [AppStore/README.md](AppStore/README.md)), then the App Store.

## How it was built

Product idea, feature design, decisions and testing by the author. The code was written with Claude Code (Anthropic) under the author's direction and checked in the iOS simulator and with unit tests.

## Legal

Ashen Build is an unofficial, fan-made tool. It is not affiliated with, endorsed, sponsored or approved by FromSoftware or Bandai Namco Entertainment. Dark Souls and all related names are trademarks of their respective owners and are used only to identify the game this tool is for. The app contains no game assets; the icon and interface are original. The app collects no data; builds are stored only on the device.

## License

[MIT](LICENSE)
