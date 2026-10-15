-- weekly_muscle_volume: prescritto ed eseguito per muscolo, esclusioni e permessi.
-- c = coach collegato ad a, x = coach di b. Mesociclo 01 (a): 3 settimane. Esercizio e1 = petto 1,0 +
-- tricipiti 0,5; e2 = solo petto 1,0.
-- Blocchi di a: 51 lavoro su e1 (sett. 1: 3 serie, 2: 4 serie, 4: 9 serie = fuori mesociclo),
-- 52 riscaldamento su e1 (sett. 1: 2 serie), 53 lavoro su e2 (sett. 1: 2 serie), 54 lavoro su e2
-- eliminato (sett. 1: 7 serie). Seduta eseguita in settimana 1: 2 serie sul blocco 51, 1 sul 52.

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
  ('e0000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000c1', 'Panca'),
  ('e0000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000c1', 'Croci');
insert into public.exercise_muscles (exercise_id, muscle, weight) values
  ('e0000000-0000-0000-0000-0000000000e1', 'chest', 1),
  ('e0000000-0000-0000-0000-0000000000e1', 'triceps', 0.5),
  ('e0000000-0000-0000-0000-0000000000e2', 'chest', 1);
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, status) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'A', '2026-10-05', 3, 'active');
insert into public.sessions (id, mesocycle_id, position, name) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 0, 'A');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 0, 'e0000000-0000-0000-0000-0000000000e1'),
  ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 1, 'e0000000-0000-0000-0000-0000000000e2');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role, deleted_at) values
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 0, 'working', null),
  ('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 1, 'warmup', null),
  ('50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000002', 0, 'working', null),
  ('50000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000002', 1, 'working', now());
insert into public.block_weeks (mesocycle_id, block_id, week, sets) values
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 1, 3),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 2, 4),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 4, 9),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', 1, 2),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 1, 2),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000004', 1, 7);
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values
  ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 1);
insert into public.set_logs (athlete_id, mesocycle_id, workout_id, block_id, set_idx) values
  ('00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 0),
  ('00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 1),
  ('00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', 0);

create schema tests;
grant usage on schema tests to authenticated;
create function tests.login(uid uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
grant execute on all functions in schema tests to authenticated;

-- coach collegato: settimana 1 petto = 3 (blocco 51) + 2 (blocco 53) = 5 serie; riscaldamento ed
-- eliminati esclusi; tricipiti = 3 × 0,5. Settimana 2 solo e1. Settimana 4 è fuori dal mesociclo.
select tests.login('00000000-0000-0000-0000-0000000000c1');
select results_eq(
  $$select week::int, muscle::text, prescribed::float8, executed::float8
    from public.weekly_muscle_volume('10000000-0000-0000-0000-000000000001')$$,
  $$values (1, 'chest', 5::float8, 2::float8), (1, 'triceps', 1.5::float8, 1::float8),
           (2, 'chest', 4::float8, 0::float8), (2, 'triceps', 2::float8, 0::float8)$$,
  'prescritto ed eseguito per muscolo e settimana, senza riscaldamento, eliminati e settimane fuori');

-- atleta proprietario: vede lo stesso volume del suo mesociclo
select tests.login('00000000-0000-0000-0000-0000000000a1');
select is(
  (select count(*)::int from public.weekly_muscle_volume('10000000-0000-0000-0000-000000000001')),
  4, 'l''atleta proprietario vede il volume del suo mesociclo');

-- coach non collegato e altro atleta: nessuna riga
select tests.login('00000000-0000-0000-0000-0000000000c2');
select is(
  (select count(*)::int from public.weekly_muscle_volume('10000000-0000-0000-0000-000000000001')),
  0, 'un coach non collegato non vede nulla');
select tests.login('00000000-0000-0000-0000-0000000000b1');
select is(
  (select count(*)::int from public.weekly_muscle_volume('10000000-0000-0000-0000-000000000001')),
  0, 'un altro atleta non vede nulla');

select * from finish();
rollback;
