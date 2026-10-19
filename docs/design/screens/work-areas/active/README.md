# Ponos · Work Areas / Active Focus Areas — visual references v3

## Scope

This package covers **only the approved Active Focus Areas view** in the Work Areas destination, including its archived-list entry control and Focus Area warning variants. It does **not** invent unapproved Archived-detail pages, Special Activity forms, or edit forms; those require their own design approval.

## The authoritative files

- `svg/` — four **canonical 1x SVG masters**: 390×844, 500×700, 768×1024, 1440×900.
- `reference/` — four immutable **PNG renderings generated directly** from those same SVG masters at exact 1x size.
- `work-areas-active.spec.json` — measured canonical geometry, visual tokens, samples, constraints, and behavior.
- `components/focus-area-states.svg` and `.png` — illustrated card variants + the compact **View archived** control; these are reference artifacts, **not** production assets.

The original approved collage is a design direction, not a pixel-accurate viewport export. These native-size SVG/PNG pairs make the design implementable and consistently comparable. The canonical references adapt the collage to **Ponos's already approved navigation** (Overview / Work Areas / Focus / Log Work), theme and breakpoints; the collage's placeholder navigation links must not be implemented.

## Approved structure

**Exactly two top-level tabs:** `Focus Areas` (selected) and `Special Activities`.

`View archived (3)` is a compact **secondary action inside Focus Areas**, not a third tab. It opens the archived Focus Areas view and returns to the preserved Focus Areas tab. `New Focus Area` is the page's primary action. Mobile places the two controls in one compact row.

Each card is selectable to edit, with an independently accessible menu for Archive (confirmation required). Focus Areas are ordered numerically ascending (`P1`, `P2`...), tied by stable ID, never by a priority-rewriting manual reorder control.

Expired records remain in the active list: **1–14 completed days** after finish date show yellow + warning icon + text; **15+ days** show red + warning icon + text. On the finish date they are not yet expired; no automatic archiving. The reference fixture day is **13 October 2026** and the sample expiry ages are 6 and 18 days. Real UI computes local-day differences at runtime.

Targets after the expiration date are not applicable; the sample expired cards say `No target today`. Zero is not a valid enabled weekday target. The daily progress summary uses illustrative numbers only: real data must come from existing contracts/providers, never be hard-coded into production.

## Canonical navigation and responsiveness

- Mobile Compact `<600`: bottom navigation, 64dp branding header, 72dp bottom bar.
- Medium `600–839`: lateral navigation rail.
- Desktop/web: lateral navigation at **all widths**, collapsed below 1200, expanded sidebar at 1200+.
- `500×700` is desktop, not mobile. The narrow desktop screenshot represents a scrollable list viewport.
- Work Areas is a list-style management page and should **scroll naturally** when content or enlarged text requires it. Unlike Overview, no single-screen requirement exists for all rows.
- Preserve >=48dp hit targets, Inter typography, keyboard focus, safe-area handling, and 200% text scaling. Cards should grow naturally outside the exact canonical sample viewports.

## Integration and conformance

1. Copy the `docs/` tree to the repository root, preserving paths.
2. Implement with existing Flutter components (`PonosPageScaffold`, `PonosInlineTabs`, `PonosButton`, `PonosCard`, `PonosSectionHeader`, `WorkAreaBadge`) and existing runtime branding/assets. **Do not copy PNGs into `app/assets/`**.
3. Match **one canonical viewport at a time** against `reference/`, using `work-areas-active.spec.json` as the measured contract. Recommended order: **390×844 → 1440×900 → 768×1024 → 500×700**.
4. Compare `render → diff → correct → rerender`; Flutter goldens measure implementation stability, not reference fidelity.
5. Do not overwrite SVG masters, reference PNGs, or spec to hide implementation discrepancies. Only update Flutter goldens after human approval.
6. Functional rules and existing backend/data contracts win over any illustrative copy or numeric example in a static design reference.

## Important limitations

The SVGs are static visual masters. Interactive focus behavior, menus, animations, scrolling beyond viewport edges, and edit/archive workflows must be implemented and tested in Flutter. Illustrative strings and counts are not runtime data. The assets in this package are reference design deliverables, not production image dependencies.

## Priority color update (v3)
The Active canonical SVG/PNG pairs and `focus-area-states` examples have been updated to the unified urgency palette: P1 red, P2 orange, P3 amber, P4 pale yellow, and P5+ all the same subdued sage. Use `../shared/priority-colors.spec.json` as the authoritative mapping and keep expiration alert backgrounds unchanged. This is only a styling change, not a change in priority ordering or streak rules.

## Priority color update (v3)
The Active canonical SVG/PNG pairs and `focus-area-states` examples have been updated to the unified urgency palette: P1 red, P2 orange, P3 amber, P4 pale yellow, and P5+ all the same subdued sage. Use `../shared/priority-colors.spec.json` as the authoritative mapping and keep expiration alert backgrounds unchanged. This is only a styling change, not a change in priority ordering or streak rules.
