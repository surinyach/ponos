# Ponos Overview — Visual Conformance References

## Source of truth

1. `svg/` — approved design masters.
2. `reference/` — immutable 1x PNG rasterizations used for direct visual comparison.
3. `overview.spec.json` — exact canonical geometry, typography, colors and behavior.
4. Flutter goldens — snapshots of the approved implementation only; they are not design references.

## Canonical implementation order

Match and obtain human approval one viewport at a time:

1. `1440x900` desktop
2. `390x844` mobile
3. `768x1024` medium
4. `500x700` compact desktop

At each viewport, render Flutter at the exact size, compare it against the corresponding PNG in `reference/`, correct the implementation, then request human visual approval. Do not overwrite the reference PNGs.

## Data

Numbers shown in the design are illustrative. Production widgets must use real provider/API values while preserving the exact formatting and geometry of the reference.
## Today pillar placement

The Greek pillar in the Today card is intentionally inset further from the card edges and action row. Use the exact `greek_pillar_bounds` and `greek_pillar_transform` values in `overview.spec.json` for the canonical viewports. Do not push the asset against the card border or action controls.

