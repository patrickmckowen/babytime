# BabyTime

Read BABYTIME.md for product vision and principles.

## Conventions
- iOS 26+ minimum deployment target
- "Liquid Glass" means the iOS 26 `glassEffect` API exclusively — blur materials (`.ultraThinMaterial`, etc.) are separate and fine to use for custom components

## Testing
- **Only run unit tests**: use `-only-testing:BabyTimeTests` when running tests
- **Always disable parallel testing**: use `-parallel-testing-enabled NO` to prevent simulator clone spawning
- **Always skip macro validation**: use `-skipMacroValidation` — required for SPM macro packages (StructuredQueries, Perception)
- **NEVER run BabyTimeUITests** — the UI test target spawns multiple simulator clones and causes out-of-memory crashes
- Build verification (`xcodebuild build`) is sufficient for UI-only changes
- A shared scheme exists at `xcshareddata/xcschemes/BabyTime.xcscheme` — do not delete it

## Git Workflow
- Default base branch for PRs: `main`
