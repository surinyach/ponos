# Ponos Focus Timer — Visual Conformance Bundle

This folder is intended to live under `docs/design/screens/focus_timer/` in the project, following the same component-folder pattern as the other Ponos screen design bundles.

## Contents

- `README.md` — usage notes and implementation guardrails.
- `focus_timer.spec.json` — layout and conformance metadata.
- `design_rules.md` — non-negotiable UI/behavior guardrails for implementation.
- `reference/` — canonical screenshots for approved timer states and breakpoints.
- `prototype/focus-timer.html` — interactive visual reference for the redesign.

## Scope

This bundle is for a **visual redesign only**.

Keep unchanged:
- timer business rules
- Riverpod/state machine logic
- local restoration and persistence
- notifications/alarms
- backend/API behavior

## Approved visual direction

- Reuse the established Ponos light palette, Inter typography, white cards, navy text, and bronze accent details.
- Make the countdown the primary element.
- Use the **laurel of effort** timer concept: leaves progressively illuminate with elapsed phase progress.
- Support these states visually:
  - setup / ready
  - focus running
  - focus paused
  - rest running
  - completed
- Preserve the real app navigation labels:
  - Overview
  - Work Areas
  - Focus
  - Log Work

## Important behavior constraints

1. One execution = one Focus phase followed by one Rest phase.
2. Reset is available only while paused.
3. Save-partial vs discard appears only from reset flow.
4. Focus Areas and Special Activities remain valid selectable work items.
5. Do not add new timer capabilities not present in the app.

## Notes for the implementer

- Treat the screenshots as the canonical visual reference.
- Use the HTML prototype to understand proportions and interaction composition.
- Validate the redesign against the checked-out `develop` branch before implementation, since this bundle was prepared from approved visual direction plus previously reviewed timer behavior rather than a live repo fetch.
