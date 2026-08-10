# ToddlerLearningApp — Product Spec

**Audience:** children ages 2–5, with a parent as the paying decision-maker.
**Platform:** iOS 26.5+, SwiftUI, SwiftData.
**Architecture:** MVVM-C (Model – View – ViewModel – Coordinator).

---

## 1. Market basis

Ten apps define this category. What the leaders share is more instructive than what makes each unique.

| App | Model | Signature strength |
|---|---|---|
| Khan Academy Kids | Free, ad-free | Adaptive path; reroutes to foundations on struggle |
| ABCmouse | Subscription | 850+ lessons, 10 levels, strong parent dashboard |
| Lingokids | Freemium | kidSAFE certified; adapts to developmental stage |
| Duolingo (ABC) | Freemium | Streaks + daily goals — the retention benchmark |
| Sago Mini World | Subscription | Open-ended play, no fail states |
| Endless Alphabet | Paid | Best-in-class animated phonics + drag-to-spell |
| ElePant | Freemium | Broad early-learning basics |
| Fluvsies Academy | Ad-free sub | Built with child psychologists; SEL focus |
| ReadingIQ | Subscription | 7,000+ leveled books |
| PBS Kids Games | Free | Trusted IP, curriculum-aligned, no ads |

**Feature frequency across the ten:** progress tracking (10/10), parent dashboard (8/10),
adaptive difficulty (6/10), reward/streak loop (7/10), offline support (5/10),
recorded human audio (9/10), built-in time limits (2/10 — an underserved gap).

---

## 2. Scope — the six features

> **Note:** the app has grown beyond these six since this section was written — Numbers
> (Learn Numbers, Count & Find), Build the Word, Letter Tracing, and Nursery Rhymes are all
> shipped, first-class features with their own content/service/view stacks, not covered by
> F1-F6 below. This section is kept as the original rationale for the founding six; it is
> not a complete feature list.

### F1. Persistent child profile + progress tracking
**Why:** universal across competitors, and a prerequisite for F2, F4, and F5.
**Build:**
- SwiftData-backed `ChildProfile` (name, age, avatar, created date).
- Multi-child support — siblings are a documented purchase driver.
- `LetterProgress` per (child, letter): attempts, correct count, mastery level, last seen.
- `SessionRecord` per play session for time accounting.

**Acceptance:** profile and progress survive relaunch; a second child has independent progress.

### F2. Adaptive difficulty / real learning path
**Why:** the strongest differentiator among the leaders and currently absent.
**Build:** a three-stage mastery model per letter — `new → learning → mastered`.
- Promotion: 3 consecutive correct answers.
- Demotion: 2 consecutive misses drops one stage.
- Quiz selection is weighted: `new` and `learning` letters are served ~4× more often than `mastered`.
- Age gates starting set size: under 3 → 10 letters, age 3+ → all 26. (Simplified from an
  earlier four-tier design — a two-year-old faced with 26 tiles disengages, but from age 3
  on there's no pedagogical reason to hold content back.) Numbers follow the same two-tier
  shape: under 3 → 5 numbers, age 3+ → all 10.

**Acceptance:** a child who repeatedly misses "M" sees "M" more often; mastered letters recede.

### F3. Parent dashboard behind a parental gate
**Why:** the feature parents pay for, and legally load-bearing.
The FTC's amended COPPA rule took effect 22 April 2026; Apple's Kids Category requires a
gate before external links or purchases.
**Build:**
- Gate: a hold-to-continue + arithmetic challenge a preschooler cannot pass.
- Dashboard: per-child mastery grid, time played today / this week (a 7-day chart plus a
  session count — not a per-session log), settings.
- No third-party analytics SDKs. All data stays on-device.

**Acceptance:** no path from child UI to settings or external links without passing the gate.

### F4. Reward and streak loop
**Why:** the single biggest lever on D7 retention.
**Build:** stars per correct answer, trophies at mastery milestones (letters and numbers),
a collectible shelf, and a gentle daily goal (5 stars/day, shown on Home, silently reset
each day — never shown as "missed"). **Non-punitive** — no streak-loss shaming for a
3-year-old; a missed day resets quietly without a negative screen.

**Acceptance:** rewards persist per child; the collection screen reflects real progress.

### F5. Session timer with a graceful stopping point
**Why:** the top parent complaint in 2026 reviews is apps engineered to maximize screen time.
AAP guidance is ~1 hour/day for ages 2–5. Two of ten competitors address this — a real gap.
**Build:** parent-set daily limit (15/30/45/60 min or off). At expiry, finish the current
activity, then show a celebration "see you tomorrow" screen — never a hard cut mid-task.

**Acceptance:** limit persists, counts only foreground time, and ends on a positive screen.

### F6. Richer phonics + real audio
**Why:** robotic TTS is the fastest way to read as low-quality next to Endless Alphabet.
**Build:** `SpeechService` abstracts playback behind one protocol so recorded audio can
replace synthesis without touching call sites. Teach letter **sounds**, not just names.
Ships with `AVSpeechSynthesizer`; recorded audio drops in later as a bundle of 26 clips.

**Acceptance:** every spoken line routes through `SpeechService`; no view calls AVFoundation.

---

## 3. Architecture — MVVM-C

```
Model        SwiftData @Model types + value-type content. No UI, no navigation.
View         SwiftUI. Dumb. Renders VM state, forwards intent. No business logic.
ViewModel    @Observable @MainActor. Owns state + services. No SwiftUI view types.
Coordinator  Owns navigation. Views never construct destination views directly.
Service      Stateless-ish capability (speech, progress, rewards, timer). Injected.
```

**Navigation rule:** a view calls `coordinator.push(.quiz)`, never `NavigationLink { QuizView() }`.
This keeps deep-linking and the parent gate enforceable in one place.

### Folder layout

```
ToddlerLearningApp/
├── App/            entry point, RootView, dependency container
├── Coordinators/   Coordinator protocol, Route, AppCoordinator
├── Models/         SwiftData @Model types + MasteryLevel
├── Content/        AlphabetContent, NumberContent, WordBuildContent,
│                   LetterTracePathContent, RhymeContent
├── Services/       Speech, Progress, Reward, SessionTimer, Haptics, RhymeAudio
├── ViewModels/     one per screen
├── Views/          one folder per feature
├── Components/     reusable UI atoms
└── Theme/          colors, fonts, spacing, shadows
```

---

## 4. Data model

```swift
ChildProfile   id, name, age, avatarEmoji, createdAt, dailyLimitMinutes,
               starCount, currentStreak, lastPlayedDate,
               progress: [LetterProgress], sessions: [SessionRecord]

LetterProgress id, letterID, attempts, correctCount, consecutiveCorrect,
               consecutiveMisses, masteryRaw, lastSeenAt

SessionRecord  id, startedAt, endedAt, secondsPlayed
```

`Letter` (content) stays a plain `struct` — it is static, not user data.

---

## 5. Monetization

Two audiences with different goals: the child uses it, the parent buys it.

- **Free tier:** letters A–J, unlimited practice, full parent dashboard.
- **Premium:** full alphabet, numbers, shapes, colors; reward collection; multi-child.
- **Pricing:** monthly with a 7-day trial, plus a discounted annual. Annual is the target.
- **Rules:** no ads, ever. No third-party ad SDKs — post-April-2026 COPPA makes ad
  monetization of under-13 data a liability. Purchase flows sit behind the F3 gate.

---

## 6. Compliance checklist

- [ ] Apple Kids Category: parental gate before external links, purchases, and settings
- [ ] No third-party analytics or ad SDKs
- [ ] No personal data collection beyond an on-device first name (never transmitted)
- [ ] No account creation for the child
- [ ] Privacy policy + accurate App Store privacy nutrition label
- [ ] Data stays on-device; no network calls in v1
- [ ] Biometric identifiers are now personal information under amended COPPA — collect none

Collecting only a local first name and no network transmission keeps v1 outside
verifiable-parental-consent territory. Any future sync feature changes that and needs review.

---

## 7. Build order

| Milestone | Contents |
|---|---|
| **M1** | Theme, content, components, MVVM-C skeleton, coordinators |
| **M2** | F1 persistence + F6 speech service |
| **M3** | F2 adaptive quiz + F4 rewards |
| **M4** | F3 parent gate & dashboard + F5 session timer |
| **M4.5** *(shipped, unplanned)* | Numbers, Word Build, Letter Tracing, Nursery Rhymes |
| **M5** | Recorded audio for Rhymes, premium content, paywall |

v1 ships M1–M4. Letter Tracing shipped ahead of schedule as part of M4.5 rather than
waiting for M5 as originally planned. M5 (recorded audio, monetization) remains the
follow-on release.
