-- prepare_account_deletion + cancellazione dell'utente: cosa resta e cosa se ne va.
-- c = coach con due esercizi propri (e1 usato nel programma di a, e2 mai usato), a = suo atleta con un
-- mesociclo scritto da c e una seduta registrata, l = atleta con un mesociclo e una seduta suoi.

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c@test.dev'),
  ('00000000-0000-0000-0000-0000000000a1', 'a@test.dev'),
  ('00000000-0000-0000-0000-0000000000b1', 'l@test.dev');
insert into public.coach_athletes (coach_id, athlete_id, status) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'active'),
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000b1', 'active');
insert into public.coach_plans (coach_id, plan) values ('00000000-0000-0000-0000-0000000000c1', 'pro');
insert into public.coach_branding (coach_id, brand_name) values ('00000000-0000-0000-0000-0000000000c1', 'Studio');
insert into public.exercises (id, owner_id, name) values
  ('e0000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000c1', 'Usato'),
  ('e0000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000c1', 'Mai usato');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, status) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'di a', '2026-10-05', 4, 'active'),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000b1', 'di l', '2026-10-05', 4, 'active');
insert into public.sessions (id, mesocycle_id, position, name) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 0, 'A'),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 0, 'B');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 0, 'e0000000-0000-0000-0000-0000000000e1');
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values
  ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 1),
  ('70000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000b1', '10000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000002', 1);

create schema tests;
grant usage on schema tests to authenticated;
create function tests.login(uid uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
grant execute on all functions in schema tests to authenticated;

-- un client non può lanciare la preparazione, nemmeno sul proprio account
select tests.login('00000000-0000-0000-0000-0000000000c1');
select throws_ok(
  $$select public.prepare_account_deletion('00000000-0000-0000-0000-0000000000c1')$$,
  '42501', null, 'solo la Edge Function (service_role) può preparare la cancellazione');
select set_config('role', 'postgres', true);

-- cancellazione del coach
select public.prepare_account_deletion('00000000-0000-0000-0000-0000000000c1');
delete from auth.users where id = '00000000-0000-0000-0000-0000000000c1';

select is((select count(*)::int from public.profiles where id = '00000000-0000-0000-0000-0000000000c1'), 0, 'il profilo del coach non c''è più');
select is((select count(*)::int from public.coach_plans), 0, 'piano cancellato');
select is((select count(*)::int from public.coach_branding), 0, 'marchio cancellato');
select is((select count(*)::int from public.coach_athletes), 0, 'i collegamenti del coach non ci sono più');
select is((select count(*)::int from public.exercises where id = 'e0000000-0000-0000-0000-0000000000e2'), 0, 'l''esercizio mai usato è cancellato');
select results_eq(
  $$select owner_id is null, deleted_at is not null from public.exercises where id = 'e0000000-0000-0000-0000-0000000000e1'$$,
  $$values (true, true)$$, 'l''esercizio usato resta, ritirato e senza proprietario');
select is((select count(*)::int from public.slots where exercise_id = 'e0000000-0000-0000-0000-0000000000e1'), 1, 'il programma di a continua a usarlo');
select is((select count(*)::int from public.mesocycles), 2, 'i mesocicli degli atleti restano');
select is((select count(*)::int from public.workouts), 2, 'le sedute degli atleti restano');

-- cancellazione di un atleta: sedute e mesocicli suoi se ne vanno
select public.prepare_account_deletion('00000000-0000-0000-0000-0000000000b1');
delete from auth.users where id = '00000000-0000-0000-0000-0000000000b1';
select is((select count(*)::int from public.workouts where athlete_id = '00000000-0000-0000-0000-0000000000b1'), 0, 'sedute dell''atleta cancellate');
select is((select count(*)::int from public.mesocycles where athlete_id = '00000000-0000-0000-0000-0000000000b1'), 0, 'mesocicli dell''atleta cancellati');
select is((select count(*)::int from public.mesocycles where athlete_id = '00000000-0000-0000-0000-0000000000a1'), 1, 'quelli di un altro atleta restano');

select * from finish();
rollback;
