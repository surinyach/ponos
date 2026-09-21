# Focus Timer domain rules

These rules are fixed requirements for the Focus Timer. They define expected
behavior independently of Flutter widgets, state management, storage, and API
implementation details.

## Execution model

- One execution contains exactly one focus phase followed by exactly one rest
  phase.
- Focus and rest durations are configured before starting each execution.
- Each execution is linked to exactly one work subject: either a Focus Area or
  a Special Activity.
- The linked work subject remains fixed during an active execution, but a
  different Focus Area or Special Activity may be selected for the next
  execution.
- Neither phase can be skipped.

The valid natural sequence is:

```text
focus running <-> focus paused
      |
      | focus duration reached
      v
rest running <-> rest paused
      |
      | rest duration reached
      v
completed and persisted
```

## Pause and reset

- Both focus and rest phases support pause and resume.
- Reset is available only while the current phase is paused.
- A reset requires one explicit outcome:
  - Save the elapsed focus/rest work as a partial execution, then reset.
  - Discard the execution without saving it, then reset.
- Reset returns the timer to an inactive state; it does not advance or skip a
  phase.

## Completion and transition effects

- Reaching the configured focus duration automatically starts the rest phase.
- The automatic focus-to-rest transition triggers an alarm and a platform
  notification.
- Naturally completing the rest phase completes and persists the execution.
- Natural completion never offers a discard path.

## Accuracy and recovery

- Timer accuracy must be based on elapsed real time and must not depend on UI
  ticks continuing while the application is backgrounded.
- An active or paused execution must survive application closure and be
  recoverable with its work subject, configured durations, current phase,
  pause/running state, and elapsed progress intact.
- Recovery must not duplicate completion, persistence, alarm, or notification
  effects that were already handled.

## Local-day attribution

- An execution belongs entirely to the user's local calendar day on which it
  started, even when its focus or rest phase crosses midnight.
- Its day attribution is fixed at start and must not be recalculated from its
  completion time.

## State and persistence ownership

- Flutter owns the live timing logic and maintains a recoverable active-state
  snapshot using absolute timestamps and accumulated focus/rest durations.
- The backend stores only finished natural executions and partial executions
  that the user explicitly chooses to save.
- A discarded reset creates no execution record.
- Flutter sends the actual accumulated focus and rest durations; the backend
  does not reconstruct them from configured durations.
- Every persisted execution includes the immutable local `work_date` captured
  when it started. Daily queries use this value rather than `ended_at`.

These requirements are the source of truth for the upcoming timer domain
model, backend contract, persistence, Flutter state, and platform integrations.
