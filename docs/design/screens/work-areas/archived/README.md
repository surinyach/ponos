# Ponos · Archived Focus Areas visual references (v3)

## Import
Extract ZIP at the **repository root**, preserving `docs/design/screens/work-areas/...`.

## Contents
- `archived/svg/`: 8 editable SVG masters (Archived list and read-only details, 390×844 / 500×700 / 768×1024 / 1440×900).
- `archived/reference/`: 8 exact-size 1× PNGs directly rasterized from the matching SVGs.
- `archived/components/`: Restore and permanent-delete dialog vector illustrations / matching PNGs.
- `../shared/priority-palette.svg` and `.png`: shared 8-badge color progression. `../shared/priority-colors.spec.json` contains the exact P5+ fallback. Updated `active/components/priority-badges.svg` also included.
- `archived/work-areas-archived.spec.json`: precise geometry and styling plus behavior/gating.
- `archived/concept/`: original moodboard for comparison, **NOT** a pixel-accurate master.

## Authority
SVG masters are authoritative for layout, component geometry and styling. The PNGs in `reference/` are derived at **exact 1×**, never from Flutter goldens. The concept moodboard is only an artistic reference; its proportions are not canonical. The actual reusable Ponos branding and icons already live under `app/assets/` and Flutter; no replacement runtime font files or emblems are supplied.

## Key requirements
1. Keep Archived within the Focus Areas context, reached via the compact `View archived` button.
2. Archived list and details use readable, content-driven cards and maintain existing navigation behavior. Details are read-only.
3. Priority urgency progression: **P1 red, P2 orange, P3 amber, P4 pale yellow, P5 and every N>=5 the same muted sage** badge in BOTH Active and Archived. Numeric label continues to show P6/P7/etc. Sort priority numerically ascending then stable ID. See `../shared/priority-colors.spec.json`.
4. Expiration warning yellow (1–14 days) / danger red (15+ days) treatments on active cards take precedence over optional priority-based **card fill**. The *priority badge* itself remains correctly colored.
5. Strong outlines `#B7C8D9` and lateral navigation 1 px divider `#A4B8CC`, consistent with approved shared shell.
6. Preserve current backend constraints for restore and permanent deletion. For destructive confirmation, honor the existing double warning when historical work exists.
7. **Do not implement unapproved functionality automatically.** Search field, extra historical time totals, an archived-time snapshot, and a Restore confirmation dialog are VISUAL EXAMPLES only; use them only if already supported by current API/product behavior. Otherwise omit them and preserve the approved layout rhythm.
8. Keep inputs/actions ≥48dp hit targets, 200% text scaling, overflow-safe scroll and keyboard navigation.
9. Validate each canonical viewport against its SVG and PNG. Flutter golden baselines are updated only **after** human visual approval.

## Recommended Codex sequence
- WA-05A: introduce consistent priority badge color mapping in Active Focus Areas (and shared badge).
- WA-05B: archived list and navigation route implementation.
- WA-05C: read-only details + approved Restore/Delete behavior.
- WA-05D: one-viewport-at-a-time visual conformance; verify loading/error/empty, accessibility, responsive; human approval before goldens and commits.

## Palette update in v3
The archived and active canonical SVGs/PNGs in this ZIP have **new badge colors only**. Existing geometry, navigation, card spacing and expiration treatments are unchanged. The old concept PNG illustrates an older palette and is not authoritative for color. Do not restyle expiration cards based on priority.

## Palette update in v3
The archived and active canonical SVGs/PNGs in this ZIP have **new badge colors only**. Existing geometry, navigation, card spacing and expiration treatments are unchanged. The old concept PNG illustrates an older palette and is not authoritative for color. Do not restyle expiration cards based on priority.
