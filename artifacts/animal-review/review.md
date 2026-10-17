# Animal code and UI review — 2026-10-17

Reviewed the current source snapshot, since this workspace has no Git history available. Scope: the four starter companions, shared water renderer, Settings selection, persistence integration, and the agreed future 30/60/90 day collection. Assumed a single user on a native iPhone app with local storage.

## Findings

### 1. P2 — Full water escapes the illustrated cup and tints foreground artwork

**Evidence:** `PandaSip/Views/PandaView.swift:80-98` draws a generic liquid mask over the entire flattened animal PNG. At full progress, `LiquidWave.path` puts the surface at the mask's top (`:165-170`). The PNG already contains the cup rim, paws, and overlapping chin, so these cannot occlude the liquid.

**Reproduction:** render each `AnimalKind` using the unchanged `PandaView` at progress 1.0. All four show blue beyond the illustrated inner rim and over the inner paws. Panda and rabbit also show blue against the chin/mouth area. This occurs in both appearances; progress 1.25 correctly clamps to the same flawed full state. Earlier partial-fill screenshots did not expose this defect.

**Fix:** align the liquid mask to the illustrated cup interior for each asset, then composite a foreground rim/paws/overlapping-chin layer after the liquid. An animal-specific foreground exclusion mask is another option. The fox's horizontal offset alone does not fix foreground occlusion or vertical bounds. Lowering the full level alone cannot reliably protect the paws.

**Impact if left:** reaching the goal breaks the main character animation. This violates the explicit acceptance condition in `docs/animal-companions-plan.md:24-28` that water stays inside the cup and does not tint faces/paws.

Evidence: [light fill matrix](fill-levels-light.png), [dark fill matrix](fill-levels-dark.png). Columns: Panda, Fox, Rabbit, Capybara. Rows: 0%, 25%, 50%, 100%, 125%.

### 2. P3 — The written plan does not record the approved unlock roster and milestones

**Evidence:** `docs/animal-companions-plan.md:64-72` describes only a 30-day milestone and says the roster still needs to be settled. The conversation approved giraffe at 30 days, monkey at 60, and pig at 90. The status at `:3` also still describes the other starter art as awaiting its panda-style update, although those assets have been replaced.

**Fix:** record the approved roster and thresholds and refresh the starter-art status. Keep genuinely unresolved rules (retroactive history, travel/time zones, deletion behavior) explicit.

**Impact if left:** the next implementation can follow an obsolete specification, omit the 60/90-day rewards, or reopen decisions that were already made.

## Collection coverage and implementation gap

| Animal | Availability | Review result |
|---|---|---|
| Panda | Free | Style matches approved direction; full-fill defect above |
| Fox | Free | Style matches; horizontal offset works at partial levels; full-fill defect above |
| Rabbit | Free | Style matches; full-fill defect above |
| Capybara | Free | Style matches; full-fill defect above |
| Giraffe | Planned 30 days | No catalog entry, artwork, unlock state, or UI to review |
| Monkey | Planned 60 days | No catalog entry, artwork, unlock state, or UI to review |
| Pig | Planned 90 days | No catalog entry, artwork, unlock state, or UI to review |

The exclusive collection remains a deferred feature, rather than a regression introduced by the recent art changes. `PandaSip/Models/Animal.swift:1-5` contains only the four starters. `SettingsView.swift:47-50` displays that catalog without locking or milestone progress. There is no implemented streak counter or persisted earned-animal set. The three exclusive animals cannot receive a visual or behavioral sign-off until those assets and flows exist.

## Checks completed

- Independent read-only code review of the renderer, catalog, Settings, Today integration, storage, and existing checks. The reviewer corroborated the reproduced full-fill defect; speculative future failures were excluded from findings.
- Production simulator build passed.
- Existing `Tests/CoreChecks.swift` passed: catalog/fallback, hydration factors and history, persistence, deletion, goal validation, local date/DST behavior, corrupt-file preservation, failed-save rollback.
- Temporary native review app used the production `PandaView`, models, Settings, and asset catalog without changing production source. Visually reviewed every starter at 0/25/50/100/125% in light/dark appearance. Over-goal clamping and accessible fill labels behaved as expected.
- Largest accessibility Dynamic Type size: picker stacks into one column; animal names and selected state remain readable, including Capybara. [Screenshot](picker-largest-text.png).
- Original app restored with Panda selected. Hydration file SHA256 remained `f5738085a89ea40e132107ff2b0b0da1c7d379de2fc9d9bb6e2ada646ef39a21`. Temporary review app removed.

## Limits and recommended regression check

No production code or artwork was changed by this review. Screenshots and this report are the only project additions.

The existing Foundation checks do not exercise rendering or prove that asset names resolve. Add a small full-fill rendering regression check across all catalog entries when fixing finding 1; include the future exclusive animals when they exist.

Full VoiceOver speech/navigation, runtime Reduce Motion switching, physical-device frame rate/memory, smaller devices, and landscape were not exercised in this pass. Reduce Motion handling and accessibility semantics were inspected in source; the native accessibility tree exposed animal names, selection state, and clamped fill descriptions. Settings largest-text layout was exercised in light appearance, while the fill matrix covered both appearances.

Verdict: fix the full-fill rendering before avatar sign-off. Unlockables remain unreviewable until implemented.

## Implementation follow-up — 2026-10-17

- Finding 1 is fixed: the shared `CupInterior` mask now stays inside the illustrated rim and clear of the paws at full progress. A native preview matrix confirmed all four starter animals at 0%, 25%, 50%, 100%, and 125%; the screenshots above remain the original pre-fix reproduction.
- Finding 2 is fixed: the plan now records the approved giraffe (30 days), monkey (60 days), and pig (90 days) milestones and the completed starter-art status.
- The exclusive animals remain planned, so their art and unlock behavior still cannot receive a UI review. Retroactive history, timezone changes, deleted entries, and progress messaging remain open rules.
- The production simulator build and existing model checks passed. After an in-place install and launch, the hydration JSON SHA256 remained `f5738085a89ea40e132107ff2b0b0da1c7d379de2fc9d9bb6e2ada646ef39a21`; Panda remained selected.
