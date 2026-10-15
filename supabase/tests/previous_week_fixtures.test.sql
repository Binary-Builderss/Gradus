-- GENERATO da fixtures/generate-sql.mjs a partire da fixtures/previous_week_cases.json: non modificare a mano.
-- previous_week_reference: gli stessi casi della fixture che passa anche l'implementazione Swift.

begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

create schema tests;
grant usage on schema tests to authenticated;
create function tests.login(uid uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
grant execute on all functions in schema tests to authenticated;

insert into public.exercises (id, owner_id, name) values ('e0000000-0000-4000-8000-000000000001', null, 'Esercizio di prova') on conflict do nothing;

-- 1. settimana 1: nessun riferimento
insert into auth.users (id, email) values ('a0000001-0000-4000-8000-000000000001', 'caso1@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000001-0000-4000-8000-000000000001', 'a0000001-0000-4000-8000-000000000001', 'Caso 1', '2026-01-05', 6, '{}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000001-0000-4000-8000-000000000001', 'b0000001-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000001-0000-4000-8000-000000000001', 'b0000001-0000-4000-8000-000000000001', 'd0000001-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000001-0000-4000-8000-000000000001', 'b0000001-0000-4000-8000-000000000001', '10000001-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000001-0000-4000-8000-000000000001', 'b0000001-0000-4000-8000-000000000001', '20000001-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000001-0000-4000-8000-000000000001', 'b0000001-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000001-0000-4000-8000-000000000002', 'b0000001-0000-4000-8000-000000000001', 'e0000001-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000001-0000-4000-8000-000000000002', 'b0000001-0000-4000-8000-000000000001', '10000001-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000001-0000-4000-8000-000000000001', 'b0000001-0000-4000-8000-000000000001', '20000001-0000-4000-8000-000000000002', 0, 'working');

-- 2. settimana 2: la stessa serie della settimana 1, con lo sforzo
insert into auth.users (id, email) values ('a0000002-0000-4000-8000-000000000001', 'caso2@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000002-0000-4000-8000-000000000001', 'a0000002-0000-4000-8000-000000000001', 'Caso 2', '2026-01-05', 6, '{}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000002-0000-4000-8000-000000000001', 'b0000002-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000002-0000-4000-8000-000000000001', 'b0000002-0000-4000-8000-000000000001', 'd0000002-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000002-0000-4000-8000-000000000001', 'b0000002-0000-4000-8000-000000000001', '10000002-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000002-0000-4000-8000-000000000001', 'b0000002-0000-4000-8000-000000000001', '20000002-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000002-0000-4000-8000-000000000001', 'b0000002-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000002-0000-4000-8000-000000000002', 'b0000002-0000-4000-8000-000000000001', 'e0000002-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000002-0000-4000-8000-000000000002', 'b0000002-0000-4000-8000-000000000001', '10000002-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000002-0000-4000-8000-000000000001', 'b0000002-0000-4000-8000-000000000001', '20000002-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000002-0000-4000-8000-000000001001', 'a0000002-0000-4000-8000-000000000001', 'b0000002-0000-4000-8000-000000000001', 'd0000002-0000-4000-8000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000002-0000-4000-8000-000000000001', 'a0000002-0000-4000-8000-000000000001', 'b0000002-0000-4000-8000-000000000001', '60000002-0000-4000-8000-000000001001', '30000002-0000-4000-8000-000000000001', 0, 1, 'BUF'::public.effort_scale);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000002-0000-4000-8000-000000000001', '70000002-0000-4000-8000-000000000001', 0, 100, 5);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000002-0000-4000-8000-000000000002', 'a0000002-0000-4000-8000-000000000001', 'b0000002-0000-4000-8000-000000000001', '60000002-0000-4000-8000-000000001001', '30000002-0000-4000-8000-000000000001', 1, 0.5, 'BUF'::public.effort_scale);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000002-0000-4000-8000-000000000001', '70000002-0000-4000-8000-000000000002', 0, 100, 4);

-- 3. serie senza sforzo: il riferimento c'è, lo sforzo no
insert into auth.users (id, email) values ('a0000003-0000-4000-8000-000000000001', 'caso3@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000003-0000-4000-8000-000000000001', 'a0000003-0000-4000-8000-000000000001', 'Caso 3', '2026-01-05', 6, '{}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000003-0000-4000-8000-000000000001', 'b0000003-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000003-0000-4000-8000-000000000001', 'b0000003-0000-4000-8000-000000000001', 'd0000003-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000003-0000-4000-8000-000000000001', 'b0000003-0000-4000-8000-000000000001', '10000003-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000003-0000-4000-8000-000000000001', 'b0000003-0000-4000-8000-000000000001', '20000003-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000003-0000-4000-8000-000000000001', 'b0000003-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000003-0000-4000-8000-000000000002', 'b0000003-0000-4000-8000-000000000001', 'e0000003-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000003-0000-4000-8000-000000000002', 'b0000003-0000-4000-8000-000000000001', '10000003-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000003-0000-4000-8000-000000000001', 'b0000003-0000-4000-8000-000000000001', '20000003-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000003-0000-4000-8000-000000001001', 'a0000003-0000-4000-8000-000000000001', 'b0000003-0000-4000-8000-000000000001', 'd0000003-0000-4000-8000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000003-0000-4000-8000-000000000001', 'a0000003-0000-4000-8000-000000000001', 'b0000003-0000-4000-8000-000000000001', '60000003-0000-4000-8000-000000001001', '30000003-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000003-0000-4000-8000-000000000001', '70000003-0000-4000-8000-000000000001', 0, 80, 10);

-- 4. drop set: i segmenti restano nell'ordine registrato
insert into auth.users (id, email) values ('a0000004-0000-4000-8000-000000000001', 'caso4@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000004-0000-4000-8000-000000000001', 'a0000004-0000-4000-8000-000000000001', 'Caso 4', '2026-01-05', 6, '{}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000004-0000-4000-8000-000000000001', 'b0000004-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000004-0000-4000-8000-000000000001', 'b0000004-0000-4000-8000-000000000001', 'd0000004-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000004-0000-4000-8000-000000000001', 'b0000004-0000-4000-8000-000000000001', '10000004-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000004-0000-4000-8000-000000000001', 'b0000004-0000-4000-8000-000000000001', '20000004-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000004-0000-4000-8000-000000000001', 'b0000004-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000004-0000-4000-8000-000000000002', 'b0000004-0000-4000-8000-000000000001', 'e0000004-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000004-0000-4000-8000-000000000002', 'b0000004-0000-4000-8000-000000000001', '10000004-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000004-0000-4000-8000-000000000001', 'b0000004-0000-4000-8000-000000000001', '20000004-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000004-0000-4000-8000-000000001002', 'a0000004-0000-4000-8000-000000000001', 'b0000004-0000-4000-8000-000000000001', 'd0000004-0000-4000-8000-000000000001', 2);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000004-0000-4000-8000-000000000001', 'a0000004-0000-4000-8000-000000000001', 'b0000004-0000-4000-8000-000000000001', '60000004-0000-4000-8000-000000001002', '30000004-0000-4000-8000-000000000001', 0, 0, 'BUF'::public.effort_scale);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000004-0000-4000-8000-000000000001', '70000004-0000-4000-8000-000000000001', 0, 100, 8);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000004-0000-4000-8000-000000000001', '70000004-0000-4000-8000-000000000001', 1, 75, 6);

-- 5. lo sforzo resta nella scala in cui è stato inserito (RPE)
insert into auth.users (id, email) values ('a0000005-0000-4000-8000-000000000001', 'caso5@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000005-0000-4000-8000-000000000001', 'a0000005-0000-4000-8000-000000000001', 'Caso 5', '2026-01-05', 6, '{}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000005-0000-4000-8000-000000000001', 'b0000005-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000005-0000-4000-8000-000000000001', 'b0000005-0000-4000-8000-000000000001', 'd0000005-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000005-0000-4000-8000-000000000001', 'b0000005-0000-4000-8000-000000000001', '10000005-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000005-0000-4000-8000-000000000001', 'b0000005-0000-4000-8000-000000000001', '20000005-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000005-0000-4000-8000-000000000001', 'b0000005-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000005-0000-4000-8000-000000000002', 'b0000005-0000-4000-8000-000000000001', 'e0000005-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000005-0000-4000-8000-000000000002', 'b0000005-0000-4000-8000-000000000001', '10000005-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000005-0000-4000-8000-000000000001', 'b0000005-0000-4000-8000-000000000001', '20000005-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000005-0000-4000-8000-000000001001', 'a0000005-0000-4000-8000-000000000001', 'b0000005-0000-4000-8000-000000000001', 'd0000005-0000-4000-8000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000005-0000-4000-8000-000000000001', 'a0000005-0000-4000-8000-000000000001', 'b0000005-0000-4000-8000-000000000001', '60000005-0000-4000-8000-000000001001', '30000005-0000-4000-8000-000000000001', 0, 8.5, 'RPE'::public.effort_scale);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000005-0000-4000-8000-000000000001', '70000005-0000-4000-8000-000000000001', 0, 120, 3);

-- 6. ogni blocco ha il suo riferimento (multiset)
insert into auth.users (id, email) values ('a0000006-0000-4000-8000-000000000001', 'caso6@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000006-0000-4000-8000-000000000001', 'a0000006-0000-4000-8000-000000000001', 'Caso 6', '2026-01-05', 6, '{}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000006-0000-4000-8000-000000000001', 'b0000006-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000006-0000-4000-8000-000000000001', 'b0000006-0000-4000-8000-000000000001', 'd0000006-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000006-0000-4000-8000-000000000001', 'b0000006-0000-4000-8000-000000000001', '10000006-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000006-0000-4000-8000-000000000001', 'b0000006-0000-4000-8000-000000000001', '20000006-0000-4000-8000-000000000001', 0, 'working');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000006-0000-4000-8000-000000000002', 'b0000006-0000-4000-8000-000000000001', '20000006-0000-4000-8000-000000000001', 1, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000006-0000-4000-8000-000000000001', 'b0000006-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000006-0000-4000-8000-000000000002', 'b0000006-0000-4000-8000-000000000001', 'e0000006-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000006-0000-4000-8000-000000000002', 'b0000006-0000-4000-8000-000000000001', '10000006-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000006-0000-4000-8000-000000000001', 'b0000006-0000-4000-8000-000000000001', '20000006-0000-4000-8000-000000000002', 0, 'working');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000006-0000-4000-8000-000000000002', 'b0000006-0000-4000-8000-000000000001', '20000006-0000-4000-8000-000000000002', 1, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000006-0000-4000-8000-000000001001', 'a0000006-0000-4000-8000-000000000001', 'b0000006-0000-4000-8000-000000000001', 'd0000006-0000-4000-8000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000006-0000-4000-8000-000000000001', 'a0000006-0000-4000-8000-000000000001', 'b0000006-0000-4000-8000-000000000001', '60000006-0000-4000-8000-000000001001', '30000006-0000-4000-8000-000000000002', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000006-0000-4000-8000-000000000001', '70000006-0000-4000-8000-000000000001', 0, 90, 7);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000006-0000-4000-8000-000000000002', 'a0000006-0000-4000-8000-000000000001', 'b0000006-0000-4000-8000-000000000001', '60000006-0000-4000-8000-000000001001', '30000006-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000006-0000-4000-8000-000000000001', '70000006-0000-4000-8000-000000000002', 0, 100, 5);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000006-0000-4000-8000-000000000003', 'a0000006-0000-4000-8000-000000000001', 'b0000006-0000-4000-8000-000000000001', '60000006-0000-4000-8000-000000001001', '30000006-0000-4000-8000-000000000002', 1, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000006-0000-4000-8000-000000000001', '70000006-0000-4000-8000-000000000003', 0, 90, 6);

-- 7. solo le serie registrate: gli indici saltati non hanno riferimento
insert into auth.users (id, email) values ('a0000007-0000-4000-8000-000000000001', 'caso7@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000007-0000-4000-8000-000000000001', 'a0000007-0000-4000-8000-000000000001', 'Caso 7', '2026-01-05', 6, '{}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000007-0000-4000-8000-000000000001', 'b0000007-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000007-0000-4000-8000-000000000001', 'b0000007-0000-4000-8000-000000000001', 'd0000007-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000007-0000-4000-8000-000000000001', 'b0000007-0000-4000-8000-000000000001', '10000007-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000007-0000-4000-8000-000000000001', 'b0000007-0000-4000-8000-000000000001', '20000007-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000007-0000-4000-8000-000000000001', 'b0000007-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000007-0000-4000-8000-000000000002', 'b0000007-0000-4000-8000-000000000001', 'e0000007-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000007-0000-4000-8000-000000000002', 'b0000007-0000-4000-8000-000000000001', '10000007-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000007-0000-4000-8000-000000000001', 'b0000007-0000-4000-8000-000000000001', '20000007-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000007-0000-4000-8000-000000001001', 'a0000007-0000-4000-8000-000000000001', 'b0000007-0000-4000-8000-000000000001', 'd0000007-0000-4000-8000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000007-0000-4000-8000-000000000001', 'a0000007-0000-4000-8000-000000000001', 'b0000007-0000-4000-8000-000000000001', '60000007-0000-4000-8000-000000001001', '30000007-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000007-0000-4000-8000-000000000001', '70000007-0000-4000-8000-000000000001', 0, 100, 5);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000007-0000-4000-8000-000000000002', 'a0000007-0000-4000-8000-000000000001', 'b0000007-0000-4000-8000-000000000001', '60000007-0000-4000-8000-000000001001', '30000007-0000-4000-8000-000000000001', 2, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000007-0000-4000-8000-000000000001', '70000007-0000-4000-8000-000000000002', 0, 95, 6);

-- 8. serie con il solo sforzo (nessun carico): il riferimento c'è
insert into auth.users (id, email) values ('a0000008-0000-4000-8000-000000000001', 'caso8@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000008-0000-4000-8000-000000000001', 'a0000008-0000-4000-8000-000000000001', 'Caso 8', '2026-01-05', 6, '{}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000008-0000-4000-8000-000000000001', 'b0000008-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000008-0000-4000-8000-000000000001', 'b0000008-0000-4000-8000-000000000001', 'd0000008-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000008-0000-4000-8000-000000000001', 'b0000008-0000-4000-8000-000000000001', '10000008-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000008-0000-4000-8000-000000000001', 'b0000008-0000-4000-8000-000000000001', '20000008-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000008-0000-4000-8000-000000000001', 'b0000008-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000008-0000-4000-8000-000000000002', 'b0000008-0000-4000-8000-000000000001', 'e0000008-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000008-0000-4000-8000-000000000002', 'b0000008-0000-4000-8000-000000000001', '10000008-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000008-0000-4000-8000-000000000001', 'b0000008-0000-4000-8000-000000000001', '20000008-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000008-0000-4000-8000-000000001001', 'a0000008-0000-4000-8000-000000000001', 'b0000008-0000-4000-8000-000000000001', 'd0000008-0000-4000-8000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000008-0000-4000-8000-000000000001', 'a0000008-0000-4000-8000-000000000001', 'b0000008-0000-4000-8000-000000000001', '60000008-0000-4000-8000-000000001001', '30000008-0000-4000-8000-000000000001', 0, 2, 'BUF'::public.effort_scale);

-- 9. seduta saltata in N−1: nessun riferimento, non si risale alle settimane prima
insert into auth.users (id, email) values ('a0000009-0000-4000-8000-000000000001', 'caso9@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000009-0000-4000-8000-000000000001', 'a0000009-0000-4000-8000-000000000001', 'Caso 9', '2026-01-05', 6, '{}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000009-0000-4000-8000-000000000001', 'b0000009-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000009-0000-4000-8000-000000000001', 'b0000009-0000-4000-8000-000000000001', 'd0000009-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000009-0000-4000-8000-000000000001', 'b0000009-0000-4000-8000-000000000001', '10000009-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000009-0000-4000-8000-000000000001', 'b0000009-0000-4000-8000-000000000001', '20000009-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000009-0000-4000-8000-000000000001', 'b0000009-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000009-0000-4000-8000-000000000002', 'b0000009-0000-4000-8000-000000000001', 'e0000009-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000009-0000-4000-8000-000000000002', 'b0000009-0000-4000-8000-000000000001', '10000009-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000009-0000-4000-8000-000000000001', 'b0000009-0000-4000-8000-000000000001', '20000009-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000009-0000-4000-8000-000000001001', 'a0000009-0000-4000-8000-000000000001', 'b0000009-0000-4000-8000-000000000001', 'd0000009-0000-4000-8000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000009-0000-4000-8000-000000000001', 'a0000009-0000-4000-8000-000000000001', 'b0000009-0000-4000-8000-000000000001', '60000009-0000-4000-8000-000000001001', '30000009-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000009-0000-4000-8000-000000000001', '70000009-0000-4000-8000-000000000001', 0, 100, 5);

-- 10. la settimana richiesta ha già dati propri: il riferimento resta N−1
insert into auth.users (id, email) values ('a0000010-0000-4000-8000-000000000001', 'caso10@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000010-0000-4000-8000-000000000001', 'a0000010-0000-4000-8000-000000000001', 'Caso 10', '2026-01-05', 6, '{}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000010-0000-4000-8000-000000000001', 'b0000010-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000010-0000-4000-8000-000000000001', 'b0000010-0000-4000-8000-000000000001', 'd0000010-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000010-0000-4000-8000-000000000001', 'b0000010-0000-4000-8000-000000000001', '10000010-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000010-0000-4000-8000-000000000001', 'b0000010-0000-4000-8000-000000000001', '20000010-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000010-0000-4000-8000-000000000001', 'b0000010-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000010-0000-4000-8000-000000000002', 'b0000010-0000-4000-8000-000000000001', 'e0000010-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000010-0000-4000-8000-000000000002', 'b0000010-0000-4000-8000-000000000001', '10000010-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000010-0000-4000-8000-000000000001', 'b0000010-0000-4000-8000-000000000001', '20000010-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000010-0000-4000-8000-000000001001', 'a0000010-0000-4000-8000-000000000001', 'b0000010-0000-4000-8000-000000000001', 'd0000010-0000-4000-8000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000010-0000-4000-8000-000000000001', 'a0000010-0000-4000-8000-000000000001', 'b0000010-0000-4000-8000-000000000001', '60000010-0000-4000-8000-000000001001', '30000010-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000010-0000-4000-8000-000000000001', '70000010-0000-4000-8000-000000000001', 0, 100, 5);
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000010-0000-4000-8000-000000001002', 'a0000010-0000-4000-8000-000000000001', 'b0000010-0000-4000-8000-000000000001', 'd0000010-0000-4000-8000-000000000001', 2);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000010-0000-4000-8000-000000000002', 'a0000010-0000-4000-8000-000000000001', 'b0000010-0000-4000-8000-000000000001', '60000010-0000-4000-8000-000000001002', '30000010-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000010-0000-4000-8000-000000000001', '70000010-0000-4000-8000-000000000002', 0, 102.5, 5);

-- 11. scarico a metà: la settimana di scarico è esclusa dalla ricerca, si usa quella prima
insert into auth.users (id, email) values ('a0000011-0000-4000-8000-000000000001', 'caso11@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000011-0000-4000-8000-000000000001', 'a0000011-0000-4000-8000-000000000001', 'Caso 11', '2026-01-05', 8, '{3}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000011-0000-4000-8000-000000000001', 'b0000011-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000011-0000-4000-8000-000000000001', 'b0000011-0000-4000-8000-000000000001', 'd0000011-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000011-0000-4000-8000-000000000001', 'b0000011-0000-4000-8000-000000000001', '10000011-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000011-0000-4000-8000-000000000001', 'b0000011-0000-4000-8000-000000000001', '20000011-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000011-0000-4000-8000-000000000001', 'b0000011-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000011-0000-4000-8000-000000000002', 'b0000011-0000-4000-8000-000000000001', 'e0000011-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000011-0000-4000-8000-000000000002', 'b0000011-0000-4000-8000-000000000001', '10000011-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000011-0000-4000-8000-000000000001', 'b0000011-0000-4000-8000-000000000001', '20000011-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000011-0000-4000-8000-000000001002', 'a0000011-0000-4000-8000-000000000001', 'b0000011-0000-4000-8000-000000000001', 'd0000011-0000-4000-8000-000000000001', 2);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000011-0000-4000-8000-000000000001', 'a0000011-0000-4000-8000-000000000001', 'b0000011-0000-4000-8000-000000000001', '60000011-0000-4000-8000-000000001002', '30000011-0000-4000-8000-000000000001', 0, 1, 'BUF'::public.effort_scale);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000011-0000-4000-8000-000000000001', '70000011-0000-4000-8000-000000000001', 0, 105, 5);
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000011-0000-4000-8000-000000001003', 'a0000011-0000-4000-8000-000000000001', 'b0000011-0000-4000-8000-000000000001', 'd0000011-0000-4000-8000-000000000001', 3);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000011-0000-4000-8000-000000000002', 'a0000011-0000-4000-8000-000000000001', 'b0000011-0000-4000-8000-000000000001', '60000011-0000-4000-8000-000000001003', '30000011-0000-4000-8000-000000000001', 0, 4, 'BUF'::public.effort_scale);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000011-0000-4000-8000-000000000001', '70000011-0000-4000-8000-000000000002', 0, 60, 8);

-- 12. scarico a metà e seduta saltata prima dello scarico: nessun riferimento
insert into auth.users (id, email) values ('a0000012-0000-4000-8000-000000000001', 'caso12@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000012-0000-4000-8000-000000000001', 'a0000012-0000-4000-8000-000000000001', 'Caso 12', '2026-01-05', 8, '{3}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000012-0000-4000-8000-000000000001', 'b0000012-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000012-0000-4000-8000-000000000001', 'b0000012-0000-4000-8000-000000000001', 'd0000012-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000012-0000-4000-8000-000000000001', 'b0000012-0000-4000-8000-000000000001', '10000012-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000012-0000-4000-8000-000000000001', 'b0000012-0000-4000-8000-000000000001', '20000012-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000012-0000-4000-8000-000000000001', 'b0000012-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000012-0000-4000-8000-000000000002', 'b0000012-0000-4000-8000-000000000001', 'e0000012-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000012-0000-4000-8000-000000000002', 'b0000012-0000-4000-8000-000000000001', '10000012-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000012-0000-4000-8000-000000000001', 'b0000012-0000-4000-8000-000000000001', '20000012-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000012-0000-4000-8000-000000001001', 'a0000012-0000-4000-8000-000000000001', 'b0000012-0000-4000-8000-000000000001', 'd0000012-0000-4000-8000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000012-0000-4000-8000-000000000001', 'a0000012-0000-4000-8000-000000000001', 'b0000012-0000-4000-8000-000000000001', '60000012-0000-4000-8000-000000001001', '30000012-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000012-0000-4000-8000-000000000001', '70000012-0000-4000-8000-000000000001', 0, 100, 5);
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000012-0000-4000-8000-000000001003', 'a0000012-0000-4000-8000-000000000001', 'b0000012-0000-4000-8000-000000000001', 'd0000012-0000-4000-8000-000000000001', 3);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000012-0000-4000-8000-000000000002', 'a0000012-0000-4000-8000-000000000001', 'b0000012-0000-4000-8000-000000000001', '60000012-0000-4000-8000-000000001003', '30000012-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000012-0000-4000-8000-000000000001', '70000012-0000-4000-8000-000000000002', 0, 60, 8);

-- 13. due scarichi di fila: si salta anche il secondo
insert into auth.users (id, email) values ('a0000013-0000-4000-8000-000000000001', 'caso13@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000013-0000-4000-8000-000000000001', 'a0000013-0000-4000-8000-000000000001', 'Caso 13', '2026-01-05', 8, '{3,4}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000013-0000-4000-8000-000000000001', 'b0000013-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000013-0000-4000-8000-000000000001', 'b0000013-0000-4000-8000-000000000001', 'd0000013-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000013-0000-4000-8000-000000000001', 'b0000013-0000-4000-8000-000000000001', '10000013-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000013-0000-4000-8000-000000000001', 'b0000013-0000-4000-8000-000000000001', '20000013-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000013-0000-4000-8000-000000000001', 'b0000013-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000013-0000-4000-8000-000000000002', 'b0000013-0000-4000-8000-000000000001', 'e0000013-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000013-0000-4000-8000-000000000002', 'b0000013-0000-4000-8000-000000000001', '10000013-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000013-0000-4000-8000-000000000001', 'b0000013-0000-4000-8000-000000000001', '20000013-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000013-0000-4000-8000-000000001002', 'a0000013-0000-4000-8000-000000000001', 'b0000013-0000-4000-8000-000000000001', 'd0000013-0000-4000-8000-000000000001', 2);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000013-0000-4000-8000-000000000001', 'a0000013-0000-4000-8000-000000000001', 'b0000013-0000-4000-8000-000000000001', '60000013-0000-4000-8000-000000001002', '30000013-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000013-0000-4000-8000-000000000001', '70000013-0000-4000-8000-000000000001', 0, 105, 5);

-- 14. tutte le settimane prima sono di scarico: nessun riferimento
insert into auth.users (id, email) values ('a0000014-0000-4000-8000-000000000001', 'caso14@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000014-0000-4000-8000-000000000001', 'a0000014-0000-4000-8000-000000000001', 'Caso 14', '2026-01-05', 8, '{1}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000014-0000-4000-8000-000000000001', 'b0000014-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000014-0000-4000-8000-000000000001', 'b0000014-0000-4000-8000-000000000001', 'd0000014-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000014-0000-4000-8000-000000000001', 'b0000014-0000-4000-8000-000000000001', '10000014-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000014-0000-4000-8000-000000000001', 'b0000014-0000-4000-8000-000000000001', '20000014-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000014-0000-4000-8000-000000000001', 'b0000014-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000014-0000-4000-8000-000000000002', 'b0000014-0000-4000-8000-000000000001', 'e0000014-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000014-0000-4000-8000-000000000002', 'b0000014-0000-4000-8000-000000000001', '10000014-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000014-0000-4000-8000-000000000001', 'b0000014-0000-4000-8000-000000000001', '20000014-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000014-0000-4000-8000-000000001001', 'a0000014-0000-4000-8000-000000000001', 'b0000014-0000-4000-8000-000000000001', 'd0000014-0000-4000-8000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000014-0000-4000-8000-000000000001', 'a0000014-0000-4000-8000-000000000001', 'b0000014-0000-4000-8000-000000000001', '60000014-0000-4000-8000-000000001001', '30000014-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000014-0000-4000-8000-000000000001', '70000014-0000-4000-8000-000000000001', 0, 60, 8);

-- 15. un'altra seduta nella stessa settimana non conta
insert into auth.users (id, email) values ('a0000015-0000-4000-8000-000000000001', 'caso15@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000015-0000-4000-8000-000000000001', 'a0000015-0000-4000-8000-000000000001', 'Caso 15', '2026-01-05', 6, '{}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000015-0000-4000-8000-000000000001', 'b0000015-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000015-0000-4000-8000-000000000001', 'b0000015-0000-4000-8000-000000000001', 'd0000015-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000015-0000-4000-8000-000000000001', 'b0000015-0000-4000-8000-000000000001', '10000015-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000015-0000-4000-8000-000000000001', 'b0000015-0000-4000-8000-000000000001', '20000015-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000015-0000-4000-8000-000000000001', 'b0000015-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000015-0000-4000-8000-000000000002', 'b0000015-0000-4000-8000-000000000001', 'e0000015-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000015-0000-4000-8000-000000000002', 'b0000015-0000-4000-8000-000000000001', '10000015-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000015-0000-4000-8000-000000000001', 'b0000015-0000-4000-8000-000000000001', '20000015-0000-4000-8000-000000000002', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000015-0000-4000-8000-000000002001', 'a0000015-0000-4000-8000-000000000001', 'b0000015-0000-4000-8000-000000000001', 'e0000015-0000-4000-8000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000015-0000-4000-8000-000000000001', 'a0000015-0000-4000-8000-000000000001', 'b0000015-0000-4000-8000-000000000001', '60000015-0000-4000-8000-000000002001', '40000015-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000015-0000-4000-8000-000000000001', '70000015-0000-4000-8000-000000000001', 0, 100, 5);

-- 16. mai dati di un mesociclo precedente, nemmeno come ripiego
insert into auth.users (id, email) values ('a0000016-0000-4000-8000-000000000001', 'caso16@fixture.test');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('b0000016-0000-4000-8000-000000000001', 'a0000016-0000-4000-8000-000000000001', 'Caso 16', '2026-01-05', 6, '{}', 'active');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values ('c0000016-0000-4000-8000-000000000001', 'a0000016-0000-4000-8000-000000000001', 'Caso 16 precedente', '2025-10-06', 6, '{}', 'completed');
insert into public.sessions (id, mesocycle_id, position, name) values ('d0000016-0000-4000-8000-000000000001', 'b0000016-0000-4000-8000-000000000001', 0, 'main');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000016-0000-4000-8000-000000000001', 'b0000016-0000-4000-8000-000000000001', 'd0000016-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000016-0000-4000-8000-000000000001', 'b0000016-0000-4000-8000-000000000001', '10000016-0000-4000-8000-000000000001', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('30000016-0000-4000-8000-000000000001', 'b0000016-0000-4000-8000-000000000001', '20000016-0000-4000-8000-000000000001', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('e0000016-0000-4000-8000-000000000001', 'b0000016-0000-4000-8000-000000000001', 1, 'other');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000016-0000-4000-8000-000000000002', 'b0000016-0000-4000-8000-000000000001', 'e0000016-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000016-0000-4000-8000-000000000002', 'b0000016-0000-4000-8000-000000000001', '10000016-0000-4000-8000-000000000002', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('40000016-0000-4000-8000-000000000001', 'b0000016-0000-4000-8000-000000000001', '20000016-0000-4000-8000-000000000002', 0, 'working');
insert into public.sessions (id, mesocycle_id, position, name) values ('f0000016-0000-4000-8000-000000000001', 'c0000016-0000-4000-8000-000000000001', 2, 'prev');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values ('10000016-0000-4000-8000-000000000003', 'c0000016-0000-4000-8000-000000000001', 'f0000016-0000-4000-8000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values ('20000016-0000-4000-8000-000000000003', 'c0000016-0000-4000-8000-000000000001', '10000016-0000-4000-8000-000000000003', 0, 'e0000000-0000-4000-8000-000000000001');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values ('50000016-0000-4000-8000-000000000001', 'c0000016-0000-4000-8000-000000000001', '20000016-0000-4000-8000-000000000003', 0, 'working');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000016-0000-4000-8000-000000003001', 'a0000016-0000-4000-8000-000000000001', 'c0000016-0000-4000-8000-000000000001', 'f0000016-0000-4000-8000-000000000001', 1);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000016-0000-4000-8000-000000000001', 'a0000016-0000-4000-8000-000000000001', 'c0000016-0000-4000-8000-000000000001', '60000016-0000-4000-8000-000000003001', '50000016-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000016-0000-4000-8000-000000000001', '70000016-0000-4000-8000-000000000001', 0, 100, 5);
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values ('60000016-0000-4000-8000-000000003002', 'a0000016-0000-4000-8000-000000000001', 'c0000016-0000-4000-8000-000000000001', 'f0000016-0000-4000-8000-000000000001', 2);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values ('70000016-0000-4000-8000-000000000002', 'a0000016-0000-4000-8000-000000000001', 'c0000016-0000-4000-8000-000000000001', '60000016-0000-4000-8000-000000003002', '50000016-0000-4000-8000-000000000001', 0, null, null);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values ('a0000016-0000-4000-8000-000000000001', '70000016-0000-4000-8000-000000000002', 0, 102.5, 5);

select tests.login('a0000001-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000001-0000-4000-8000-000000000001', 1) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[]'::jsonb,
  'settimana 1: nessun riferimento');

select tests.login('a0000002-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000002-0000-4000-8000-000000000001', 2) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[{"block_id":"30000002-0000-4000-8000-000000000001","set_idx":0,"week":1,"segments":[{"load_kg":100,"reps":5}],"effort":{"value":1,"scale":"BUF"}},{"block_id":"30000002-0000-4000-8000-000000000001","set_idx":1,"week":1,"segments":[{"load_kg":100,"reps":4}],"effort":{"value":0.5,"scale":"BUF"}}]'::jsonb,
  'settimana 2: la stessa serie della settimana 1, con lo sforzo');

select tests.login('a0000003-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000003-0000-4000-8000-000000000001', 2) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[{"block_id":"30000003-0000-4000-8000-000000000001","set_idx":0,"week":1,"segments":[{"load_kg":80,"reps":10}],"effort":null}]'::jsonb,
  'serie senza sforzo: il riferimento c''è, lo sforzo no');

select tests.login('a0000004-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000004-0000-4000-8000-000000000001', 3) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[{"block_id":"30000004-0000-4000-8000-000000000001","set_idx":0,"week":2,"segments":[{"load_kg":100,"reps":8},{"load_kg":75,"reps":6}],"effort":{"value":0,"scale":"BUF"}}]'::jsonb,
  'drop set: i segmenti restano nell''ordine registrato');

select tests.login('a0000005-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000005-0000-4000-8000-000000000001', 2) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[{"block_id":"30000005-0000-4000-8000-000000000001","set_idx":0,"week":1,"segments":[{"load_kg":120,"reps":3}],"effort":{"value":8.5,"scale":"RPE"}}]'::jsonb,
  'lo sforzo resta nella scala in cui è stato inserito (RPE)');

select tests.login('a0000006-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000006-0000-4000-8000-000000000001', 2) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[{"block_id":"30000006-0000-4000-8000-000000000001","set_idx":0,"week":1,"segments":[{"load_kg":100,"reps":5}],"effort":null},{"block_id":"30000006-0000-4000-8000-000000000002","set_idx":0,"week":1,"segments":[{"load_kg":90,"reps":7}],"effort":null},{"block_id":"30000006-0000-4000-8000-000000000002","set_idx":1,"week":1,"segments":[{"load_kg":90,"reps":6}],"effort":null}]'::jsonb,
  'ogni blocco ha il suo riferimento (multiset)');

select tests.login('a0000007-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000007-0000-4000-8000-000000000001', 2) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[{"block_id":"30000007-0000-4000-8000-000000000001","set_idx":0,"week":1,"segments":[{"load_kg":100,"reps":5}],"effort":null},{"block_id":"30000007-0000-4000-8000-000000000001","set_idx":2,"week":1,"segments":[{"load_kg":95,"reps":6}],"effort":null}]'::jsonb,
  'solo le serie registrate: gli indici saltati non hanno riferimento');

select tests.login('a0000008-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000008-0000-4000-8000-000000000001', 2) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[{"block_id":"30000008-0000-4000-8000-000000000001","set_idx":0,"week":1,"segments":[],"effort":{"value":2,"scale":"BUF"}}]'::jsonb,
  'serie con il solo sforzo (nessun carico): il riferimento c''è');

select tests.login('a0000009-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000009-0000-4000-8000-000000000001', 3) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[]'::jsonb,
  'seduta saltata in N−1: nessun riferimento, non si risale alle settimane prima');

select tests.login('a0000010-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000010-0000-4000-8000-000000000001', 2) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[{"block_id":"30000010-0000-4000-8000-000000000001","set_idx":0,"week":1,"segments":[{"load_kg":100,"reps":5}],"effort":null}]'::jsonb,
  'la settimana richiesta ha già dati propri: il riferimento resta N−1');

select tests.login('a0000011-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000011-0000-4000-8000-000000000001', 4) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[{"block_id":"30000011-0000-4000-8000-000000000001","set_idx":0,"week":2,"segments":[{"load_kg":105,"reps":5}],"effort":{"value":1,"scale":"BUF"}}]'::jsonb,
  'scarico a metà: la settimana di scarico è esclusa dalla ricerca, si usa quella prima');

select tests.login('a0000012-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000012-0000-4000-8000-000000000001', 4) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[]'::jsonb,
  'scarico a metà e seduta saltata prima dello scarico: nessun riferimento');

select tests.login('a0000013-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000013-0000-4000-8000-000000000001', 5) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[{"block_id":"30000013-0000-4000-8000-000000000001","set_idx":0,"week":2,"segments":[{"load_kg":105,"reps":5}],"effort":null}]'::jsonb,
  'due scarichi di fila: si salta anche il secondo');

select tests.login('a0000014-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000014-0000-4000-8000-000000000001', 2) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[]'::jsonb,
  'tutte le settimane prima sono di scarico: nessun riferimento');

select tests.login('a0000015-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000015-0000-4000-8000-000000000001', 2) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[]'::jsonb,
  'un''altra seduta nella stessa settimana non conta');

select tests.login('a0000016-0000-4000-8000-000000000001');
select is(
  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,
           'segments', r.segments,
           'effort', case when r.effort_value is null then null
                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)
         order by r.n), '[]'::jsonb)
   from public.previous_week_reference('d0000016-0000-4000-8000-000000000001', 2) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),
  '[]'::jsonb,
  'mai dati di un mesociclo precedente, nemmeno come ripiego');

select * from finish();
rollback;
