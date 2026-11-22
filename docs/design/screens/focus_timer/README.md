# Ponos Focus Timer — Visual Conformance Bundle

This folder is intended to live under `docs/design/screens/focus_timer/` in the project, following the same component-folder pattern as the other Ponos screen design bundles.

## Contents

- `README.md` — usage notes and implementation guardrails.
- `focus_timer.spec.json` — original concept layout and conformance metadata.
- `design_rules.md` — non-negotiable UI/behavior guardrails for implementation.
- `reference/` — screenshots of the original timer concept.
- `prototype/focus-timer.html` — historical interactive visual concept.

## Scope

This bundle records the original visual concept. Its screenshots, prototype,
and measured geometry predate the approved compact mobile refinements and
focus-only sessions; they are not exact baselines for the current app. The
current Flutter presentation and the approved refinements take precedence.
The prototype is illustrative and does not implement No rest.

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

1. One execution has a Focus phase and an optional Rest phase. Entering 0 in
   the Rest minutes field selects **No rest**; Focus duration stays positive.
2. Reset is available only while paused.
3. Save-partial vs discard appears only from reset flow.
4. Focus Areas and Special Activities remain valid selectable work items.
5. Do not add new timer capabilities not present in the app.

## Notes for the implementer

- Use the screenshots and prototype as historical visual references; do not
  infer current layout or behavior from them where approved refinements differ.
- Mobile uses a compact full-height composition with configuration beneath the
  timer and scrolling when content cannot fit. Desktop retains its left-aligned
  timer/configuration composition. During an execution configuration is read-only.
- With No rest, Focus completes and persists immediately with zero rest time,
  without a Rest-start alert. A positive Rest duration retains the existing
  Focus-to-Rest transition.
- The domain rules are documented in `../../../focus-timer-domain-rules.md`.
