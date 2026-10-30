# Ember Grove

A cozy focus game for iPhone. Every minute you focus in the real world keeps a small ember spirit's fire alive, and slowly brings a frozen grove back to life.

**Core loop:** start focusing → do real work → collect Glow, Seeds, visits from friends and discoveries → watch Ember and the grove change → choose what grows next → focus again.

## Building

**No Mac?** [TESTFLIGHT.md](TESTFLIGHT.md) explains how GitHub builds the app and sends it to TestFlight, all from your iPhone.

**With a Mac:**

Requirements: Xcode 15 or later, iOS 17 or later, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
cd EmberGrove
xcodegen generate
open EmberGrove.xcodeproj
```

Before running on a device:

1. Set your **Development Team** for both targets (Signing & Capabilities).
2. Change the bundle IDs (`com.example.embergrove`) and the App Group (`group.com.example.embergrove`) to your own. The App Group string also appears in `Shared/SharedModels.swift` as `AppGroup.identifier`, and in `project.yml`.
3. Enable the **App Groups** capability for the app and the widget extension, and **iCloud → Key-value storage** for the app. Only the app needs iCloud key-value storage, and the iCloud sync setting won't work without it.

Run the unit tests with ⌘U. They cover the level curve, timer math, rewards, renewals, path choice and quests.

## What's inside

| Area | Files |
|---|---|
| Character art (vector, animated, shared with widgets) | `Shared/EmberFigure.swift` |
| World art (12 restorable places, companions, sky, weather) | `EmberGrove/Views/World/GroveScene.swift` |
| Game content (areas, landmarks, companions, cosmetics, curios, chapters, quests, achievements) | `EmberGrove/Model/Content.swift` |
| Rules engine (XP, evolution, rewards, renewals, quests, milestones) | `EmberGrove/Model/Progression.swift` |
| Save data and the date-based timer | `EmberGrove/Model/GameState.swift` |
| Store, persistence, iCloud | `EmberGrove/Engine/` |
| Generated ambient sound and effects | `EmberGrove/Engine/SoundEngine.swift` |
| Widgets and Live Activity | `EmberGroveWidgets/EmberWidgets.swift` |

All art is drawn in code with SwiftUI `Canvas`, and all audio is synthesized at runtime. There are no image or sound files except the app icon, which is a rendering of Ember.

## Game design summary

- **Glow (XP):** 10 per focused minute. Bonuses: +20% for finishing a timer, +10% for stopwatch sessions of 25 minutes or more, and +25% "rested glow" on your first session after 36 hours away. Coming back is rewarded, never punished. Ending a session early keeps every minute.
- **Evolution:** Spark (Lv 1) → Kindle (Lv 4) → at Lv 8 you choose a path: **Hearth**, **Bloom** or **Starlight** → second form (Lv 15) → final form (Lv 25). Each path changes Ember's look and grants small passive abilities.
- **Renewals:** reached at focus-time milestones (45 min, 2 h, 4 h, … about 57 h in total). Each renewal lets you pick which place to restore next, and in which of two variants.
- **Areas:** Willowbrook opens at 3 h of focus, the Old Oak at 10 h and Starlit Ridge at 25 h. The Star Shrine stays hidden until you find the Star Map.
- **Companions:** seven creatures. Each one moves in when its place is restored, keeps you company during sessions, and gives gifts and memories at 3, 6 and 10 hearts.
- **Discoveries:** 17 curios, found randomly during sessions of 10 minutes or more. Longer sessions find more.
- **Story:** 9 chapters, triggered by milestones.
- **Quests:** 3 daily and 2 weekly, all optional, with rewards you claim yourself.

Typical pace at 1–2 hours of focus a day: the first evolution choice in a few days, a new restoration every day or two, and the full grove in a few months.

## Extending

`GameContent` is a data catalogue (`GameContent.grove`). To add a world or storyline, add another catalogue and drawing functions for it. `GameState` already records `characterId` and `worldId` for this. Adding a landmark means writing one entry in `Content.swift` and one drawing case in `GroveRenderer.drawLandmark`.
