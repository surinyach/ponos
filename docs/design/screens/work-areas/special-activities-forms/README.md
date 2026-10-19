# Ponos · Special Activities Create/Edit (card-free) — v1

This package is the approved **card-free form** direction, translated into canonical SVG/PNG references for Codex.

## Where to put it

Copy `docs/design/screens/work-areas/special-activities-forms/` into the Ponos repository at the same path.

## Source of truth

- `svg/` — 16 editable SVG masters (4 states × 4 canonical viewports).
- `reference/` — 16 corresponding PNGs, directly rasterized from SVG at **exact 1× native dimensions**.
- `special-activities-forms.spec.json` — layout coordinates, typography, colors, and responsive rules.
- `components/` — input/button appearance reference.

Viewports: 390×844 mobile, 500×700 compact desktop, 768×1024 medium, 1440×900 expanded desktop.

States: `create-empty`, `create-filled`, `edit-current`, `edit-filled`.

## Critical approved design constraint

**Do not render a white parent card/container around the form.** Name and Description fields sit directly on the existing Ponos app background. Individual input surfaces remain white with a thin outline. No form shadow.

Keep the existing theme, branding, left rail/bottom navigation, responsive scrolling, 48dp targets and interaction semantics. The SVGs are references, not a request to replace production branding/navigation assets.

## Functional boundaries

- Name required, description optional.
- No priority, daily targets, dates, or time-tracking fields in Special Activities create/edit.
- Date belongs to logged work, not to the Special Activity.
- Retain controller/repository rules, error feedback, duplicate-name handling, save behavior, unsaved-change protection, and existing deletion safeguards.
- Delete appears as a secondary red outlined action on Edit, according to the approved visual direction; reuse the existing confirmation and restrictions.
- Example `Test` is illustrative, never production data.
- The drawings do **not** establish character limits. No counters or new validations should be introduced without backend/domain support.
- Focus Area and Archived Focus Area redesigns are out of scope.

## Conformance workflow

1. Review current route/shell structure; do not duplicate the adaptive shell inside forms.
2. Match at 390×844 and 1440×900 first, then 768×1024 and 500×700.
3. Compare screen captures with immutable PNG references, paying special attention to removal of the outer form card, field proportions, button positions, and navigation preservation.
4. Validate short-height and 200% text cases; scroll instead of shrinking targets/fonts.
5. Do **not** overwrite approved references or Flutter goldens before human approval.

The illustrative UI PNGs are not test goldens; Flutter goldens must be generated from Flutter after approval.
