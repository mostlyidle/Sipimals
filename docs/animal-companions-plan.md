# Animal companions and the shared cup

Status: the shared cup renderer and all seven animals are implemented in a consistent polished 3D storybook style. The shared liquid mask is inset to keep full cups inside the glass across the collection. Giraffe, monkey, and pig unlock at 30, 60, and 90 consecutive qualifying local calendar days.

## Agreed experience

- Replace belly filling with an oversized transparent cup held by the animal.
- Keep the face visible, with paws around the cup sides and blue water waving inside.
- Use the same cup shape and liquid geometry for every animal. Keep the cup aligned with each animal's hands and torso; allow a small artwork-specific offset where needed to preserve that alignment (the fox uses 58% of the canvas width).
- Keep the water gently moving at a 60 fps target while partly full and active; a successful hydration log adds a damped slosh, and credited drinks that take the total over goal trigger a brief rim splash. Alcohol does not move the water; Reduce Motion and inactive scenes pause it.
- Start with panda, fox, rabbit, and capybara in a consistent polished 3D storybook cartoon style.
- Preserve each starter animal's current pose, colors, transparent background, and shared cup placement while simplifying fur and shaping the cartoon finish.
- Make all four available immediately, without purchases or unlock requirements.
- Choose an animal through illustrated cards in Settings. Done saves the selection; dismissing the sheet cancels the draft, matching daily-goal editing.
- Add exclusive animals: giraffe at 30 consecutive days, monkey at 60, and pig at 90. A day qualifies with at least one saved drink that has positive hydration credit. Reaching the daily goal is unnecessary; alcohol alone does not qualify.
- A missed day resets an unfinished streak. An earned animal remains unlocked permanently.

## 1. Establish the panda and cup artwork

Create and review the panda style sample before revising the remaining starter animals.

- Preserve rounded features and the warm palette while using smooth stylized 3D forms, simplified fur, expressive faces, and gentle cartoon shading.
- Use one transparent canvas size and shared cup interior and paw geometry across the collection. Position the cup to stay centered between each animal's hands and torso.
- Give the cup enough space to make its level readable on an iPhone, including near-empty and near-full states.
- Use an animal base behind the cup and transparent foreground paws over it. Keep the cup, liquid mask, rim, and glass highlights shared in SwiftUI so every animal uses identical fill geometry.
- Draw the layers in this order: animal base, cup background, clipped liquid, glass rim/highlights, foreground paws, goal sparkles.
- Review the panda at empty, quarter, half, and full levels in light and dark mode before making the other animals.

Acceptance: the panda visibly holds the cup, water stays inside its interior, and the face and paws are never tinted by the water.

## 2. Implement the shared companion renderer

- Add a small `AnimalKind` model with stable identifiers, display names, and bundled artwork names.
- Replace `PandaView` with an animal-aware `CompanionView`; update its caller in `ContentView` and register added/renamed Swift files in the Xcode project.
- Reuse the existing wave paths, spring fill transition, goal sparkles, and animation pausing for Reduce Motion, inactive scenes, and settled empty/full states.
- Pass the same daily hydration progress to the cup for every animal. Cap the displayed cup at full while keeping totals above the goal intact.
- Update Today headings and completion copy for the selected animal. Describe the cup's fill percentage in VoiceOver instead of saying the animal is full.
- Use a species-neutral, hydration-focused product name as the collection grows.

Acceptance: changing the artwork does not change hydration calculations, drink logging, history, goal handling, or the current day's progress.

## 3. Complete the collection and Settings picker

- Produce fox, rabbit, and capybara artwork using the approved panda proportions, palette, texture, cup position, and layer contract.
- Add an Animal section to Settings with illustrated cards, animal names, a selected indicator, and VoiceOver selected state. Let cards stack when larger text needs space.
- Keep the selection as a local draft while the sheet is open. Tapping a card previews that animal in the picker.
- On Done, validate and save the goal first. Commit the animal preference and dismiss only after the required goal save succeeds. Invalid goals or failed goal writes keep the draft open.
- Store the selected animal in a separate local preference, shared by Today and Settings. Default missing or unknown identifiers to panda.
- Retain the choice across relaunches. Changing animals keeps the same goal, history, and water level.
- Leave the existing hydration JSON schema untouched; this feature needs no drink-data migration.

Acceptance: all four animals are selectable, Done applies the choice, swipe dismissal cancels it, and existing installations retain their saved drinks.

## 4. Validate and deliver

- Add focused checks for the animal catalog and fallback behavior, plus isolated preference persistence where practical.
- Build the iOS simulator app and run the existing model checks.
- Verify all four animals at empty, partial, full, and over-goal progress; inspect paw overlap, clipping, wave movement, and Reduce Motion.
- Check light/dark appearance, large text, VoiceOver labels and selection states, Settings save/cancel/error paths, and relaunch persistence.
- Verify existing hydration data survives an in-place app update unchanged.
- Update README and screenshots to show the cup and animal picker.

Implementation can be split into bounded avatar/artwork and Settings/preference tasks once the shared interface is defined, followed by focused review. Avoid concurrent writers in overlapping files.

## Exclusive-animal unlocks

- Track qualifying local calendar days from saved positive-credit drinks; use calendar dates rather than 24-hour intervals.
- Existing drink history counts retroactively. A current streak remains active through the end of the day after the latest qualifying day; a missed day resets it.
- Persist earned animal identifiers separately from hydration JSON, so missing later days or deleting entries cannot revoke rewards.
- Show locked cards, milestone progress, and current streak in Settings. A locked animal cannot be selected.
- Keep the four starter animals free permanently.
- Date grouping follows the device's current local calendar. Changing time zones can regroup historical entries because entries do not record a time zone.

## Main risks

- Artwork alignment is the main visual risk: each animal's paws must match the shared cup without hiding the water level.
- Oversized artwork can crowd Today on smaller screens or with large text; preserve scrolling and the existing Log a drink action.
- Changing time zones can regroup saved entries and therefore change an unfinished streak; permanent unlocks remain earned.
