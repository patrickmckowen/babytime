# Baby Time

## The Problem

New parents are exhausted and overwhelmed. The tools meant to help them—feed trackers, sleep trackers—are fragmented, cluttered, and slow. They add cognitive load instead of removing it.

## Core Belief

Know what's next without thinking. Calm tools for chaotic days.

## What This Is

A single app that answers one question: *What does my baby need next, and when?*

- Tracks feeding (time, volume, breast/bottle) and sleep only
- Shows the next activity at a glance with supporting context
- Calculates goals based on the child's age
- Supports multiple caregivers with real-time sync

## What This Isn't

- No activity types beyond feed and sleep
- No gamification, streaks, or badges
- No social features beyond caregiver sharing
- No ads, ever
- No complexity that doesn't serve the core question

## Principles

**Status-first, action-ready.**
Show the current situation clearly—awake time, last feed, last sleep. Let action availability signal readiness rather than explicit recommendations. Parents know their baby best; the app provides honest, accurate context.

**Forgiving by design.**
Timers can be started late, edited retroactively, adjusted. Life with a newborn is messy.

**Calm confidence.**
Reduce anxiety, never add to it. The app should feel like a quiet, competent partner.

**Minimal, not empty.**
Every element earns its place. Thoughtful details reward attention without demanding it.

**One-handed, half-asleep.**
Design for 3am, one arm holding a baby, brain at 40%.

## Key Scenarios

1. **The glance** — Parent checks phone in the middle of a busy day, sees current status at a glance. 
2. **The forgotten timer** — Feeding started 10 minutes ago, parent remembers, starts timer and adjusts start time back
3. **The handoff** — Partner takes over, opens app, has full context without a conversation
4. **The check-in** — Quick look at daily progress toward feed/sleep goals

## Scope Boundaries

- iOS native (Lock Screen widgets and Live Activities are future milestones)
- Multi-caregiver real-time sync is core, not an add-on
- Theming supported via semantic design tokens

## Design Decisions

### Status over Recommendations
The app shows facts (awake time, last activities) rather than prescriptive recommendations. This approach:
- Is always accurate (facts can't be wrong)
- Respects that every baby is different
- Reduces anxiety by avoiding "overdue" language
- Lets parents remain the decision-makers

### Contextual Action Buttons
Action buttons appear only when the activity enters its age-appropriate window. Button presence signals "ready when you are" without explicit instruction.
