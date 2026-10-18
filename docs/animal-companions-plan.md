# Animal companions and the shared cup

Status: the shared cup renderer and all seven animals are implemented in a consistent polished 3D storybook style. The liquid uses one shared water material and normalized cup shape, with the usable interior bounds and paw contours calibrated to each bundled illustration. Giraffe, monkey, and pig unlock at 30, 60, and 90 consecutive qualifying local calendar days.

## Agreed experience

- Replace belly filling with an oversized transparent cup held by the animal.
- Keep the face visible, with paws around the cup sides and blue water waving inside.
- Use the same normalized liquid shape, blue material, relative fill level, and wave behavior for every animal. Calibrate the interior bounds and paw clipping to each bundled glass illustration; the flattened cup drawings have slightly different dimensions.
- Keep the water gently moving at a 60 fps target while partly full and active; a successful hydration log adds a damped slosh. At the daily goal, two unequal translucent rivulets spill over the front rim and down the glass. Their wet paths stay mostly fixed while independent thickness pulses travel downward; beads collect at the glass base and occasionally fall. Further credited drinks briefly widen the flow. Alcohol does not move the water; Reduce Motion and inactive scenes pause it.
- Start with panda, fox, rabbit, and capybara in a consistent polished 3D storybook cartoon style.
- Preserve each starter animal's current pose, colors, transparent background, and shared cup placement while simplifying fur and shaping the cartoon finish.
- Make all four available immediately, without purchases or unlock requirements.
- Choose an animal through illustrated cards in Settings. Done saves the selection; dismissing the sheet cancels the draft, matching daily-goal editing.
- Add exclusive animals: giraffe at 30 consecutive days, monkey at 60, and pig at 90. A day qualifies with at least one saved drink that has positive hydration credit. Reaching the daily goal is unnecessary; alcohol alone does not qualify.
- A missed day resets an unfinished streak. An earned animal remains unlocked permanently.

## 1. Establish the panda and cup artwork

Create and review the panda style sample before revising the remaining starter animals.

- Preserve rounded features and the warm palette while using smooth stylized 3D forms, simplified fur, expressive faces, and gentle cartoon shading.
- Use one transparent canvas size across the collection. Keep the cup aligned between each animal's hands and torso, and calibrate the liquid bounds and paw contours against the bundled artwork.
- Give the cup enough space to make its level readable on an iPhone, including near-empty and near-full states.
- The current art flattens the glass and paws into the body image. Render the body and moving head, then liquid clipped to the calibrated interior and paw contours, followed by overflow streams behind the same paw mask and goal sparkles. A separately rendered shared glass would require new artwork layers.
- Review the panda at empty, quarter, half, and full levels in light and dark mode before making the other animals.

Acceptance: the panda visibly holds the cup, water stays inside its interior, and the face and paws are never tinted by the water.

## 2. Implement the shared companion renderer

- Add a small `AnimalKind` model with stable identifiers, display names, and bundled artwork names.
- Replace `PandaView` with an animal-aware `CompanionView`; update its caller in `ContentView` and register added/renamed Swift files in the Xcode project.
- Reuse the existing wave paths, spring fill transition, goal sparkles, and animation pausing for Reduce Motion, inactive scenes, and settled empty states. Full cups keep the overflow flowing; Reduce Motion shows static streams.
- Animate only the head layer. Keep the body, cup, liquid clipping, and paw contours in the same stationary artwork canvas.
- Map 0–100% to each illustrated cup’s inner floor and front rim. Clip around the paw silhouettes with a small safety margin. Use normal alpha compositing so animal fur does not change the water’s hue. Copying parts of the flattened body above the water also copies empty glass and belly pixels, leaving pale holes. Recalibrate bounds and contours if the bundled artwork changes.
- The panda uses a measured fur contour without a glass-side safety buffer. Positive coverage landmarks require the bright glass between fingers to fill blue, while separate dark-fur landmarks must remain untinted.
- At goal, fill the oval opening through to the back rim, connecting it to the main liquid below the front rim. Calibrate this surface to each glass perspective and keep the opening filled while overflow runs; the front rim alone leaves the cup looking underfilled.
- Gate the brim and overflow with the same spring-interpolated level as the liquid waves. `@State` holds the animation target immediately, so a target-based full check or separate opacity delay makes the brim appear before the visible water reaches it. `CupTopVisibility` fades them in only over the final 0.5% of the presented fill.
- Follow the physical cues and rendering limits in [water-overflow-research.md](water-overflow-research.md). Avoid full-length sine bends and bright closed outlines. The Canvas uses transparent edge shading as an optical approximation, not background refraction.
- Run `python3 scripts/check-water-rendering.py` after renderer or artwork changes. It checks the interior separately for relative fill height, paw coverage, exterior leaks, water color consistency, and over-goal clamping in light/dark at 2× and 3×. Separate complete renders check overflow at the rim and below the inner floor, downward pulse movement between phases, paw protection, bounded coverage, and absence below goal. These fixed-phase rendering checks do not exercise the live log-triggered animation or measure frame rate. Visually inspect the generated `.build/water-review` images and live animation too; the checks protect calibrated landmarks rather than recognizing artwork semantically.
- Use `python3 scripts/check-water-rendering.py --transition-only` for the focused brim regression: the logical goal is 100% while the animatable presentation inputs span 25–99%. The brim and spill must remain absent until the visible water reaches the rim. Also check a real log transition in the isolated simulator; the deterministic samples do not replace SwiftUI runtime verification.
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
