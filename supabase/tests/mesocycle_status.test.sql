-- Ciclo di vita del mesociclo: pubblicazione, conclusione, ritiro, un solo attivo, chi può cosa.
-- c = coach di a; a = atleta; x = altro coach. Mesocicli di a: 01 (con contenuto), 02 (vuoto), 03 (con contenuto).

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c@test.dev'),
  ('00000000-0000-0000-0000-0000000000c2', 'x@test.dev'),
  ('00000000-0000-0000-0000-0000000000a1', 'a@test.dev');
insert into public.coach_athletes (coach_id, athlete_id, status) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'active');
insert into public.exercises (id, owner_id, name) values
  ('e0000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000c1', 'Panca');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'Uno', '2026-10-05', 4),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1', 'Vuoto', '2026-10-05', 4),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a1', 'Tre', '2026-11-05', 4);
insert into public.sessions (id, mesocycle_id, position, name) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 0, 'A'),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 0, 'A'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 0, 'A');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 0),
  ('30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 0, 'e0000000-0000-0000-0000-0000000000e1'),
  ('40000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000003', 0, 'e0000000-0000-0000-0000-0000000000e1');
insert into public.set_blocks (id, mesocycle_id, slot_id, position) values
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 0),
  ('50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000003', 0);
insert into public.block_weeks (mesocycle_id, block_id, week, sets) values
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 1, 3),
  ('10000000-0000-0000-0000-000000000003', '50000000-0000-0000-0000-000000000003', 1, 3);

create schema tests;
grant usage on schema tests to authenticated;
create function tests.login(uid uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
create function tests.rows_affected(q text) returns int language plpgsql as $$
declare n int;
begin
  execute q;
  get diagnostics n = row_count;
  return n;
end;
$$;
create function tests.error_hint(q text) returns text language plpgsql as $$
declare h text;
begin
  execute q;
  return null;
exception when others then
  get stacked diagnostics h = pg_exception_hint;
  return h;
end;
$$;
grant execute on all functions in schema tests to authenticated;

select tests.login('00000000-0000-0000-0000-0000000000c1');

-- pubblicare
select throws_ok(
  $$update public.mesocycles set status = 'active' where id = '10000000-0000-0000-0000-000000000002'$$,
  'P0001', 'mesocycle_empty', 'un mesociclo senza prescrizioni non si attiva');
select lives_ok(
  $$update public.mesocycles set status = 'active' where id = '10000000-0000-0000-0000-000000000001'$$,
  'con una prescrizione si attiva');
select throws_ok(
  $$update public.mesocycles set status = 'active' where id = '10000000-0000-0000-0000-000000000003'$$,
  'P0001', 'athlete_has_active', 'un solo attivo per atleta');
select is(
  tests.error_hint($$update public.mesocycles set status = 'active' where id = '10000000-0000-0000-0000-000000000003'$$),
  'Uno', 'il rifiuto dice quale mesociclo è già attivo');

-- concludere e passare al successivo
select lives_ok(
  $$update public.mesocycles set status = 'completed' where id = '10000000-0000-0000-0000-000000000001'$$,
  'si può concludere un mesociclo attivo');
select lives_ok(
  $$update public.mesocycles set status = 'active' where id = '10000000-0000-0000-0000-000000000003'$$,
  'concluso il primo, il successivo si attiva');
select throws_ok(
  $$update public.mesocycles set status = 'active' where id = '10000000-0000-0000-0000-000000000001'$$,
  'P0001', 'mesocycle_status_change_not_allowed', 'un mesociclo concluso non si riattiva');
select throws_ok(
  $$update public.mesocycles set status = 'draft' where id = '10000000-0000-0000-0000-000000000001'$$,
  'P0001', 'mesocycle_status_change_not_allowed', 'né torna in bozza');
select throws_ok(
  $$update public.mesocycles set status = 'completed' where id = '10000000-0000-0000-0000-000000000002'$$,
  'P0001', 'mesocycle_status_change_not_allowed', 'una bozza non si conclude senza essere stata attiva');

-- ritirare una pubblicazione: solo se l'atleta non ha registrato nulla
select set_config('role', 'postgres', true);
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values
  ('70000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 1);
select tests.login('00000000-0000-0000-0000-0000000000c1');
select throws_ok(
  $$update public.mesocycles set status = 'draft' where id = '10000000-0000-0000-0000-000000000003'$$,
  'P0001', 'mesocycle_has_workouts', 'con sedute registrate non si ritira');
select set_config('role', 'postgres', true);
delete from public.workouts where id = '70000000-0000-0000-0000-000000000003';
select tests.login('00000000-0000-0000-0000-0000000000c1');
select lives_ok(
  $$update public.mesocycles set status = 'draft' where id = '10000000-0000-0000-0000-000000000003'$$,
  'senza sedute registrate si riporta in bozza');

-- chi può cambiare lo stato
select tests.login('00000000-0000-0000-0000-0000000000c2');
select is(
  tests.rows_affected($$update public.mesocycles set status = 'active' where id = '10000000-0000-0000-0000-000000000003'$$),
  0, 'un coach non collegato non cambia lo stato');
select tests.login('00000000-0000-0000-0000-0000000000a1');
select is(
  tests.rows_affected($$update public.mesocycles set status = 'completed' where id = '10000000-0000-0000-0000-000000000001'$$),
  0, 'nemmeno l''atleta');

-- eliminare: solo le bozze, solo dal coach
select tests.login('00000000-0000-0000-0000-0000000000c1');
select is(
  tests.rows_affected($$delete from public.mesocycles where id = '10000000-0000-0000-0000-000000000001'$$),
  0, 'un mesociclo concluso non si elimina');
select is(
  tests.rows_affected($$delete from public.mesocycles where id = '10000000-0000-0000-0000-000000000002'$$),
  1, 'una bozza si elimina');

select * from finish();
rollback;
