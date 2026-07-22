# Coach-generated training plans

## Goal

Allow coaches to create custom bingo boards (training plans, homework, any topic) with configurable items, a reusable item library, and date ranges. Players see active boards for their team. Multiple boards can be active simultaneously.

## Background

Currently BINGO (6×6 grid) and STYRKE (19-step guided program) are hardcoded in index.html and coach.html. All players see the same board. The `progress` Appwrite collection is at attribute limit (6 attributes).

## Confirmed Facts

- BINGO: 6×6=36 cells, each is `{sv,en}` text or `"STYRKE"` marker
- STYRKE: 19-step guided exercise program with timers/rep counters — **will be removed**
- Appwrite `progress` collection at attribute limit — cannot add columns
- Document ID format: `${playerName}_${teamCode}` (lowercased)
- Single team code "GBK" currently
- Coach page password-protected (localStorage auth)
- Appwrite database has room for new collections

## Requirements

### Data Model
- **Unified item type**: every cell is one of: `text` (tap to mark done), `reps` (counter with target), `timer` (countdown with target seconds + optional sets). No special styrke handling.
- **Plans collection** (`plans`): stores board definition (36 items, name, dates, team_code). Immutable items after publish; dates editable.
- **Items library collection** (`items`): persistent library of all items ever created. Coach can browse/search when building a plan. New items auto-saved to library.
- **Per-plan progress**: document ID format becomes `${playerName}_${teamCode}_${planId}`. Each plan has its own progress documents. Old progress preserved and viewable by coach.
- **Multiple active boards**: multiple plans can have overlapping date ranges. Player sees a list of active boards, taps one to open.

### Plan Builder (admin.html)
- New page for plan management: list, create, edit (dates only after publish), duplicate, delete.
- Shared password auth with coach.html.
- Plan creation flow: name → date range → build grid (browse library + create new items) → review → publish.
- Item creation: coach enters Swedish text, selects type (text/reps/timer), sets target if applicable. LLM auto-translates to English. Coach can review/edit translation before saving.
- Library reuse: persistent library + reuse from plan history + duplicate whole plan.
- coach.html gets "Manage plans" button linking to admin.html.

### Player App (index.html)
- On login, fetch active plans for team (plans where today is within date range).
- If 0 active plans: show hardcoded fallback board (current behavior).
- If 1 active plan: show it directly (current UX).
- If 2+ active plans: show board list (cards with name, progress %, date range), tap to open.
- Each board opened independently with its own progress.
- Cells render based on type: text = tap to mark, reps = counter, timer = countdown.
- Remove styrke guided program entirely.
- Notify players when a plan they're working on is edited (toast/banner: "Plan updated by coach").

### Coach View (coach.html)
- Show per-plan progress: coach selects a plan, sees player list with that plan's progress.
- Mini-grid shows all 36 cells with inline dates + clickable notes (existing behavior).
- "Manage plans" button → admin.html.

### Migration
- Seed current hardcoded BINGO as first plan in Appwrite (date range covering current period).
- Elias's existing progress linked to this plan via new document ID format.
- Hardcoded board becomes fallback when no plan exists in Appwrite.

### Translation
- Coach enters Swedish. LLM (OpenAI API via Appwrite Function or client-side) translates to English.
- Coach reviews/edits translation before saving.
- API key kept server-side (Appwrite Function) — never in client config.

## Acceptance Criteria

- [ ] Coach can create a new plan with 36 items (mix of text/reps/timer types)
- [ ] Coach can browse the item library and add existing items to a plan
- [ ] Coach can create new items; they auto-save to the library
- [ ] Coach can duplicate an entire existing plan as a starting point
- [ ] Coach enters Swedish text; English is auto-translated via LLM and editable before save
- [ ] Coach sets start and end dates for a plan
- [ ] Multiple plans can be active simultaneously for the same team
- [ ] Player sees a list of active boards when multiple are active; taps one to open
- [ ] Player sees a single board directly when only one is active
- [ ] Player sees hardcoded fallback when no plan is active
- [ ] Each plan has independent progress (per-plan document IDs)
- [ ] Coach can edit a published plan's dates (not items); players get notified
- [ ] Coach can view per-plan progress for each player
- [ ] Existing Elias progress migrates to the seeded first plan
- [ ] Styrke guided program is removed; all cells use unified type model
- [ ] Reps cells show a counter; timer cells show a countdown

## Out of Scope

- Variable grid sizes (always 6×6=36)
- Plan templates/categories (all plans are just bingo boards)
- Player-side plan switching history
- Offline plan creation (requires network for LLM translation + Appwrite)
