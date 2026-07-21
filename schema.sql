-- Run this in Supabase: Dashboard → SQL Editor → New query → paste → Run
create table if not exists progress (
  player_name text not null,
  team_code text not null,
  bingo jsonb default '[]'::jsonb,
  styrke jsonb default '[]'::jsonb,
  updated_at timestamptz default now(),
  primary key (player_name, team_code)
);

alter table progress enable row level security;

-- Data is non-sensitive (just workout check-ins), so anon can read/write all.
-- The team_code acts as a lightweight shared "password" per team.
drop policy if exists "anon all" on progress;
create policy "anon all" on progress
  for all to anon using (true) with check (true);

-- Auto-update updated_at on every change
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_progress_updated on progress;
create trigger trg_progress_updated
  before update on progress
  for each row execute function set_updated_at();
