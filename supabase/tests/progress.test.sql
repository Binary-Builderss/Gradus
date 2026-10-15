-- weekly_exercise_progress: serie prescritte ed eseguite, miglior serie (e1RM di Epley), esclusioni e permessi.
-- c = coach collegato ad a, x = coach di b. Mesociclo 01 (a): 3 settimane, esercizio e1 (panca).
-- Blocco 51 lavoro (sett. 1: 3 serie, 2: 3 serie, 4: 9 serie = fuori mesociclo), 52 riscaldamento
-- (sett. 1: 2 serie). Settimana 1 eseguita: 3 serie sul 51 (80×8, 90×5, 85×6 con drop 70×10) e 1 sul 52 (40×10).

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c@test.dev'),
  ('00000000-0000-0000-0000-0000000000c2', 'x@test.dev'),
  ('00000000-0000-0000-0000-0000000000a1', 'a@test.dev'),
  ('00000000-0000-0000-0000-0000000000b1', 'b@test.dev');
insert into public.coach_athletes (coach_id, athlete_id, status) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'active'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000b1', 'active');
insert into public.exercises (id, owner_id, name) values
  ('e0000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000c1', 'Panca');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, status) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'A', '2026-10-05', 3, 'active');
insert into public.sessions (id, mesocycle_id, position, name) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 0, 'A');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 0, 'e0000000-0000-0000-0000-0000000000e1');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 0, 'working'),
  ('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 1, 'warmup');
insert into public.block_weeks (mesocycle_id, block_id, week, sets) values
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 1, 3),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 2, 3),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 4, 9),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', 1, 2);
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values
  ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx) values
  ('80000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 0),
  ('80000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 1),
  ('80000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 2),
  ('80000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', 0);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values
  ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000001', 0, 80, 8),
  ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000002', 0, 90, 5),
  ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000003', 0, 85, 6),
  ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000003', 1, 70, 10),
  ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000004', 0, 120, 10);

create schema tests;
grant usage on schema tests to authenticated;
create function tests.login(uid uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
grant execute on all functions in schema tests to authenticated;

-- Settimana 1: 3 serie prescritte (riscaldamento escluso), 3 fatte. e1RM: 80×8 = 101,3; 90×5 = 105;
-- 85×6 = 102; 70×10 = 93,3 → vince 90×5 con 105. Settimana 2: solo prescritta. Settimana 4: fuori.
select tests.login('00000000-0000-0000-0000-0000000000c1');
select results_eq(
  $$select week::int, sets_prescribed, sets_done, top_load_kg::float8, top_reps::int, e1rm::float8
    from public.weekly_exercise_progress('10000000-0000-0000-0000-000000000001')$$,
  $$values (1, 3, 3, 90::float8, 5, 105::float8), (2, 3, 0, null::float8, null::int, null::float8)$$,
  'serie prescritte ed eseguite e miglior serie per settimana, senza riscaldamento né settimane fuori');

select tests.login('00000000-0000-0000-0000-0000000000a1');
select is(
  (select count(*)::int from public.weekly_exercise_progress('10000000-0000-0000-0000-000000000001')),
  2, 'l''atleta proprietario vede i suoi progressi');

select tests.login('00000000-0000-0000-0000-0000000000c2');
select is(
  (select count(*)::int from public.weekly_exercise_progress('10000000-0000-0000-0000-000000000001')),
  0, 'un coach non collegato non vede nulla');
select tests.login('00000000-0000-0000-0000-0000000000b1');
select is(
  (select count(*)::int from public.weekly_exercise_progress('10000000-0000-0000-0000-000000000001')),
  0, 'un altro atleta non vede nulla');

select * from finish();
rollback;
