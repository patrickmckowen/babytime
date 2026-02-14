# BabyTime Day Model

## Philosophy

The app does not plan the day. It reacts to what's actually happening and tells you what it means for what's left. Babies are unpredictable. The model embraces that — it never makes a parent feel behind schedule, because there is no schedule. There are only anchors, constraints, and the current moment.

## Inputs

Three settings. That's it.

| Input | Type | Purpose |
|---|---|---|
| **Bedtime** | Time (e.g., 7:00 PM) | The one fixed anchor. Means "put down at this time." |
| **Baby's birthday** | Date | Derives age, which drives all targets. |
| **Dream feed** | Toggle + time (optional) | For parents who do a late feed after baby is asleep. |

Everything else is derived from age and from what the parent actually logs throughout the day.

## How the Day Works

### The day begins when the first feed is logged.

There is no "wake time" setting. The baby wakes when the baby wakes. The first logged feed is the signal that the day has started. The app doesn't need to know the plan — it just needs to know what happened.

### The day ends at bedtime.

Bedtime is the single fixed point the entire model works backward from. All nap cutoff logic, final wake window calculations, and bedtime routine signals reference this anchor.

### Everything in between is reactive.

The app watches two running clocks at all times:

- **Time since last feed** — drives feed readiness
- **Time since last sleep ended** — drives wake window awareness

From these two clocks and the baby's age, the app derives everything the home screen needs.

## Age-Derived Targets

The app maintains a table of age-appropriate targets. These are not rigid rules — they are reference points that inform what the home screen surfaces.

### Wake Windows

Wake windows are **progressive throughout the day** — shorter in the morning, longer in the evening. The app does not prescribe when naps should happen. It simply knows how long the baby has been awake and whether that duration is within, approaching, or beyond the age-appropriate window for this point in the day.

| Age | Naps/Day | WW1 | WW2 | WW3 | WW4 | Last WW (to bed) |
|---|---|---|---|---|---|---|
| 0–2 mo | 4–5 | 45–60m | 45–60m | 45–60m | 45–60m | 45–60m |
| 3–4 mo | 3–4 | 1.25–1.5h | 1.5–1.75h | 1.5–1.75h | 1.75–2h | 1.75–2h |
| 5–7 mo | 2–3 | 1.75–2.5h | 2–2.75h | 2.25–3h | — | 2.5–3h |
| 8–10 mo | 2 | 2.5–3h | 3–3.5h | — | — | 3–4h |
| 11–14 mo | 1–2 | 3–4h | 3.5–4.5h | — | — | 3.5–4.5h |

*These ranges will be refined. The key principle is that the app knows which wake window the baby is in (first, second, last) based on how many naps have been logged today, and uses the appropriate range — not a single flat number.*

### Feed Intervals

| Age | Typical Interval | Expected Feeds/Day |
|---|---|---|
| 0–2 mo | 2–3h | 8–12 |
| 3–4 mo | 2.5–3.5h | 6–8 |
| 5–7 mo | 3–4h | 5–6 |
| 8–12 mo | 3.5–4.5h | 4–5 |

Feed intervals are measured from the *start* of the last feed. The app surfaces time since last feed and signals when the baby is approaching or within the next feed window.

### Nap Cutoff

This is the single most important derived constraint. It answers: **"Is there still room for a nap before bedtime?"**

```
nap_cutoff = bedtime − last_wake_window_for_age
```

For a 6-month-old with a 7:00 PM bedtime and a last wake window of ~2.5–3h, the nap cutoff is roughly **4:00–4:30 PM**. Any nap must end by this time, or it risks pushing bedtime.

The nap cutoff is not a single moment — it's a closing window. The app can signal:
- **Nap still possible** — there's time for a nap that ends before cutoff
- **Nap window closing** — a nap would need to be short
- **Nap window closed** — no more naps; bridge to bedtime

## Home Screen States

The home screen reflects reality. Based on the two running clocks and the derived constraints, the baby is always in one of these states:

### 1. Awake — Early in Wake Window
*She just woke up. No action needed yet.*

- Wake window counting up
- Feed timer counting from last feed
- All actions available
- Tone: calm, informational

### 2. Awake — Approaching Wake Window
*She's been up a while. Nap is an option soon.*

- Wake window visually signals it's approaching the age-appropriate range
- Feed status visible
- Sleep action becomes more prominent
- Tone: gentle awareness

### 3. Awake — Beyond Wake Window
*She's been up longer than typical. She may be getting overtired.*

- Wake window signals she's past the typical range
- Sleep action is prominent
- Tone: calm urgency, not alarm

### 4. Asleep — Nap in Progress, No Time Pressure
*She's napping. All is well.*

- Sleep timer counting up
- Feed status paused or secondary
- Nap cutoff time visible but not urgent
- Tone: restful, quiet

### 5. Asleep — Nap Approaching Cutoff
*She's napping, but needs to wake soon to protect bedtime.*

- Sleep timer shows time remaining until cutoff
- "Wake by [time]" becomes visible
- Tone: heads-up, not stressful

### 6. Asleep — Nap Must End
*She needs to wake up now or bedtime is at risk.*

- Clear signal: wake her up
- Tone: direct but calm

### 7. Awake — Nap Window Closed
*No more naps today. Bridge to bedtime.*

- Sleep action disappears or is unavailable
- Focus shifts to bedtime countdown and feed status
- App may signal "bedtime routine starts in X minutes"
- If the day has been rough, the app can suggest an earlier bedtime: "6:40 would be fine today"
- Tone: supportive, finish-line energy

### 8. Bedtime Window
*Almost there.*

- Bedtime countdown prominent
- Feed status shows whether a final feed has happened
- Tone: winding down

## State Transitions

States change based on logged events and elapsed time. The app never asks the parent to declare intent — it infers state from what's been logged.

| Trigger | Transition |
|---|---|
| First feed logged | Day begins → State 1 |
| Wake window enters age range | State 1 → State 2 |
| Wake window exceeds age range | State 2 → State 3 |
| Sleep started (logged) | Any awake state → State 4 or 5 |
| Nap approaches cutoff | State 4 → State 5 |
| Nap reaches cutoff | State 5 → State 6 |
| Sleep ended (logged) after cutoff | → State 7 |
| Sleep ended (logged) before cutoff | → State 1, 2, or 3 (based on new wake window) |
| Bedtime minus routine buffer reached | → State 8 |

## Feed Logic (Runs Parallel)

Feed state is independent of sleep state. It runs as a parallel track:

- **Time since last feed** is always visible
- When the interval approaches the age-appropriate range, feed action becomes more prominent
- After a feed is logged, the timer resets
- The app never tells a parent to feed — it shows how long it's been and lets context do the work

## Bedtime Flex

Bedtime is a fixed anchor, but the app allows grace. If the baby's last nap ended unusually early or the day has been difficult (e.g., short naps, long wake windows), the app can signal that an earlier bedtime is reasonable.

This is not a recommendation. It's a fact: "Last nap ended at 2:30. Normal bedtime is 7:00. Putting down at 6:30–6:45 would keep the last wake window in range."

## Dream Feed

If enabled, the dream feed appears as a reminder after the baby is down for the night. It's a simple prompt at the configured time — "Dream feed at 10:30 PM" — and disappears once logged or dismissed. It does not affect the day model or any other calculations.

## Edge Cases

**No naps logged yet and wake window is long.**
The app doesn't assume the baby should have napped. It reports the facts: "Awake for 3h 15m." The wake window signal does the work.

**Very short nap.**
The wake window resets but will re-enter the approaching range quickly. The app handles this naturally.

**Missed/late logging.**
All events can be logged retroactively with adjusted times. The model recalculates from the corrected data.

**Nap transition days (e.g., 3 naps → 2).**
The app determines which wake window applies based on how many naps have been logged today. If only one nap has happened but it's past the cutoff for a second, the model adjusts. This handles transition periods where the number of naps varies day to day.

## What This Document Does Not Cover

- Visual design of home screen states (separate brief)
- Multi-caregiver logic
- Notification strategy
- Onboarding flow
- Data model / persistence
