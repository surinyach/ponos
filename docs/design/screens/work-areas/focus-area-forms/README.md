# Ponos · Focus Area Create/Edit — WA-07B v1

Implementation-ready visual reference package for the **approved Focus Area Create/Edit proposal**.

## Install
Extract at the repository root. All files are under:
`docs/design/screens/work-areas/focus-area-forms/`

## Contents / precedence
- `svg/` — 18 **editable SVG masters** (4 states × 4 viewports, plus two mobile scrolled-state proofs).
- `reference/` — 18 **direct 1× PNG rasters** from exactly those SVG masters.
- `components/` — priority-selection palette P1–P5 and warning examples, SVG + PNG.
- `focus-area-forms.spec.json` — layout, typography, palette, and business/interaction boundaries.

The screenshots are stable design references, **not** Flutter goldens. Do not regenerate/overwrite them during implementation.

## Approved compositions
- Header/back anchored top-left to standard Ponos page insets, as in Edit Focus Area and Special Activities.
- On desktop (1440×900), the **Details** and **Weekly targets** surfaces are two balanced white outlined cards centered in the main content; actions centered below them.
- On mobile (<600) panels stack vertically. On medium and narrow desktop they also stack naturally; **vertical scrolling** exposes all weekdays and controls, with nothing covered by navigation.
- Keep the approved Ponos navigation system: mobile bottom nav, desktop/web lateral rail, expanded sidebar at ≥1200. Maintain production brand assets; symbolic SVG branding is illustrative.
- Use the exact existing Ponos palette, Inter, page margins, button shapes, borders and ≥48dp interactive hit regions.

## Functional rules — do not infer new rules from drawing fixtures
- Create + Edit support required Name, optional Description, Priority and optional Finish date; dates in the past are allowed.
- In new/edited forms, **choose from priority P1–P5**. P1 highest urgency; approved palette runs red→sage as urgency decreases.
- **Important legacy compatibility**: Existing saved P6+ values must not be overwritten on view/save just because the new picker offers only P1–P5; if necessary surface the currently saved numeric value separately and preserve until user explicitly changes it. Existing P5+ badges all use the sage palette.
- On Edit, destructive secondary action is **Archive Focus Area**, *not Delete Focus Area*. Archived-only permanent deletion stays in the separate archived management flow.
- Monday through Sunday; when a day is enabled its target must be **any integer >0**. Do not impose increments of 5 or 15 minutes. Disabled day has no required target. Historical target versioning is preserved.
- Finish-date expiry begins the calendar day after the date: yellow 1–14 days, red from 15 days; do not automatically archive expired areas. Warnings are independent of priority color.
- Existing form Save/Create, Cancel/Back, unsaved-change handling, errors/loading and mutation invalidation are preserved.
- All on-screen names, minute values, dates and suggested defaults are **illustrative fixture data**, not production data or new requirements.

## Visual-validation order
1. Match desktop 1440×900 and mobile 390×844 using the same source SVG/PNG/spec trio.
2. Match Medium 768×1024 and Compact Desktop 500×700 with true platform-dependent navigation.
3. Verify `mobile-scrolled` proofs: all seven weekday targets and action buttons reachable after scrolling; no overlay hides rows.
4. Validate 320×568 and 390×844 at 200% text, long names, negative/error values, keyboard focus/48dp controls.
5. Keep design refs immutable and defer golden regeneration until human visual approval.

## Scope
These files are documentation/reference assets only. No Flutter/backend source or tests are included.
