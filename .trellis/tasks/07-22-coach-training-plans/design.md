# Design: Coach-generated training plans

## Architecture

### New files
- `admin.html` — plan builder UI (list/create/edit/duplicate/delete plans, item library, LLM translation)
- Appwrite Function `translate` — server-side LLM translation proxy (keeps OpenAI key server-side)

### Modified files
- `index.html` — fetch active plans, board list view, unified cell rendering (text/reps/timer), remove styrke guided program, per-plan progress sync
- `coach.html` — per-plan progress view, plan selector, "Manage plans" button → admin.html
- `config.js` — add Appwrite Function endpoint URL
- `sw.js` — cache admin.html, bump version

### New Appwrite collections

#### `plans` collection
| Attribute | Type | Size | Required | Notes |
|-----------|------|------|----------|-------|
| `name` | string | 100 | yes | Plan name (sv) |
| `name_en` | string | 100 | no | Plan name (en, auto-translated) |
| `team_code` | string | 50 | yes | e.g. "GBK" |
| `items` | string | 20000 | yes | JSON array of 36 items |
| `start_date` | string | 20 | yes | YYYY-MM-DD |
| `end_date` | string | 20 | yes | YYYY-MM-DD |
| `status` | string | 20 | yes | "draft" or "published" |
| `created_at` | datetime | - | no | |
| `updated_at` | datetime | - | no | |

Item JSON format (each of 36):
```json
{
  "sv": "Hoppa 2×100 hopprep",
  "en": "Jump 2×100 jump rope",
  "type": "text|reps|timer",
  "target": 100,        // for reps: count; for timer: seconds
  "sets": 2,            // optional, for timer
  "hint_sv": "",        // optional
  "hint_en": "",        // optional
  "library_id": "xxx"   // optional, links to items collection
}
```

#### `items` collection (library)
| Attribute | Type | Size | Required | Notes |
|-----------|------|------|----------|-------|
| `sv` | string | 200 | yes | Swedish text |
| `en` | string | 200 | yes | English text |
| `type` | string | 20 | yes | "text|reps|timer" |
| `default_target` | integer | - | no | suggested target |
| `default_sets` | integer | - | no | suggested sets |
| `hint_sv` | string | 300 | no | |
| `hint_en` | string | 300 | no | |
| `created_at` | datetime | - | no | |
| `usage_count` | integer | - | no | incremented when used in a plan |

### Progress data model (existing `progress` collection — no schema change)
Document ID format changes from `${playerName}_${teamCode}` to `${playerName}_${teamCode}_${planId}`.

Existing attributes remain:
- `player_name`, `team_code`, `bingo` (JSON array of completed cell indices), `styrke` (repurposed as `cell_data` — JSON of cell completion details for reps/timer types), `notes` (JSON of notes + dates), `updated_at`

`styrke` attribute repurposed: stores per-cell completion data for reps/timer cells:
```json
{
  "5": {"count": 15, "completed": true},
  "12": {"count": 60, "sets_done": 2, "completed": true}
}
```

### Data flow

#### Player loads app
1. Login → fetch plans where `team_code = X` AND `status = "published"` AND `start_date <= today <= end_date`
2. 0 plans → load hardcoded fallback BINGO (current behavior)
3. 1 plan → render board directly
4. 2+ plans → render board list cards; tap → render that board
5. Fetch progress doc by ID `${playerName}_${teamCode}_${planId}` (or create if missing)
6. Render cells based on item type

#### Coach creates plan (admin.html)
1. Coach logs in (shared password)
2. "New plan" → enter name (sv), dates
3. Build grid: 36 slots
   - Browse library: fetch `items` collection, search/filter, tap to add to slot
   - Create new: enter sv text, select type, set target → LLM translates to en → review → save to library + add to slot
   - Duplicate plan: load existing plan's items as starting point
4. Review all 36 items → Publish
5. Plan saved to `plans` collection with `status: "published"`

#### Coach edits plan
- Items locked after publish
- Dates editable → update `plans` doc → notify players (see below)

#### Player notification on plan edit
- Player app stores `last_plan_update` timestamp per plan in localStorage
- On load, compare with plan's `updated_at`; if newer, show banner "Plan updated by coach"
- Coach edits dates → updates `plans.updated_at` → players see banner on next load

### Translation (client-side, MyMemory API)
- Free translation API, no key needed: `https://api.mymemory.translated.net/get?q=<text>&langpair=sv|en`
- Client (admin.html) calls this when coach creates/edits an item
- Coach sees translation in an editable field before saving
- Fallback: if API fails, coach enters English manually
- Note: MyMemory has daily limits (~5000 words/day anonymous). For a small coaching app this is sufficient. Can upgrade to OpenAI later if needed.

### Cell rendering (player side)

| Type | Render | Interaction |
|------|--------|-------------|
| `text` | Cell with label text | Tap to toggle done (current behavior) |
| `reps` | Cell with label + counter "15/100" | Tap opens counter modal: +1, -1, mark done |
| `timer` | Cell with label + timer "0:60" | Tap opens timer modal: start/pause/reset, mark done |

Completed state (green) when: text=marked, reps=count>=target, timer=completed all sets.

### Migration plan
1. Create `plans` and `items` collections in Appwrite
2. Seed current hardcoded BINGO as plan `plan_sommar2026` (start=2026-06-16, end=2026-08-17, week 25-33)
3. Seed all current BINGO items into `items` library
4. Migrate Elias's progress: create new doc `elias_gbk_plan_sommar2026` with data from `elias_gbk`
5. Keep old doc `elias_gbk` for backup
6. Deploy new code
7. Player app: fetches plan, finds progress doc, renders seamlessly

### Permissions
- `plans` collection: read=any, create/update/delete=any (coach password gates UI, not DB — same pattern as current)
- `items` collection: read=any, create/update/delete=any
- `progress` collection: unchanged (read/create/update/delete=any)

## Trade-offs

- **Per-plan progress via doc ID encoding**: avoids schema change on at-limit `progress` collection. Trade-off: doc ID length grows, querying progress by plan requires client-side filtering (fetch all progress docs for team, filter by plan ID in ID string).
- **LLM translation server-side**: adds latency (~1-2s per item) and dependency on OpenAI. Trade-off: high quality, handles context. Fallback: if LLM fails, coach can enter English manually.
- **Immutable items after publish**: protects progress integrity. Trade-off: coach must duplicate to change items. Dates remain editable for flexibility.
- **styrke attribute repurposed**: avoids new attribute on at-limit collection. Trade-off: semantic mismatch (attribute named styrke stores cell data). Acceptable since it's internal.

## Rollback
- New collections (`plans`, `items`) can be deleted without affecting existing `progress`
- Player app falls back to hardcoded BINGO if `plans` collection is empty/unreachable
- Old progress docs (`elias_gbk`) remain as backup
- Revert index.html/coach.html to previous version to restore old behavior
