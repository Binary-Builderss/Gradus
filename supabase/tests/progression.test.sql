-- generate_progression: valori per settimana, scarichi, settimane eseguite, permessi e regole non valide.
-- c = coach collegato ad a (active), x = coach di b. Mesociclo 01 = a, 6 settimane, scarico alla 4,
-- con una seduta registrata in settimana 2. Blocchi: 51 = top di a, 53 = di b.

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
  ('e0000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000c1', 'Panca di c'),
  ('e0000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000c2', 'Panca di x');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'A', '2026-10-05', 6, '{4}', 'active'),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000b1', 'B', '2026-10-05', 6, '{}', 'active');
insert into public.sessions (id, mesocycle_id, position, name) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 0, 'A'),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 0, 'A');
insert into public.slot_groups (id, mesocycle_id, session_id, position) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 0),
  ('30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000003', 0);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 0, 'e0000000-0000-0000-0000-0000000000c1'),
  ('40000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000003', 0, 'e0000000-0000-0000-0000-0000000000c2');
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 0, 'working'),
  ('50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000003', 0, 'working');
-- settimana 2 di a già eseguita: dati reali, quindi esiste la seduta
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values
  ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 2);
-- e una prescrizione preesistente in settimana 2 (eseguita) che non deve cambiare
insert into public.block_weeks (mesocycle_id, block_id, week, sets, reps_min, reps_max, method, intensity_value) values
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 2, 9, 9, 9, 'RPE', 9);

create schema tests;
grant usage on schema tests to authenticated;
create function tests.login(uid uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
grant execute on all functions in schema tests to authenticated;

-- BUF da 3 a 0 (-1 a settimana), +1 serie a settimana da 3, fino a 5 serie, 8-10 ripetizioni fisse
select tests.login('00000000-0000-0000-0000-0000000000c1');
select is(
  public.generate_progression('50000000-0000-0000-0000-000000000001', $${
    "sets": {"start": 3, "step": 1, "max": 5},
    "reps_min": {"start": 8}, "reps_max": {"start": 10},
    "method": "BUF", "intensity": {"start": 3, "step": -1, "min": 0}
  }$$),
  4, 'scrive 4 settimane: 6 meno lo scarico (4) e la settimana eseguita (2)');

select results_eq(
  $$ select week::int, sets::int, reps_min::int, reps_max::int, method::text, intensity_value::int
     from public.block_weeks where block_id = '50000000-0000-0000-0000-000000000001' order by week $$,
  $$ values
    (1, 3, 8, 10, 'BUF', 3),
    (2, 9, 9, 9, 'RPE', 9),
    (3, 5, 8, 10, 'BUF', 1),
    (5, 5, 8, 10, 'BUF', 0),
    (6, 5, 8, 10, 'BUF', 0) $$,
  'settimana 1 = start; la 2 (eseguita) intatta ma conta come passo; lo scarico non scritto e non conta; max e min rispettati');

-- rigenerare è idempotente
select is(
  public.generate_progression('50000000-0000-0000-0000-000000000001', '{"sets": {"start": 3}, "from_week": 5, "to_week": 6}'),
  2, 'sotto-intervallo: due settimane');
select results_eq(
  $$ select week::int, sets::int, method::text from public.block_weeks
     where block_id = '50000000-0000-0000-0000-000000000001' and week >= 5 order by week $$,
  $$ values (5, 3, null::text), (6, 3, null::text) $$,
  'sovrascrive e toglie metodo e intensità se la regola non li dà');

-- una settimana cancellata (deleted_at) torna in vita
update public.block_weeks set deleted_at = now()
 where block_id = '50000000-0000-0000-0000-000000000001' and week = 1;
select public.generate_progression('50000000-0000-0000-0000-000000000001', '{"sets": {"start": 4}, "from_week": 1, "to_week": 1}');
select is(
  (select sets::int from public.block_weeks
    where block_id = '50000000-0000-0000-0000-000000000001' and week = 1 and deleted_at is null),
  4, 'una riga eliminata logicamente viene riscritta');

-- anteprima: stesso calcolo, senza scrivere. Mesociclo a 6 settimane, scarico alla 4, settimana 2 eseguita
select tests.login('00000000-0000-0000-0000-0000000000c1');
select results_eq(
  $$ select week, action, sets, reps_min::int, reps_max::int, method::text, intensity_value::int
     from public.preview_progression('50000000-0000-0000-0000-000000000001',
       '{"sets": {"start": 3, "step": 1, "max": 5}, "reps_min": {"start": 8}, "reps_max": {"start": 10},
         "method": "BUF", "intensity": {"start": 3, "step": -1, "min": 0}}') order by week $$,
  $$ values
    (1, 'write', 3, 8, 10, 'BUF', 3),
    (2, 'locked', 4, 8, 10, 'BUF', 2),
    (3, 'write', 5, 8, 10, 'BUF', 1),
    (4, 'deload', null::int, null::int, null::int, null::text, null::int),
    (5, 'write', 5, 8, 10, 'BUF', 0),
    (6, 'write', 5, 8, 10, 'BUF', 0) $$,
  'anteprima: scritte, eseguita (intatta ma conta come passo), scarico (saltato) e valori con max e min');
select is(
  (select count(*)::int from public.block_weeks where block_id = '50000000-0000-0000-0000-000000000001' and week = 3 and sets = 5 and deleted_at is null),
  1, 'l''anteprima non scrive: la settimana 3 è ancora quella di prima della prova');
select throws_ok(
  $$ select * from public.preview_progression('50000000-0000-0000-0000-000000000001', '{"sets": {"start": 3}, "reps_min": {"start": 10}, "reps_max": {"start": 8}}') $$,
  '23514', null, 'anteprima: ripetizioni minime oltre le massime');

-- regole non valide
select throws_ok($$ select public.generate_progression('50000000-0000-0000-0000-000000000001', '{}') $$,
  '22023', null, 'senza sets');
select throws_ok($$ select public.generate_progression('50000000-0000-0000-0000-000000000001', '{"sets": {"start": 3}, "method": "BUF"}') $$,
  '22023', null, 'metodo senza intensità');
select throws_ok($$ select public.generate_progression('50000000-0000-0000-0000-000000000001', '{"sets": {"start": 3}, "to_week": 7}') $$,
  '22023', null, 'oltre le settimane del mesociclo');
select throws_ok($$ select public.generate_progression('50000000-0000-0000-0000-000000000001', '{"sets": {"start": 3}, "from_week": 4, "to_week": 2}') $$,
  '22023', null, 'intervallo invertito');
select throws_ok($$ select public.generate_progression('50000000-0000-0000-0000-000000000001', '{"sets": {"start": 2.5}}') $$,
  '22023', null, 'serie non intere');
select throws_ok($$ select public.generate_progression('50000000-0000-0000-0000-000000000001', '{"sets": {"start": 3}, "reps_min": {"start": 10}, "reps_max": {"start": 8}}') $$,
  '23514', null, 'ripetizioni minime oltre le massime: vincolo della tabella');

-- permessi
select tests.login('00000000-0000-0000-0000-0000000000c2');
select throws_ok($$ select public.generate_progression('50000000-0000-0000-0000-000000000001', '{"sets": {"start": 3}}') $$,
  'P0002', null, 'coach non collegato: il blocco non esiste');
select tests.login('00000000-0000-0000-0000-0000000000a1');
select throws_ok($$ select public.generate_progression('50000000-0000-0000-0000-000000000001', '{"sets": {"start": 3}}') $$,
  '42501', null, 'atleta proprietario: non può scrivere la programmazione');
select tests.login('00000000-0000-0000-0000-0000000000b1');
select throws_ok($$ select public.generate_progression('50000000-0000-0000-0000-000000000001', '{"sets": {"start": 3}}') $$,
  'P0002', null, 'altro atleta: il blocco non esiste');
select throws_ok($$ select public.generate_progression('00000000-0000-0000-0000-00000000dead', '{"sets": {"start": 3}}') $$,
  'P0002', null, 'blocco inesistente');

select * from finish();
rollback;
