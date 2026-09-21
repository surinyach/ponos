# Manual Work Entries and Special Activities domain rules

These rules are fixed requirements. They define expected behavior independently
of Flutter widgets, state management, database structure, and API implementation
details.

## Manual Work Entries

- Every Manual Work Entry belongs to exactly one work subject: either one Focus
  Area or one Special Activity, never both and never neither.
- An entry stores focused time and rest time.
- Either duration may be zero, but their combined duration must be greater than
  zero.
- The user explicitly selects the work date.
- Manual entries have no start or end timestamps.
- Manual entries can be edited and deleted.
- Their focused and rest durations contribute to calculations in exactly the
  same way as durations recorded by Focus Timer executions.
- A manual entry assigned to a Focus Area contributes to that area's applicable
  daily progress.
- A manual entry assigned to a Special Activity contributes to totals but does
  not introduce a target or compulsory streak requirement.

## Special Activities

- A Special Activity represents punctual, non-recurring work associated with
  one specific local calendar day.
- It has no daily targets, priority, or target end date.
- It is excluded from compulsory priority-based streak rules.
- It can be selected as the work subject of a Focus Timer execution.
- It can receive Manual Work Entries.
- It can be archived instead of deleted.
- Archiving preserves its existing timer executions, manual entries, and their
  contribution to historical totals.
- Its focused and rest time contributes to daily, weekly, and overall totals.

## Shared attribution and reporting

- Timer executions and Manual Work Entries each belong to exactly one Focus
  Area or Special Activity.
- The selected work subject determines attribution; time must not be counted
  against both subject types.
- Special Activity time is included in time totals while remaining excluded
  from Focus Area target and compulsory priority-based streak calculations.
- Historical reporting continues to include entries and executions belonging
  to archived Special Activities.

These requirements are the source of truth for the upcoming database schema,
API contract, backend implementation, and Flutter integration.
