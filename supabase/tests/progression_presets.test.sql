-- progression_presets: modelli di progressione del coach. c1 = coach proprietario (collegato ad a1), c2 = altro coach,
-- a1 = atleta di c1, b1 = atleta di c2.

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c1@test.dev'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@test.dev'),
  ('00000000-0000-0000-0000-0000000000a1', 'a1@test.dev'),
  ('00000000-0000-0000-0000-0000000000b1', 'b1@test.dev');
insert into public.coach_athletes (coach_id, athlete_id, status) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'active'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000b1', 'active');

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
grant execute on all functions in schema tests to authenticated;

-- la regola: forme valide e non valide
select ok(private.valid_progression_rule('{"sets": {"start": 3}}'), 'solo le serie');
select ok(private.valid_progression_rule($${
  "sets": {"start": 3, "step": 1, "max": 5},
  "reps_min": {"start": 8}, "reps_max": {"start": 10},
  "method": "BUF", "intensity": {"start": 3, "step": -1, "min": 0},
  "from_week": 2, "to_week": 6}$$::jsonb), 'regola completa (come la scrive il web)');
select ok(not private.valid_progression_rule('{}'), 'senza serie no');
select ok(not private.valid_progression_rule('[]'), 'non è un oggetto');
select ok(not private.valid_progression_rule('{"sets": {"step": 1}}'), 'una serie parte sempre da start');
select ok(not private.valid_progression_rule('{"sets": {"start": "3"}}'), 'i valori sono numeri');
select ok(not private.valid_progression_rule('{"sets": {"start": 3, "colore": 1}}'), 'niente chiavi sconosciute nella serie');
select ok(not private.valid_progression_rule('{"sets": {"start": 3}, "altro": 1}'), 'niente chiavi sconosciute nella regola');
select ok(not private.valid_progression_rule('{"sets": {"start": 3}, "method": "BUF"}'), 'metodo senza valore no');
select ok(not private.valid_progression_rule('{"sets": {"start": 3}, "intensity": {"start": 2}}'), 'valore senza metodo no');
select ok(not private.valid_progression_rule('{"sets": {"start": 3}, "method": "XYZ", "intensity": {"start": 2}}'), 'metodo sconosciuto no');
select ok(not private.valid_progression_rule('{"sets": {"start": 3}, "from_week": 0}'), 'settimana da 1');
select ok(not private.valid_progression_rule('{"sets": {"start": 3}, "to_week": 53}'), 'settimana fino a 52');
select ok(not private.valid_progression_rule('{"sets": {"start": 3}, "from_week": 5, "to_week": 2}'), 'intervallo invertito no');
select ok(not private.valid_progression_rule('{"sets": {"start": 3}, "from_week": 1.5}'), 'settimana intera');
select ok(not private.valid_progression_rule('{"sets": {"start": 3}, "from_week": "2"}'), 'settimana numerica');

-- coach proprietario
select tests.login('00000000-0000-0000-0000-0000000000c1');
select lives_ok($$
  insert into public.progression_presets (owner_id, name, rule) values
    ('00000000-0000-0000-0000-0000000000c1', 'Sforzo che sale', '{"sets": {"start": 3}, "method": "BUF", "intensity": {"start": 3, "step": -1, "min": 0}}') $$,
  'il coach salva un modello');
select throws_ok($$
  insert into public.progression_presets (owner_id, name, rule) values
    ('00000000-0000-0000-0000-0000000000c1', 'Sforzo che sale', '{"sets": {"start": 4}}') $$,
  '23505', null, 'il nome è unico per coach');
select throws_ok($$
  insert into public.progression_presets (owner_id, name, rule) values
    ('00000000-0000-0000-0000-0000000000c1', 'Rotto', '{"method": "BUF"}') $$,
  '23514', null, 'una regola non valida non si salva');
select throws_ok($$
  insert into public.progression_presets (owner_id, name, rule) values
    ('00000000-0000-0000-0000-0000000000c1', '  ', '{"sets": {"start": 3}}') $$,
  '23514', null, 'il nome non è vuoto');
select throws_ok($$
  insert into public.progression_presets (owner_id, name, rule) values
    ('00000000-0000-0000-0000-0000000000c2', 'A nome di un altro', '{"sets": {"start": 3}}') $$,
  '42501', null, 'non si salva a nome di un altro coach');
select is((select count(*)::int from public.progression_presets), 1, 'il coach vede i propri modelli');
select is(tests.rows_affected($$
  update public.progression_presets set name = 'Sforzo crescente' where name = 'Sforzo che sale' $$),
  1, 'il coach rinomina un suo modello');

-- atleta di c1
select tests.login('00000000-0000-0000-0000-0000000000a1');
select is((select count(*)::int from public.progression_presets), 0, 'l''atleta non vede i modelli del suo coach');
select is(tests.rows_affected($$ delete from public.progression_presets $$), 0, 'l''atleta non elimina');
select lives_ok($$
  insert into public.progression_presets (owner_id, name, rule) values
    ('00000000-0000-0000-0000-0000000000a1', 'Mio', '{"sets": {"start": 3}}') $$,
  'ognuno salva nel proprio spazio');
select is((select count(*)::int from public.progression_presets), 1, 'e vede solo i propri');

-- coach non collegato
select tests.login('00000000-0000-0000-0000-0000000000c2');
select is((select count(*)::int from public.progression_presets), 0, 'un altro coach non vede i modelli di c1 né di a1');
select is(tests.rows_affected($$ update public.progression_presets set name = 'x' $$), 0, 'un altro coach non modifica');
select is(tests.rows_affected($$ delete from public.progression_presets $$), 0, 'un altro coach non elimina');
select lives_ok($$
  insert into public.progression_presets (owner_id, name, rule) values
    ('00000000-0000-0000-0000-0000000000c2', 'Sforzo crescente', '{"sets": {"start": 3}}') $$,
  'lo stesso nome è libero per un altro coach');

-- il coach proprietario elimina il suo
select tests.login('00000000-0000-0000-0000-0000000000c1');
select is((select count(*)::int from public.progression_presets), 1, 'c1 vede solo il proprio');
select is(tests.rows_affected($$ delete from public.progression_presets where name = 'Sforzo crescente' $$),
  1, 'il coach elimina un suo modello');

-- anonimo
select set_config('role', 'anon', true);
select throws_ok($$ select * from public.progression_presets $$, '42501', null, 'l''anonimo non legge');

select * from finish();
rollback;
