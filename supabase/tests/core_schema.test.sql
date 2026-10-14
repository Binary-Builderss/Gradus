-- RLS e vincoli dello schema core.
-- Utenti: c = coach collegato ad a (active), x = coach di b (non collegato ad a),
-- p = coach con invito pending verso a, a = atleta proprietario, b = altro atleta.
-- Mesocicli: 01 = a active, 02 = a draft, 03 = b active. Ogni mesociclo ha un'intera catena
-- sessione → gruppo → slot → blocco → settimana; 01 e 03 hanno una seduta con una serie e un segmento.

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- ---------------------------------------------------------------------------
-- Dati
-- ---------------------------------------------------------------------------

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c@test.dev'),
  ('00000000-0000-0000-0000-0000000000c2', 'x@test.dev'),
  ('00000000-0000-0000-0000-0000000000c3', 'p@test.dev'),
  ('00000000-0000-0000-0000-0000000000a1', 'a@test.dev'),
  ('00000000-0000-0000-0000-0000000000b1', 'b@test.dev');

insert into public.coach_athletes (coach_id, athlete_id, status) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'active'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000b1', 'active'),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000a1', 'pending');

insert into public.exercises (id, owner_id, name) values
  ('e0000000-0000-0000-0000-000000000000', null, 'Panca piana'),
  ('e0000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c1', 'Panca di c'),
  ('e0000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000c2', 'Panca di x');
insert into public.exercise_muscles (exercise_id, muscle, weight) values
  ('e0000000-0000-0000-0000-0000000000c1', 'chest', 1);

insert into public.mesocycles (id, athlete_id, name, start_date, weeks, status, created_at, updated_at) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'A attivo', '2026-10-05', 6, 'active', '2026-01-01', '2026-01-01'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1', 'A bozza', '2026-11-16', 6, 'draft', '2026-01-01', '2026-01-01'),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000b1', 'B attivo', '2026-10-05', 6, 'active', '2026-01-01', '2026-01-01');

insert into public.sessions (id, mesocycle_id, position, name)
select ('20000000-0000-0000-0000-00000000000' || n)::uuid, ('10000000-0000-0000-0000-00000000000' || n)::uuid, 0, 'A'
from generate_series(1, 3) n;
insert into public.slot_groups (id, mesocycle_id, session_id, position)
select ('30000000-0000-0000-0000-00000000000' || n)::uuid, ('10000000-0000-0000-0000-00000000000' || n)::uuid,
       ('20000000-0000-0000-0000-00000000000' || n)::uuid, 0
from generate_series(1, 3) n;
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id)
select ('40000000-0000-0000-0000-00000000000' || n)::uuid, ('10000000-0000-0000-0000-00000000000' || n)::uuid,
       ('30000000-0000-0000-0000-00000000000' || n)::uuid, 0,
       case n when 3 then 'e0000000-0000-0000-0000-0000000000c2'::uuid
              else 'e0000000-0000-0000-0000-0000000000c1'::uuid end
from generate_series(1, 3) n;
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role)
select ('50000000-0000-0000-0000-00000000000' || n)::uuid, ('10000000-0000-0000-0000-00000000000' || n)::uuid,
       ('40000000-0000-0000-0000-00000000000' || n)::uuid, 0, 'top'
from generate_series(1, 3) n;
insert into public.block_weeks (id, mesocycle_id, block_id, week, sets, reps_min, reps_max, method, intensity_value)
select ('60000000-0000-0000-0000-00000000000' || n)::uuid, ('10000000-0000-0000-0000-00000000000' || n)::uuid,
       ('50000000-0000-0000-0000-00000000000' || n)::uuid, 1, 1, 5, 5, 'BUF', 1
from generate_series(1, 3) n;

insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values
  ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 1),
  ('70000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values
  ('80000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 0, 1, 'BUF'),
  ('80000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-000000000003', '70000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000003', 0, 8, 'RPE');
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values
  ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000001', 0, 100, 5),
  ('00000000-0000-0000-0000-0000000000b1', '80000000-0000-0000-0000-000000000003', 0, 80, 8);

-- ---------------------------------------------------------------------------
-- Helper: login come utente, conteggio delle righe visibili per tabella
-- ---------------------------------------------------------------------------

create schema tests;
grant usage on schema tests to authenticated;

create function tests.login(uid uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;

create function tests.visible() returns table (tbl text, n int) language plpgsql as $$
declare
  t text;
begin
  foreach t in array array[
    'profiles', 'coach_athletes', 'exercises', 'exercise_muscles', 'mesocycles', 'sessions',
    'slot_groups', 'slots', 'set_blocks', 'block_weeks', 'workouts', 'set_logs', 'set_segments'
  ] loop
    tbl := t;
    -- il catalogo globale reale resta fuori dai conteggi: contano solo gli esercizi di test
    execute format('select count(*)::int from public.%I where %s', t, case t
      when 'exercises' then 'id::text like ''e0000000%'''
      when 'exercise_muscles' then 'exercise_id::text like ''e0000000%'''
      else 'true' end) into n;
    return next;
  end loop;
end;
$$;
grant execute on all functions in schema tests to authenticated;

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------

select is((select count(*)::int from public.profiles), 5, 'ogni utente auth ha un profilo');
select is(
  (select count(*)::int from pg_tables where schemaname = 'public' and not rowsecurity), 0,
  'RLS attiva su ogni tabella di public');
select is(
  (select count(*)::int from pg_policies where schemaname = 'public'
     and (qual = 'true' or with_check = 'true')), 0,
  'nessuna policy using (true)');

-- ---------------------------------------------------------------------------
-- Lettura
-- ---------------------------------------------------------------------------

select tests.login('00000000-0000-0000-0000-0000000000c1');
select results_eq('select * from tests.visible()', $$ values
  ('profiles', 2), ('coach_athletes', 1), ('exercises', 2), ('exercise_muscles', 1),
  ('mesocycles', 2), ('sessions', 2), ('slot_groups', 2), ('slots', 2), ('set_blocks', 2),
  ('block_weeks', 2), ('workouts', 1), ('set_logs', 1), ('set_segments', 1) $$,
  'coach collegato: vede a, bozze comprese, e la sua esecuzione; niente di b');

select tests.login('00000000-0000-0000-0000-0000000000c2');
select results_eq('select * from tests.visible()', $$ values
  ('profiles', 2), ('coach_athletes', 1), ('exercises', 2), ('exercise_muscles', 0),
  ('mesocycles', 1), ('sessions', 1), ('slot_groups', 1), ('slots', 1), ('set_blocks', 1),
  ('block_weeks', 1), ('workouts', 1), ('set_logs', 1), ('set_segments', 1) $$,
  'coach non collegato ad a: vede solo b');
select is(
  (select count(*)::int from public.mesocycles where athlete_id = '00000000-0000-0000-0000-0000000000a1'), 0,
  'coach non collegato: nessun mesociclo di a');

select tests.login('00000000-0000-0000-0000-0000000000c3');
select results_eq('select * from tests.visible()', $$ values
  ('profiles', 2), ('coach_athletes', 1), ('exercises', 1), ('exercise_muscles', 0),
  ('mesocycles', 0), ('sessions', 0), ('slot_groups', 0), ('slots', 0), ('set_blocks', 0),
  ('block_weeks', 0), ('workouts', 0), ('set_logs', 0), ('set_segments', 0) $$,
  'coach con invito pending: vede il profilo di a, nessun dato');

select tests.login('00000000-0000-0000-0000-0000000000a1');
select results_eq('select * from tests.visible()', $$ values
  ('profiles', 3), ('coach_athletes', 2), ('exercises', 2), ('exercise_muscles', 1),
  ('mesocycles', 1), ('sessions', 1), ('slot_groups', 1), ('slots', 1), ('set_blocks', 1),
  ('block_weeks', 1), ('workouts', 1), ('set_logs', 1), ('set_segments', 1) $$,
  'atleta proprietario: il proprio mesociclo attivo, mai le bozze');

select tests.login('00000000-0000-0000-0000-0000000000b1');
select results_eq('select * from tests.visible()', $$ values
  ('profiles', 2), ('coach_athletes', 1), ('exercises', 2), ('exercise_muscles', 0),
  ('mesocycles', 1), ('sessions', 1), ('slot_groups', 1), ('slots', 1), ('set_blocks', 1),
  ('block_weeks', 1), ('workouts', 1), ('set_logs', 1), ('set_segments', 1) $$,
  'altro atleta: solo i propri dati');

-- ---------------------------------------------------------------------------
-- Scrittura: coach collegato
-- ---------------------------------------------------------------------------

select tests.login('00000000-0000-0000-0000-0000000000c1');
select lives_ok($$
  insert into public.sessions (mesocycle_id, position, name)
  values ('10000000-0000-0000-0000-000000000001', 1, 'B') $$,
  'coach collegato: aggiunge una sessione');
select results_eq($$
  with u as (update public.mesocycles set coach_notes = 'ok'
             where id = '10000000-0000-0000-0000-000000000001' returning 1)
  select count(*)::int from u $$, 'values (1)', 'coach collegato: modifica il mesociclo');
select throws_ok($$
  insert into public.mesocycles (athlete_id, name, start_date, weeks)
  values ('00000000-0000-0000-0000-0000000000b1', 'x', '2026-10-05', 4) $$,
  '42501', null, 'coach collegato: nessun mesociclo per un atleta non suo');
select results_eq($$
  with d as (delete from public.sessions where id = '20000000-0000-0000-0000-000000000001' returning 1)
  select count(*)::int from d $$, 'values (0)', 'coach: nessuna cancellazione fisica fuori dalle bozze');
select throws_ok($$
  insert into public.slots (mesocycle_id, group_id, position, exercise_id)
  values ('10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 1,
          'e0000000-0000-0000-0000-0000000000c2') $$,
  '42501', null, 'coach: nessuno slot con un esercizio che non vede');
select throws_ok($$
  insert into public.workouts (athlete_id, mesocycle_id, session_id, week)
  values ('00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001',
          '20000000-0000-0000-0000-000000000001', 2) $$,
  '42501', null, 'coach: non scrive dati di esecuzione');
select results_eq($$
  with u as (update public.set_logs set effort_value = 2 returning 1) select count(*)::int from u $$,
  'values (0)', 'coach: non modifica le serie dell''atleta');
select throws_ok($$
  insert into public.exercises (owner_id, name) values (null, 'globale') $$,
  '42501', null, 'coach: non scrive nel catalogo globale');
select throws_ok($$
  insert into public.coach_athletes (coach_id, athlete_id, status)
  values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000b1', 'active') $$,
  '42501', null, 'coach: non crea un collegamento già attivo');
select lives_ok($$
  insert into public.coach_athletes (coach_id, athlete_id, status)
  values ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c1', 'active') $$,
  'coach: si collega a sé stesso come atleta');
select results_eq($$
  with d as (delete from public.mesocycles where id = '10000000-0000-0000-0000-000000000002' returning 1)
  select count(*)::int from d $$, 'values (1)', 'coach: cancella una bozza');

-- ---------------------------------------------------------------------------
-- Scrittura: coach non collegato / pending
-- ---------------------------------------------------------------------------

select tests.login('00000000-0000-0000-0000-0000000000c2');
select results_eq($$
  with u as (update public.mesocycles set coach_notes = 'no'
             where id = '10000000-0000-0000-0000-000000000001' returning 1)
  select count(*)::int from u $$, 'values (0)', 'coach non collegato: non modifica il mesociclo di a');
select throws_ok($$
  insert into public.sessions (mesocycle_id, position, name)
  values ('10000000-0000-0000-0000-000000000001', 2, 'C') $$,
  '42501', null, 'coach non collegato: non aggiunge sessioni');

select tests.login('00000000-0000-0000-0000-0000000000c3');
select throws_ok($$
  insert into public.sessions (mesocycle_id, position, name)
  values ('10000000-0000-0000-0000-000000000001', 2, 'C') $$,
  '42501', null, 'coach pending: non aggiunge sessioni');
select throws_ok($$
  update public.coach_athletes set status = 'active'
  where coach_id = '00000000-0000-0000-0000-0000000000c3' $$,
  '42501', null, 'coach pending: non attiva da solo il collegamento');

-- ---------------------------------------------------------------------------
-- Scrittura: atleta proprietario
-- ---------------------------------------------------------------------------

select tests.login('00000000-0000-0000-0000-0000000000a1');
select lives_ok($$
  insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week)
  values ('70000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-0000000000a1',
          '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 2) $$,
  'atleta: registra una seduta');
select lives_ok($$
  insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx)
  values ('80000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-0000000000a1',
          '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000011',
          '50000000-0000-0000-0000-000000000001', 0) $$,
  'atleta: registra una serie');
select lives_ok($$
  insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale)
  values ('80000000-0000-0000-0000-000000000011', '00000000-0000-0000-0000-0000000000a1',
          '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000011',
          '50000000-0000-0000-0000-000000000001', 0, 2, 'BUF')
  on conflict (workout_id, block_id, set_idx) do update
    set effort_value = excluded.effort_value, effort_scale = excluded.effort_scale $$,
  'atleta: lo stesso upsert reinviato non fallisce');
select is(
  (select count(*)::int from public.set_logs where workout_id = '70000000-0000-0000-0000-000000000011'), 1,
  'atleta: upsert idempotente, una sola riga');
select results_eq($$
  with u as (update public.set_logs set deleted_at = now()
             where id = '80000000-0000-0000-0000-000000000011' returning 1)
  select count(*)::int from u $$, 'values (1)', 'atleta: soft delete della propria serie');
select results_eq($$
  with d as (delete from public.set_logs returning 1) select count(*)::int from d $$,
  'values (0)', 'atleta: nessuna cancellazione fisica');
select results_eq($$
  with u as (update public.mesocycles set name = 'mio' returning 1) select count(*)::int from u $$,
  'values (0)', 'atleta: non modifica la programmazione');
select throws_ok($$
  insert into public.sessions (mesocycle_id, position, name)
  values ('10000000-0000-0000-0000-000000000001', 2, 'C') $$,
  '42501', null, 'atleta: non aggiunge sessioni');
select lives_ok($$
  update public.coach_athletes set status = 'active'
  where coach_id = '00000000-0000-0000-0000-0000000000c3' $$,
  'atleta: accetta l''invito pending');
select throws_ok($$
  update public.coach_athletes set coach_id = '00000000-0000-0000-0000-0000000000c2'
  where coach_id = '00000000-0000-0000-0000-0000000000c1' $$,
  '42501', null, 'atleta: non riassegna un collegamento');

-- ---------------------------------------------------------------------------
-- Scrittura: altro atleta
-- ---------------------------------------------------------------------------

select tests.login('00000000-0000-0000-0000-0000000000b1');
select results_eq($$
  with u as (update public.set_logs set effort_value = 3
             where athlete_id = '00000000-0000-0000-0000-0000000000a1' returning 1)
  select count(*)::int from u $$, 'values (0)', 'altro atleta: non modifica le serie di a');
select throws_ok($$
  insert into public.set_segments (athlete_id, set_log_id, seg_idx, reps)
  values ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000001', 1, 5) $$,
  '42501', null, 'altro atleta: non scrive a nome di a');
select throws_ok($$
  insert into public.set_segments (athlete_id, set_log_id, seg_idx, reps)
  values ('00000000-0000-0000-0000-0000000000b1', '80000000-0000-0000-0000-000000000001', 1, 5) $$,
  '23503', null, 'altro atleta: non aggancia segmenti alle serie di a');
select throws_ok($$
  insert into public.workouts (athlete_id, mesocycle_id, session_id, week)
  values ('00000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-000000000001',
          '20000000-0000-0000-0000-000000000001', 3) $$,
  '42501', null, 'altro atleta: non registra sul mesociclo di a');

-- ---------------------------------------------------------------------------
-- Vincoli (come postgres)
-- ---------------------------------------------------------------------------

reset role;

select throws_ok($$
  insert into public.mesocycles (athlete_id, name, start_date, weeks, status)
  values ('00000000-0000-0000-0000-0000000000a1', 'altro', '2026-12-01', 4, 'active') $$,
  '23505', null, 'un solo mesociclo active per atleta');
select throws_ok($$
  update public.set_logs set effort_value = 5, effort_scale = 'RPE'
  where id = '80000000-0000-0000-0000-000000000001' $$,
  '23514', null, 'RPE fuori scala rifiutato');
select throws_ok($$
  update public.set_logs set effort_value = 1.3 where id = '80000000-0000-0000-0000-000000000001' $$,
  '23514', null, 'sforzo a passo 0,5');
select throws_ok($$
  insert into public.set_logs (athlete_id, mesocycle_id, workout_id, block_id, set_idx)
  values ('00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001',
          '70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 1) $$,
  '23503', null, 'serie su un blocco di un altro mesociclo rifiutata');
select throws_ok($$
  delete from public.set_blocks where id = '50000000-0000-0000-0000-000000000001' $$,
  '23503', null, 'un blocco con serie registrate non si cancella fisicamente');
select throws_ok($$
  update public.set_blocks set ref_block_id = '50000000-0000-0000-0000-000000000003'
  where id = '50000000-0000-0000-0000-000000000001' $$,
  '23503', null, 'back-off legato solo a blocchi dello stesso mesociclo');

update public.mesocycles set name = 'rinominato' where id = '10000000-0000-0000-0000-000000000001';
select is(
  (select updated_at from public.mesocycles where id = '10000000-0000-0000-0000-000000000001'), now(),
  'updated_at aggiornato a ogni modifica');

select * from finish();
rollback;
