# Panda Sip

A native SwiftUI iPhone hydration tracker with original storybook animal companions and layered, animated water in a shared cup. Requires iOS 17+ and Xcode 16+; no third-party dependencies.

Previews: [Home](artifacts/home-light.png) · [History](artifacts/history.png) · [Drink picker](artifacts/drink-picker.png) · [Dark mode](artifacts/home-dark.png)

## Run

1. Open `PandaSip.xcodeproj` in Xcode.
2. Select the **PandaSip** scheme and an iPhone simulator.
3. Run. For a physical iPhone, choose your development team under Signing & Capabilities and use a unique bundle identifier.

The app starts with no sample entries. Log water, coffee, tea, soft drinks, juice, milk, sparkling water, sports drinks, or alcohol. Choose 250 mL, 500 mL, or a custom whole amount. The **Today** tab shows the panda and current progress; **History** browses individual days with a date picker and previous/next controls. Every drink, including alcohol, appears with its time, consumed volume, and goal credit. Each day shows separate consumed and credited totals, with newest entries first. Both tabs support deleting a sip.

Change the starting 2,000 mL goal in settings and tap **Done** to save. Choose the free panda, fox, rabbit, or capybara companion in the same screen. Giraffe, monkey, and pig unlock after 30, 60, and 90 consecutive local calendar days with at least one drink that adds goal credit. Existing drink history counts toward these rewards; alcohol-only days do not. Earned animals remain unlocked if drinks are later deleted. Invalid goals or failed writes keep settings open. Swiping the sheet away cancels unsaved edits; **Hide keyboard** only ends text editing. History shows daily totals rather than comparing earlier days to the current goal, because past goal settings are not stored.

## Goal credit

Goal credit is logged volume multiplied by a stored factor. These are **approximate water-content proxies**, not absorption percentages, a physiological hydration reading, or medical recommendations. Factors come from Table 2 of [Maughan et al. (2016)](https://citrusbr.com/wp-content/uploads/2021/03/2016-Maughan-OJ-vs-other-beverages-hydration-potential.pdf): water/sparkling water/tea 100%, black coffee 99%, regular cola/orange juice 89%, whole milk 88%, sports drink 96%. Broad categories use those example drinks; actual formulations vary. Alcohol receives 0% goal credit by app policy, while its consumed volume is retained. The study’s beverage hydration index is not used as a volume multiplier.

Entries retain the factor applied when logged. The display rounds the summed credit, rather than rounding individual entries before summing. The companion cup caps at full while totals can exceed the goal.

## Storage and animation

Data saves atomically to the app’s Application Support directory as `PandaSip/hydration.json`. Failed writes keep the previous state; unreadable files are preserved and block writes until successfully reloaded. Daily grouping uses the current local calendar. Today refreshes on significant time changes or app activation. History follows today across midnight unless a past day has been selected. Previously saved entries remain compatible; no migration is needed.

Original storybook panda, fox, rabbit, capybara, giraffe, monkey, and pig illustrations are bundled in `PandaSip/Assets.xcassets`. Two overlapping wave surfaces fill a shared tapered cup while the animal's face and paws stay clear. Multiply compositing preserves the painted texture. Liquid level rises with SwiftUI animation; the surface moves on a 60 fps animation timeline. Waves pause when the app is inactive, empty/full after settling, or Reduce Motion is enabled. Reduce Motion also disables the fill transition. Dynamic Type, VoiceOver labels, and adaptive light/dark colors are supported. The selected companion and earned animal identifiers are stored separately from hydration history.

Reminders, HealthKit, accounts, and cloud synchronization are outside this MVP.

## Checks

Run the Foundation/Observation model checks without a simulator:

```sh
swiftc -parse-as-library PandaSip/Models/Animal.swift PandaSip/Models/Drink.swift PandaSip/Models/HydrationStore.swift Tests/CoreChecks.swift -o /tmp/panda-sip-checks
/tmp/panda-sip-checks
```

Build for an iOS simulator without code signing:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project PandaSip.xcodeproj -scheme PandaSip -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/PandaSip-build CODE_SIGNING_ALLOWED=NO build
```
