# Work Areas shared priority palette (v3)

Reference master: `priority-palette.svg` (8 badges, P1 to P8). The directly-rendered 1x PNG is `priority-palette.png`. Machine-readable palette and boundary rule: `priority-colors.spec.json`.

**Implementation:** use priority 1, 2, 3, 4 with their respective color tier; all priorities **>= 5** must use exactly the same colors and still display their actual numeric label. Do **not** map beyond 5 to new colors or cycle. Applied to Active and Archived badges, list/cards/details. Expiration (yellow/red) remains a distinct, dominant card-state treatment.

The older v1 Active and v2 Archived reference packages are superseded by this package; keep existing geometry and navigation behavior.
