# Implementation Plan: Coach-generated training plans

## Phases (ordered)

### Phase 1: Appwrite backend setup
- [ ] Create `plans` collection (8 attributes per design.md)
- [ ] Create `items` collection (9 attributes per design.md)
- [ ] Set permissions: read/create/update/delete = any
- [ ] Deploy Appwrite Function `translate` (OpenAI proxy)
- [ ] Add function endpoint URL to config.js
- **Validate**: `appwrite databases list-collections` shows both new collections; curl function endpoint returns translation

### Phase 2: Seed & migrate
- [ ] Write migration script: seed current BINGO as `plan_sommar2026` in `plans` collection
- [ ] Seed all 36 current BINGO items into `items` library
- [ ] Migrate Elias's progress: create `elias_gbk_plan_sommar2026` from `elias_gbk` data
- [ ] Verify Elias's 11 completed cells carry over
- **Validate**: query `plans` collection returns 1 doc; query `items` returns 36 docs; query `progress` for new ID returns Elias's data

### Phase 3: admin.html — plan builder
- [ ] Scaffold admin.html with shared auth (password from config.js)
- [ ] Plan list view: fetch published + draft plans, cards with name/dates/status
- [ ] Plan creation flow:
  - Step 1: name (sv) + dates
  - Step 2: build grid — 36 slots, browse library sidebar, create new item modal
  - Step 3: item editor — sv text, type selector (text/reps/timer), target input, LLM translate button → en field (editable), hint fields
  - Step 4: review all 36 items → publish
- [ ] Duplicate plan: load existing plan items as starting point
- [ ] Edit plan: dates only (items locked after publish)
- [ ] Delete plan (with confirm)
- **Validate**: create a test plan with mix of text/reps/timer items; verify it appears in `plans` collection; verify items saved to `items` library

### Phase 4: index.html — player app refactor
- [ ] Fetch active plans on login (team_code + date range + status=published)
- [ ] Board list view (when 2+ plans): cards with name, progress %, date range
- [ ] Single board view (when 1 plan): render directly
- [ ] Fallback to hardcoded BINGO when 0 plans
- [ ] Per-plan progress: doc ID `${playerName}_${teamCode}_${planId}`
- [ ] Unified cell rendering:
  - text: tap to toggle (current)
  - reps: counter modal (+1/-1/mark done)
  - timer: timer modal (start/pause/reset/mark done)
- [ ] Remove styrke guided program (STYRKE array, styrke modal, all related code)
- [ ] Plan update notification: compare localStorage `last_plan_update` with plan `updated_at`; show banner if newer
- **Validate**: login as test player, see board list or single board, complete cells of each type, verify progress syncs to Appwrite with correct doc ID

### Phase 5: coach.html — per-plan progress
- [ ] Add plan selector dropdown (fetch plans for team)
- [ ] Load progress docs filtered by selected plan ID
- [ ] Mini-grid: 36 cells, inline dates, clickable notes (existing behavior, now works per-plan)
- [ ] "Manage plans" button → admin.html
- [ ] Handle old progress docs (no plan ID) gracefully — show under "Legacy" plan option
- **Validate**: select seeded plan, see Elias's 11 completed cells; select new test plan, see test player's progress

### Phase 6: Polish & deploy
- [ ] Update sw.js (cache admin.html, bump version)
- [ ] Update manifest.json if needed
- [ ] i18n strings for all new UI (admin.html, board list, cell modals, notifications)
- [ ] Desktop layout for admin.html
- [ ] Test full flow: coach creates plan → player sees it → completes cells → coach views progress
- [ ] Clean up test data
- **Validate**: end-to-end test on mobile + desktop

## Validation commands
```bash
# Collections exist
appwrite databases list-collections --database-id "6a5fc1470035f5150049"

# Plans seeded
curl "https://fra.cloud.appwrite.io/v1/databases/6a5fc1470035f5150049/collections/plans/documents" -H "X-Appwrite-Project: 6a5fbff9003d75f889af"

# Translation function works
curl -X POST "<function-endpoint>" -H "Content-Type: application/json" -d '{"text":"Hoppa 100 hopprep","target_lang":"en"}'

# Deploy
gh run list --workflow=deploy.yml --limit 1
```

## Risky files / rollback points
- `index.html` — major refactor (cell rendering, plan fetching, styrke removal). Rollback: git revert to pre-refactor commit, hardcoded BINGO still works.
- `coach.html` — per-plan progress changes. Rollback: git revert, old progress docs still exist.
- Appwrite collections — new collections can be deleted safely. Old `progress` docs untouched.
- Migration script — creates new docs, doesn't modify/delete old ones. Safe.

## Follow-up checks before task.py start
- [ ] PRD convergence pass complete
- [ ] design.md reviewed
- [ ] implement.md reviewed
- [ ] User approves proceeding to implementation
