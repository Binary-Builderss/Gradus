-- Macro: obiettivi del coach (nutrition_plans / nutrition_plan_days), aderenza dell'atleta (nutrition_days),
-- consenso e dieta ancora non disponibile.
-- c1 = coach collegato ad a1, c2 = altro coach con b1, c3 = secondo coach collegato ad a1, a1 e b1 = atleti.

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c1@test.dev'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@test.dev'),
  ('00000000-0000-0000-0000-0000000000c3', 'c3@test.dev'),
  ('00000000-0000-0000-0000-0000000000a1', 'a1@test.dev'),
  ('00000000-0000-0000-0000-0000000000b1', 'b1@test.dev');
insert into public.coach_athletes (coach_id, athlete_id, status) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'active'),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000a1', 'active'),
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

-- ---------------------------------------------------------------------------
-- Obiettivi
-- ---------------------------------------------------------------------------
select tests.login('00000000-0000-0000-0000-0000000000c1');
select lives_ok(
  $$insert into public.nutrition_plans (id, athlete_id, author_id, valid_from, tolerance_pct, declared_at, declaration_version)
    values ('90000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000c1', '2026-10-01', 10, now(), '2026-10-16')$$,
  'il coach collegato scrive un piano a suo nome');
select lives_ok(
  $$insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g, fiber_g)
    values ('90000000-0000-0000-0000-000000000001', 2500, 180, 280, 70, 30)$$,
  'e il suo obiettivo giornaliero');
select throws_ok(
  $$insert into public.nutrition_plans (athlete_id, author_id, valid_from, declared_at, declaration_version)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c2', '2026-11-01', now(), 'v1')$$,
  '42501', null, 'non si scrive a nome di un altro');
select throws_ok(
  $$insert into public.nutrition_plans (athlete_id, author_id, valid_from, declared_at, declaration_version)
    values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000c1', '2026-11-01', now(), 'v1')$$,
  '42501', null, 'né per un atleta non collegato');
select throws_ok(
  $$insert into public.nutrition_plans (athlete_id, author_id, valid_from, declared_at, declaration_version)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', '2026-10-01', now(), 'v1')$$,
  '23505', null, 'un solo piano per atleta e giorno di inizio');
select throws_ok(
  $$insert into public.nutrition_plans (athlete_id, author_id, valid_from, declared_at, declaration_version)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', '2026-11-01', null, 'v1')$$,
  '23502', null, 'la dichiarazione è obbligatoria');
select throws_ok(
  $$insert into public.nutrition_plans (athlete_id, author_id, valid_from, declared_at, declaration_version)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', '2026-11-01', now(), '  ')$$,
  '23514', null, 'e la versione del testo non è vuota');
select throws_ok(
  $$insert into public.nutrition_plans (athlete_id, author_id, kind, valid_from, declared_at, declaration_version)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', 'diet', '2026-11-01', now(), 'v1')$$,
  'P0001', 'diet_requires_verified_professional', 'la dieta compilabile non è ancora disponibile');
select throws_ok(
  $$insert into public.nutrition_plan_days (plan_id, day_type, kcal, protein_g, carbs_g, fat_g)
    values ('90000000-0000-0000-0000-000000000001', 'training', 2800, 180, 330, 80)$$,
  '23514', null, 'oggi un solo obiettivo per giorno');
select throws_ok(
  $$insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g)
    values ('90000000-0000-0000-0000-000000000001', 100, 180, 280, 70)$$,
  '23514', null, 'calorie assurde sono rifiutate');
select lives_ok(
  $$update public.nutrition_plans set tolerance_pct = 8 where id = '90000000-0000-0000-0000-000000000001'$$,
  'l''autore modifica il suo piano');

-- altro coach collegato allo stesso atleta: legge, non scrive; coach non collegato: niente
select tests.login('00000000-0000-0000-0000-0000000000c3');
select is((select count(*)::int from public.nutrition_plans), 1, 'il secondo coach dell''atleta vede il piano');
select is(
  tests.rows_affected($$update public.nutrition_plans set tolerance_pct = 20$$), 0, 'ma non lo modifica: un solo autore');
select is(
  tests.rows_affected($$update public.nutrition_plan_days set kcal = 3000$$), 0, 'né i suoi obiettivi');
select tests.login('00000000-0000-0000-0000-0000000000c2');
select is((select count(*)::int from public.nutrition_plans), 0, 'un coach non collegato non vede il piano');
select is((select count(*)::int from public.nutrition_plan_days), 0, 'né gli obiettivi');
select throws_ok(
  $$insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g)
    values ('90000000-0000-0000-0000-000000000001', 2000, 150, 200, 60)$$,
  '42501', null, 'né aggiunge obiettivi a un piano non suo');

-- atleta: vede il suo piano, non quello degli altri, non lo scrive
select tests.login('00000000-0000-0000-0000-0000000000a1');
select is((select count(*)::int from public.nutrition_plans), 1, 'l''atleta vede il suo piano');
select is((select count(*)::int from public.nutrition_plan_days), 1, 'e i suoi obiettivi');
select throws_ok(
  $$insert into public.nutrition_plans (athlete_id, author_id, valid_from, declared_at, declaration_version)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a1', '2026-11-01', now(), 'v1')$$,
  '42501', null, 'l''atleta non scrive i propri obiettivi');
select tests.login('00000000-0000-0000-0000-0000000000b1');
select is((select count(*)::int from public.nutrition_plans), 0, 'un altro atleta non vede il piano');

-- ---------------------------------------------------------------------------
-- Aderenza e consenso
-- ---------------------------------------------------------------------------
select tests.login('00000000-0000-0000-0000-0000000000a1');
select throws_ok(
  $$insert into public.nutrition_days (athlete_id, day, status, source)
    values ('00000000-0000-0000-0000-0000000000a1', '2026-10-10', 'respected', 'confirm')$$,
  '42501', null, 'senza consenso l''atleta non registra nulla');
select lives_ok(
  $$update public.profiles set nutrition_consent_at = now(), nutrition_consent_version = '2026-10-16'
    where id = '00000000-0000-0000-0000-0000000000a1'$$,
  'l''atleta dà il consenso sul proprio profilo');
select lives_ok(
  $$insert into public.nutrition_days (athlete_id, day, status, source)
    values ('00000000-0000-0000-0000-0000000000a1', '2026-10-10', 'respected', 'confirm')$$,
  'una conferma senza numeri è un giorno verde');
select lives_ok(
  $$insert into public.nutrition_days (athlete_id, day, status, source, kcal, protein_g, carbs_g, fat_g)
    values ('00000000-0000-0000-0000-0000000000a1', '2026-10-11', 'not_respected', 'manual', 3100.5, 150, 400, 95.5)$$,
  'un giorno non rispettato con i numeri inseriti a mano');
select throws_ok(
  $$insert into public.nutrition_days (athlete_id, day, status, source)
    values ('00000000-0000-0000-0000-0000000000a1', '2026-10-12', 'respected', 'manual')$$,
  '23514', null, 'da Apple Salute o a mano servono dei numeri');
select throws_ok(
  $$insert into public.nutrition_days (athlete_id, day, status, source)
    values ('00000000-0000-0000-0000-0000000000a1', '2026-10-10', 'respected', 'confirm')$$,
  '23505', null, 'un solo giorno per atleta e data: si corregge, non si duplica');
select lives_ok(
  $$update public.nutrition_days set status = 'respected', source = 'manual' where day = '2026-10-11'$$,
  'si può correggere un giorno');
select throws_ok(
  $$insert into public.nutrition_days (athlete_id, day, status, source)
    values ('00000000-0000-0000-0000-0000000000b1', '2026-10-13', 'respected', 'confirm')$$,
  '42501', null, 'l''atleta non scrive per un altro');

-- il coach legge solo con il consenso
select tests.login('00000000-0000-0000-0000-0000000000c1');
select is((select count(*)::int from public.nutrition_days), 2, 'con il consenso il coach collegato vede i giorni');
select is(
  tests.rows_affected($$update public.nutrition_days set status = 'not_respected'$$), 0, 'ma non li modifica: li scrive l''atleta');
select throws_ok(
  $$insert into public.nutrition_days (athlete_id, day, status, source)
    values ('00000000-0000-0000-0000-0000000000a1', '2026-10-14', 'respected', 'confirm')$$,
  '42501', null, 'né li inserisce');
select tests.login('00000000-0000-0000-0000-0000000000c2');
select is((select count(*)::int from public.nutrition_days), 0, 'un coach non collegato non vede i giorni');
select tests.login('00000000-0000-0000-0000-0000000000b1');
select is((select count(*)::int from public.nutrition_days), 0, 'un altro atleta nemmeno');

-- ---------------------------------------------------------------------------
-- Obiettivo in vigore e panoramica
-- ---------------------------------------------------------------------------
select tests.login('00000000-0000-0000-0000-0000000000c1');
select lives_ok(
  $$insert into public.nutrition_plans (id, athlete_id, author_id, valid_from, declared_at, declaration_version)
    values ('90000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1',
            '00000000-0000-0000-0000-0000000000c1', '2026-10-11', now(), '2026-10-16')$$,
  'un piano più recente');
select lives_ok(
  $$insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g)
    values ('90000000-0000-0000-0000-000000000002', 2200, 190, 220, 60)$$,
  'con i suoi obiettivi');
select is(
  (select kcal from public.nutrition_target_on('00000000-0000-0000-0000-0000000000a1', '2026-10-10')),
  2500, 'il 10 vale ancora il primo piano');
select is(
  (select kcal from public.nutrition_target_on('00000000-0000-0000-0000-0000000000a1', '2026-10-11')),
  2200, 'dall''11 vale quello nuovo');
select is(
  (select count(*)::int from public.nutrition_target_on('00000000-0000-0000-0000-0000000000a1', '2026-09-01')),
  0, 'prima del primo piano non c''è un obiettivo');
select results_eq(
  $$select day::text, status::text, source::text, kcal, target_kcal, tolerance_pct
      from public.nutrition_overview('00000000-0000-0000-0000-0000000000a1', '2026-10-09', '2026-10-12') order by day$$,
  $$values ('2026-10-09', null::text, null::text, null::numeric, 2500, 8::smallint),
           ('2026-10-10', 'respected', 'confirm', null, 2500, 8::smallint),
           ('2026-10-11', 'respected', 'manual', 3100.5, 2200, 10::smallint),
           ('2026-10-12', null, null, null, 2200, 10::smallint)$$,
  'la panoramica: un giorno per riga, con obiettivo e registrato (vuoto = non registrato)');
select is(
  (select count(*)::int from public.nutrition_overview('00000000-0000-0000-0000-0000000000a1', '2026-01-01', '2030-01-01')),
  367, 'la panoramica è limitata a un anno');

-- un piano eliminato non vale più, e il suo giorno di inizio si può riusare
select lives_ok(
  $$update public.nutrition_plans set deleted_at = now() where id = '90000000-0000-0000-0000-000000000002'$$,
  'il coach ritira un piano');
select is(
  (select kcal from public.nutrition_target_on('00000000-0000-0000-0000-0000000000a1', '2026-10-11')),
  2500, 'torna in vigore il precedente');
select lives_ok(
  $$insert into public.nutrition_plans (athlete_id, author_id, valid_from, declared_at, declaration_version)
    values ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000c1', '2026-10-11', now(), 'v1')$$,
  'il giorno di inizio di un piano eliminato si riusa');

-- ---------------------------------------------------------------------------
-- Ritirare il consenso
-- ---------------------------------------------------------------------------
select tests.login('00000000-0000-0000-0000-0000000000a1');
select lives_ok($$select public.withdraw_nutrition_consent()$$, 'l''atleta ritira il consenso');
select is((select count(*)::int from public.nutrition_days), 0, 'i giorni registrati sono cancellati');
select is(
  (select nutrition_consent_at from public.profiles where id = '00000000-0000-0000-0000-0000000000a1'), null,
  'e il consenso è azzerato');
select throws_ok(
  $$insert into public.nutrition_days (athlete_id, day, status, source)
    values ('00000000-0000-0000-0000-0000000000a1', '2026-10-15', 'respected', 'confirm')$$,
  '42501', null, 'senza consenso non si scrive più');
select tests.login('00000000-0000-0000-0000-0000000000c1');
select is((select count(*)::int from public.nutrition_days), 0, 'il coach non vede più nulla');
select is((select count(*)::int from public.nutrition_plans), 3, 'gli obiettivi restano: sono del coach');

-- niente anonimi, niente cancellazioni fisiche
reset role;
select throws_ok($$set local role anon; select * from public.nutrition_plans$$, '42501', null, 'gli anonimi non leggono');
reset role;
select tests.login('00000000-0000-0000-0000-0000000000c1');
select throws_ok(
  $$delete from public.nutrition_plans where id = '90000000-0000-0000-0000-000000000001'$$, '42501', null,
  'i piani non si cancellano dal client (si ritirano)');

select * from finish();
rollback;
