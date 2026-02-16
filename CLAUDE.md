# BabyTime

Read BABYTIME.md for product vision and principles.

## Tech Stack
- iOS 26+, SwiftUI
- CloudKit for multi-caregiver sync
- Swift 6, strict concurrency

## Conventions
- Use Swift's new Observation framework (@Observable)
- Prefer semantic design tokens over hardcoded colors/sizes
- Prefer SwiftUI, but UIKit is fine for custom components and advanced interactions
- "Liquid Glass" means the iOS 26 `glassEffect` API exclusively — blur materials (`.ultraThinMaterial`, etc.) are separate and fine to use for custom components

## Testing
- **Only run unit tests**: use `-only-testing:BabyTimeTests` when running tests
- **NEVER run BabyTimeUITests** — the UI test target spawns multiple simulator clones and causes out-of-memory crashes
- Build verification (`xcodebuild build`) is sufficient for UI-only changes
- Unit tests (BabyTimeTests) are pure logic with in-memory SwiftData — they run in seconds

## Git Workflow
- Default base branch for PRs: `main`
