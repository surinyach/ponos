

- Ready/setup: activity selector grouped by Focus Areas and Special Activities; editable focus/rest duration; start.
- Focus running: Focus label + countdown + laurel progress; Pause; Reset unavailable until paused.
- Focus paused: Resume + Reset, with save-partial vs discard confirmation dialog.
- Rest running/paused: Rest label, automatic entry from Focus, same pause/resume and reset rules.
- Completed: execution stored by existing app logic, completion feedback, ready to start another execution.
- Loading/empty/error: preserve current widgets and routes; redesign visuals only.

## Non-negotiable behavior

1. **One execution = one Focus phase followed by one Rest phase**. No multi-cycle counter, no automatic repeat toggle, no phase skipping.
2. One selected Work Area (regular Focus Area or Special Activity) per execution; configurable before starting the next execution.
3. Both phases can pause/resume. Reset available **only while paused**. Reset dialog offers Save partial or Discard; natural completion saves automatically.
4. Existing Riverpod, timestamp-based timing, local restoration, backend persistence, notifications and alarms are authoritative and must remain untouched.
5. Use the real project navigation — do not add Dashboard, Tasks, Planner, Analytics, Journal, or other invented screens.
6. Do not add new controls or timer behavior inferred from the concept art. Keep the existing validation, loading, error and retry flows.

## Laurel animation (implementable in Flutter)

- Render a fixed 30-leaf, two-branch laurel via `CustomPainter` or a vector asset; use primary blue for the discreet inner progress stroke and bronze for illuminated leaves. Keep leaf geometry consistent and motion minimal.
- As **elapsed time within the current phase** advances, illuminate leaves incrementally. Each phase has its own progress; reset progress at Focus→Rest. Focus and Rest also have explicit text labels; color alone must not communicate the state.
- In paused state, freeze decorative motion; reduce-motion settings should disable breathing while retaining static progress. The countdown must be driven by the existing Riverpod state, **not an animation clock**.
- An optional subtle scale pulse every ~4 seconds is decoration only and must not affect timers, notifications, or battery use.

## Review order

1. Desktop 1440×900, Ready and Focus running.
2. Mobile 390×844, Ready and Paused + reset dialog.
3. Rest and Completed variants; check 768×1024 and 500×700.
4. Ensure scrolling at 200% text scale, minimum 48px accessible tap targets, keyboard navigation, and reduced motion.
5. Treat screenshot text/metrics as illustrative; data, states, constraints, actions must map to existing implementation.
