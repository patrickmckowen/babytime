# Graduated Duration Picker

A full-screen vertical scrubber for selecting timer duration. The user drags up/down to move a graduated scale past a fixed center indicator.

## Interaction

- Drag up increases value, drag down decreases
- Scale moves; indicator stays fixed at vertical center
- Haptic tick on each graduation crossing
- Snaps to nearest graduation on release

## Visual

- Graduations are horizontal lines stacked vertically
- Center indicator: thicker highlighted line
- Single dynamic label at center displaying current value (e.g., "12 min")
- Depth-of-field effect: graduations fade in opacity as distance from center increases
- Minimal: no chrome, no containers — just scale, indicator, label

## Graduation Density

| Range | Interval |
|-------|----------|
| 0–30 min | every 1 minute |
| 30–60 min | every 5 minutes |
| 60–120 min | every 15 minutes |

## Style

Inspired by mid-century analog instrumentation — graduated dial aesthetic. Calm, precise, tactile.
