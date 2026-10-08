-- Gradus — core schema (fase 0): profili, collegamenti coach-atleta, libreria esercizi,
-- programmazione (mesocycles → sessions → slot_groups → slots → set_blocks → block_weeks)
-- ed esecuzione (workouts → set_logs → set_segments).
--
-- Ogni tabella figlia della programmazione porta mesocycle_id, ogni tabella di esecuzione porta
-- athlete_id: le FK composite garantiscono che restino coerenti con il genitore, RLS e pull
-- incrementale filtrano su una colonna sola.

-- ---------------------------------------------------------------------------
-- Tipi
-- ---------------------------------------------------------------------------

create type public.link_status as enum ('pending', 'active', 'ended');
create type public.mesocycle_status as enum ('draft', 'active', 'completed');
create type public.group_kind as enum ('single', 'superset', 'giant', 'circuit', 'jumpset');
create type public.block_role as enum ('warmup', 'top', 'backoff', 'working');
create type public.technique as enum ('none', 'drop', 'rest_pause', 'myo', 'cluster');
create type public.intensity_method as enum ('BUF', 'RPE', 'RM', 'PCT_1RM', 'LOAD');
create type public.effort_scale as enum ('BUF', 'RPE');
create type public.muscle as enum (
  'chest', 'lats', 'upper_back', 'traps', 'front_delts', 'side_delts', 'rear_delts',
  'biceps', 'triceps', 'forearms', 'abs', 'lower_back', 'glutes', 'quads', 'hamstrings',
  'adductors', 'calves'
);

-- ---------------------------------------------------------------------------
-- Funzioni di servizio (schema private, non esposto da PostgREST)
-- ---------------------------------------------------------------------------

create schema private;
grant usage on schema private to authenticated;

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Profili e collegamenti
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  full_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data ->> 'full_name');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- Un coach può essere atleta di sé stesso: riga con coach_id = athlete_id.
create table public.coach_athletes (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.profiles (id) on delete cascade,
  athlete_id uuid not null references public.profiles (id) on delete cascade,
  status public.link_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (coach_id, athlete_id)
);
create index coach_athletes_athlete_id_idx on public.coach_athletes (athlete_id);

-- Transizioni ammesse dai client (le Edge Functions con service_role non hanno auth.uid()):
-- pending → active solo dall'atleta; qualunque → ended da entrambi; ended → pending dal coach.
create function private.check_link_change()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if new.coach_id <> old.coach_id or new.athlete_id <> old.athlete_id then
    raise exception 'coach_id and athlete_id are immutable' using errcode = '42501';
  end if;
  if uid is null or new.status = old.status or new.coach_id = new.athlete_id then
    return new;
  end if;
  if (old.status = 'pending' and new.status = 'active' and uid = new.athlete_id)
    or new.status = 'ended'
    or (old.status = 'ended' and new.status = 'pending' and uid = new.coach_id) then
    return new;
  end if;
  raise exception 'link transition % -> % not allowed', old.status, new.status
    using errcode = '42501';
end;
$$;

create trigger check_link_change
  before update on public.coach_athletes
  for each row execute function private.check_link_change();

-- Helper RLS: security definer per leggere coach_athletes/mesocycles senza ricorsione di policy.
create function private.is_coach_of(p_athlete_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.coach_athletes
    where coach_id = (select auth.uid()) and athlete_id = p_athlete_id and status = 'active'
  );
$$;

-- Qualunque collegamento, in entrambe le direzioni: serve a vedere nome ed email dell'altro.
create function private.is_linked_with(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.coach_athletes
    where (coach_id = (select auth.uid()) and athlete_id = p_user_id)
       or (athlete_id = (select auth.uid()) and coach_id = p_user_id)
  );
$$;

-- L'atleta vede gli esercizi dei coach con cui ha (o ha avuto) un collegamento accettato.
create function private.is_coached_by(p_coach_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.coach_athletes
    where coach_id = p_coach_id and athlete_id = (select auth.uid()) and status <> 'pending'
  );
$$;

-- ---------------------------------------------------------------------------
-- Libreria esercizi
-- ---------------------------------------------------------------------------

-- owner_id null = catalogo globale, scritto solo da seed / service_role.
create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.profiles (id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  video_url text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index exercises_owner_id_idx on public.exercises (owner_id);

create table public.exercise_muscles (
  id uuid primary key default gen_random_uuid(),
  exercise_id uuid not null references public.exercises (id) on delete cascade,
  muscle public.muscle not null,
  weight numeric(3, 2) not null check (weight > 0 and weight <= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (exercise_id, muscle)
);

-- ---------------------------------------------------------------------------
-- Programmazione (scrive il coach)
-- ---------------------------------------------------------------------------

create table public.mesocycles (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (btrim(name) <> ''),
  start_date date not null,
  weeks smallint not null check (weeks between 1 and 52),
  deload_weeks smallint[] not null default '{}',
  status public.mesocycle_status not null default 'draft',
  coach_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, athlete_id)
);
create index mesocycles_athlete_id_idx on public.mesocycles (athlete_id);
create unique index mesocycles_one_active_per_athlete
  on public.mesocycles (athlete_id) where status = 'active';

create function private.can_read_mesocycle(p_mesocycle_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.mesocycles m
    where m.id = p_mesocycle_id
      and ((m.athlete_id = (select auth.uid()) and m.status <> 'draft')
           or private.is_coach_of(m.athlete_id))
  );
$$;

create function private.can_write_mesocycle(p_mesocycle_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.mesocycles m
    where m.id = p_mesocycle_id and private.is_coach_of(m.athlete_id)
  );
$$;

-- Cancellazione fisica solo nelle bozze: il telefono non vede mai i draft, quindi non serve
-- propagare la cancellazione. Altrove si usa deleted_at.
create function private.can_hard_delete_in(p_mesocycle_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.mesocycles m
    where m.id = p_mesocycle_id and m.status = 'draft' and private.is_coach_of(m.athlete_id)
  );
$$;

-- L'atleta registra solo su mesocicli che vede (active o completed).
create function private.can_log_in(p_mesocycle_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.mesocycles m
    where m.id = p_mesocycle_id and m.athlete_id = (select auth.uid()) and m.status <> 'draft'
  );
$$;

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  mesocycle_id uuid not null references public.mesocycles (id) on delete cascade,
  position smallint not null check (position >= 0),
  name text not null check (btrim(name) <> ''),
  coach_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, mesocycle_id)
);
create index sessions_mesocycle_id_idx on public.sessions (mesocycle_id);

create table public.slot_groups (
  id uuid primary key default gen_random_uuid(),
  mesocycle_id uuid not null,
  session_id uuid not null,
  position smallint not null check (position >= 0),
  kind public.group_kind not null default 'single',
  rest_between_s smallint not null default 0 check (rest_between_s >= 0),
  rest_after_round_s smallint not null default 0 check (rest_after_round_s >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, mesocycle_id),
  foreign key (session_id, mesocycle_id)
    references public.sessions (id, mesocycle_id) on delete cascade
);
create index slot_groups_mesocycle_id_idx on public.slot_groups (mesocycle_id);
create index slot_groups_session_id_idx on public.slot_groups (session_id);

create table public.slots (
  id uuid primary key default gen_random_uuid(),
  mesocycle_id uuid not null,
  group_id uuid not null,
  position smallint not null check (position >= 0),
  exercise_id uuid not null references public.exercises (id),
  coach_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, mesocycle_id),
  foreign key (group_id, mesocycle_id)
    references public.slot_groups (id, mesocycle_id) on delete cascade
);
create index slots_mesocycle_id_idx on public.slots (mesocycle_id);
create index slots_group_id_idx on public.slots (group_id);
create index slots_exercise_id_idx on public.slots (exercise_id);

-- TUT: le quattro fasi hanno un nome, l'ordine in cui mostrarle è una scelta dell'interfaccia.
create table public.set_blocks (
  id uuid primary key default gen_random_uuid(),
  mesocycle_id uuid not null,
  slot_id uuid not null,
  position smallint not null check (position >= 0),
  role public.block_role not null default 'working',
  technique public.technique not null default 'none',
  technique_params jsonb not null default '{}' check (jsonb_typeof(technique_params) = 'object'),
  tut_eccentric_s smallint check (tut_eccentric_s >= 0),
  tut_bottom_pause_s smallint check (tut_bottom_pause_s >= 0),
  tut_concentric_s smallint check (tut_concentric_s >= 0),
  tut_top_pause_s smallint check (tut_top_pause_s >= 0),
  rest_s smallint check (rest_s >= 0),
  prep_s smallint check (prep_s >= 0),
  ref_block_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id, mesocycle_id),
  check (ref_block_id <> id),
  foreign key (slot_id, mesocycle_id)
    references public.slots (id, mesocycle_id) on delete cascade,
  foreign key (ref_block_id, mesocycle_id)
    references public.set_blocks (id, mesocycle_id) on delete set null (ref_block_id)
);
create index set_blocks_mesocycle_id_idx on public.set_blocks (mesocycle_id);
create index set_blocks_slot_id_idx on public.set_blocks (slot_id);
create index set_blocks_ref_block_id_idx on public.set_blocks (ref_block_id);

create table public.block_weeks (
  id uuid primary key default gen_random_uuid(),
  mesocycle_id uuid not null,
  block_id uuid not null,
  week smallint not null check (week >= 1),
  sets smallint not null check (sets >= 0),
  reps_min smallint check (reps_min >= 0),
  reps_max smallint check (reps_max >= 0),
  method public.intensity_method,
  intensity_value numeric(6, 2),
  ref_pct numeric(5, 2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (block_id, week),
  check (reps_min <= reps_max),
  check ((method is null) = (intensity_value is null)),
  foreign key (block_id, mesocycle_id)
    references public.set_blocks (id, mesocycle_id) on delete cascade
);
create index block_weeks_mesocycle_id_idx on public.block_weeks (mesocycle_id);

-- ---------------------------------------------------------------------------
-- Esecuzione (scrive l'atleta)
-- ---------------------------------------------------------------------------
-- FK verso la programmazione senza cascade: una riga programmata con dati registrati non si
-- cancella fisicamente.

create table public.workouts (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null,
  mesocycle_id uuid not null,
  session_id uuid not null,
  week smallint not null check (week >= 1),
  athlete_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (session_id, week),
  unique (id, athlete_id, mesocycle_id),
  foreign key (mesocycle_id, athlete_id) references public.mesocycles (id, athlete_id),
  foreign key (session_id, mesocycle_id) references public.sessions (id, mesocycle_id)
);
create index workouts_athlete_id_idx on public.workouts (athlete_id);
create index workouts_mesocycle_id_idx on public.workouts (mesocycle_id);

create table public.set_logs (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null,
  mesocycle_id uuid not null,
  workout_id uuid not null,
  block_id uuid not null,
  set_idx smallint not null check (set_idx >= 0),
  effort_value numeric(3, 1),
  effort_scale public.effort_scale,
  done_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (workout_id, block_id, set_idx),
  unique (id, athlete_id),
  check ((effort_value is null) = (effort_scale is null)),
  check (effort_value * 2 = trunc(effort_value * 2)),
  check (effort_scale <> 'BUF' or effort_value between 0 and 5),
  check (effort_scale <> 'RPE' or effort_value between 6 and 10),
  foreign key (workout_id, athlete_id, mesocycle_id)
    references public.workouts (id, athlete_id, mesocycle_id) on delete cascade,
  foreign key (block_id, mesocycle_id) references public.set_blocks (id, mesocycle_id)
);
create index set_logs_athlete_id_idx on public.set_logs (athlete_id);
create index set_logs_block_id_idx on public.set_logs (block_id);

create table public.set_segments (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null,
  set_log_id uuid not null,
  seg_idx smallint not null check (seg_idx >= 0),
  load_kg numeric(6, 2) check (load_kg >= 0),
  reps smallint check (reps >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (set_log_id, seg_idx),
  check (load_kg is not null or reps is not null),
  foreign key (set_log_id, athlete_id)
    references public.set_logs (id, athlete_id) on delete cascade
);
create index set_segments_athlete_id_idx on public.set_segments (athlete_id);

-- ---------------------------------------------------------------------------
-- updated_at automatico (cursore del pull incrementale)
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'coach_athletes', 'exercises', 'exercise_muscles', 'mesocycles', 'sessions',
    'slot_groups', 'slots', 'set_blocks', 'block_weeks', 'workouts', 'set_logs', 'set_segments'
  ] loop
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function private.set_updated_at()', t);
    execute format('alter table public.%I enable row level security', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

-- profiles
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.is_linked_with(id));
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- coach_athletes (gli inviti via email passano dalla Edge Function)
create policy coach_athletes_select on public.coach_athletes for select to authenticated
  using ((select auth.uid()) in (coach_id, athlete_id));
create policy coach_athletes_insert on public.coach_athletes for insert to authenticated
  with check (coach_id = (select auth.uid()) and (status = 'pending' or athlete_id = coach_id));
create policy coach_athletes_update on public.coach_athletes for update to authenticated
  using ((select auth.uid()) in (coach_id, athlete_id))
  with check ((select auth.uid()) in (coach_id, athlete_id));

-- exercises
create policy exercises_select on public.exercises for select to authenticated
  using (owner_id is null or owner_id = (select auth.uid()) or private.is_coached_by(owner_id));
create policy exercises_insert on public.exercises for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy exercises_update on public.exercises for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy exercises_delete on public.exercises for delete to authenticated
  using (owner_id = (select auth.uid()));

-- exercise_muscles: segue la visibilità e la proprietà dell'esercizio
create policy exercise_muscles_select on public.exercise_muscles for select to authenticated
  using (exists (select 1 from public.exercises e where e.id = exercise_id));
create policy exercise_muscles_insert on public.exercise_muscles for insert to authenticated
  with check (exists (
    select 1 from public.exercises e where e.id = exercise_id and e.owner_id = (select auth.uid())));
create policy exercise_muscles_update on public.exercise_muscles for update to authenticated
  using (exists (
    select 1 from public.exercises e where e.id = exercise_id and e.owner_id = (select auth.uid())))
  with check (exists (
    select 1 from public.exercises e where e.id = exercise_id and e.owner_id = (select auth.uid())));
create policy exercise_muscles_delete on public.exercise_muscles for delete to authenticated
  using (exists (
    select 1 from public.exercises e where e.id = exercise_id and e.owner_id = (select auth.uid())));

-- mesocycles
create policy mesocycles_select on public.mesocycles for select to authenticated
  using ((athlete_id = (select auth.uid()) and status <> 'draft') or private.is_coach_of(athlete_id));
create policy mesocycles_insert on public.mesocycles for insert to authenticated
  with check (private.is_coach_of(athlete_id));
create policy mesocycles_update on public.mesocycles for update to authenticated
  using (private.is_coach_of(athlete_id)) with check (private.is_coach_of(athlete_id));
create policy mesocycles_delete on public.mesocycles for delete to authenticated
  using (status = 'draft' and private.is_coach_of(athlete_id));

-- figli della programmazione: stesse quattro policy su mesocycle_id
do $$
declare
  t text;
begin
  foreach t in array array['sessions', 'slot_groups', 'slots', 'set_blocks', 'block_weeks'] loop
    execute format(
      'create policy %1$s_select on public.%1$I for select to authenticated
         using (private.can_read_mesocycle(mesocycle_id))', t);
    execute format(
      'create policy %1$s_insert on public.%1$I for insert to authenticated
         with check (private.can_write_mesocycle(mesocycle_id))', t);
    execute format(
      'create policy %1$s_update on public.%1$I for update to authenticated
         using (private.can_write_mesocycle(mesocycle_id))
         with check (private.can_write_mesocycle(mesocycle_id))', t);
    execute format(
      'create policy %1$s_delete on public.%1$I for delete to authenticated
         using (private.can_hard_delete_in(mesocycle_id))', t);
  end loop;
end;
$$;

-- la FK non guarda RLS: lo slot può usare solo esercizi che il coach vede
create policy slots_exercise_visible_insert on public.slots as restrictive for insert to authenticated
  with check (exists (select 1 from public.exercises e where e.id = exercise_id));
create policy slots_exercise_visible_update on public.slots as restrictive for update to authenticated
  with check (exists (select 1 from public.exercises e where e.id = exercise_id));

-- esecuzione: l'atleta scrive le proprie righe (niente delete fisico: deleted_at), il coach
-- collegato legge
create policy workouts_select on public.workouts for select to authenticated
  using (athlete_id = (select auth.uid()) or private.is_coach_of(athlete_id));
create policy workouts_insert on public.workouts for insert to authenticated
  with check (athlete_id = (select auth.uid()) and private.can_log_in(mesocycle_id));
create policy workouts_update on public.workouts for update to authenticated
  using (athlete_id = (select auth.uid()))
  with check (athlete_id = (select auth.uid()) and private.can_log_in(mesocycle_id));

create policy set_logs_select on public.set_logs for select to authenticated
  using (athlete_id = (select auth.uid()) or private.is_coach_of(athlete_id));
create policy set_logs_insert on public.set_logs for insert to authenticated
  with check (athlete_id = (select auth.uid()));
create policy set_logs_update on public.set_logs for update to authenticated
  using (athlete_id = (select auth.uid())) with check (athlete_id = (select auth.uid()));

create policy set_segments_select on public.set_segments for select to authenticated
  using (athlete_id = (select auth.uid()) or private.is_coach_of(athlete_id));
create policy set_segments_insert on public.set_segments for insert to authenticated
  with check (athlete_id = (select auth.uid()));
create policy set_segments_update on public.set_segments for update to authenticated
  using (athlete_id = (select auth.uid())) with check (athlete_id = (select auth.uid()));

-- Gli helper si chiamano solo dalle policy.
revoke execute on all functions in schema private from public, anon;
grant execute on all functions in schema private to authenticated;
