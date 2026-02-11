# Napkin

## Corrections
| Date | Source | What Went Wrong | What To Do Instead |
|------|--------|----------------|-------------------|
| 2026-02-11 | user | Didn't check `.git/config` for remote URL, asked user instead | Always check `.git/config` for remote info before asking |
| 2026-02-11 | self | Tried running bash commands in Explore mode | Remember: Explore mode = read-only, use Read/Glob/Grep tools only |
| 2026-02-11 | self | REBASE_HEAD existed but no rebase was active - stale file | Git state files can be stale; check `git status` for truth |
| 2026-02-11 | self | `git mv` into an existing empty dir nests instead of replacing | When `git mv A B` and B already exists as a dir, A goes INSIDE B. Check target doesn't exist first, or use temp names |

## User Preferences
- Ask questions, don't guess or assume
- Prefers thorough research before action
- Remote: https://github.com/patrickmckowen/babytime.git

## Patterns That Work
- Using Explore agent for full directory tree discovery
- Reading .git/config for repo metadata
- Feature branches for safe refactoring (reversible by deleting branch)
- PBXFileSystemSynchronizedRootGroup allows moving dirs without editing pbxproj (paths are relative to xcodeproj parent)
- Use temp names when moving dirs that collide (e.g., BabyTime_src → BabyTime)

## Patterns That Don't Work
- Glob can't find directories (like .xcodeproj) - it only finds files
- Bash commands blocked in Explore mode

## Domain Notes
- BabyTime: iOS SwiftUI app, iOS 26+, Swift 6, CloudKit
- Xcode 26.2 project using PBXFileSystemSynchronizedRootGroup (auto-sync with filesystem)
- .xcodeproj relative paths: BabyTime, BabyTimeTests, BabyTimeUITests (relative to xcodeproj parent)
- CODE_SIGN_ENTITLEMENTS = BabyTime/BabyTime.entitlements (relative to project root)
