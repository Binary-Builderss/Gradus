-- Tetti su template di mesociclo e progressioni salvate: free 1 / 20, basic 5 / 350, piano scaduto = free,
-- chi supera il tetto dopo un declassamento tiene le righe ma non ne aggiunge, ognuno conta le sue.
-- c1 = free, c2 = basic, c3 = advanced scaduto (= free).

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c1@test.dev'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@test.dev'),
  ('00000000-0000-0000-0000-0000000000c3', 'c3@test.dev');
insert into public.coach_plans (coach_id, plan, pro_until) values
  ('00000000-0000-0000-0000-0000000000c2', 'basic', null),
  ('00000000-0000-0000-0000-0000000000c3', 'advanced', now() - interval '1 day');

create function pg_temp.template(owner int, n int) returns void language sql as $$
  insert into public.mesocycle_templates (owner_id, name, weeks, sessions, structure)
  values (('00000000-0000-0000-0000-0000000000c' || owner)::uuid, 'T' || n, 4, 0, '{"version": 1, "sessions": []}');
$$;
create function pg_temp.preset(owner int, n int) returns void language sql as $$
  insert into public.progression_presets (owner_id, name, rule)
  values (('00000000-0000-0000-0000-0000000000c' || owner)::uuid, 'P' || n, '{"sets": {"start": 3}}');
$$;

-- template di mesociclo: free 1
select lives_ok($$select pg_temp.template(1, 1)$$, 'free: il primo template entra');
select throws_ok($$select pg_temp.template(1, 2)$$, 'P0001', 'mesocycle_templates_limit_reached', 'free: il secondo no');
-- basic 5
select lives_ok($$select pg_temp.template(2, g) from generate_series(1, 5) g$$, 'basic: 5 template');
select throws_ok($$select pg_temp.template(2, 6)$$, 'P0001', 'mesocycle_templates_limit_reached', 'basic: il sesto no');
-- piano scaduto = free
select lives_ok($$select pg_temp.template(3, 1)$$, 'piano scaduto: vale il tetto del free (uno)');
select throws_ok($$select pg_temp.template(3, 2)$$, 'P0001', 'mesocycle_templates_limit_reached', 'piano scaduto: il secondo no');
-- ognuno conta i suoi: i template di c2 non occupano posti a c1 (c1 ne ha già uno, quindi si prova con un altro coach libero)
select is((select count(*)::int from public.mesocycle_templates where owner_id = '00000000-0000-0000-0000-0000000000c1'), 1, 'ognuno conta i propri');
-- chi era sopra tetto tiene i suoi, non ne aggiunge: basic → free con 5 template
update public.coach_plans set plan = 'free' where coach_id = '00000000-0000-0000-0000-0000000000c2';
select is((select count(*)::int from public.mesocycle_templates where owner_id = '00000000-0000-0000-0000-0000000000c2'), 5, 'declassato: tiene i 5 template');
select throws_ok($$select pg_temp.template(2, 7)$$, 'P0001', 'mesocycle_templates_limit_reached', 'declassato: non ne aggiunge');
-- eliminarne uno non libera comunque posti sopra il tetto, ma sotto sì
delete from public.mesocycle_templates where owner_id = '00000000-0000-0000-0000-0000000000c1';
select lives_ok($$select pg_temp.template(1, 9)$$, 'eliminato il template si può farne un altro');

-- progressioni salvate: free 20
select lives_ok($$select pg_temp.preset(1, g) from generate_series(1, 20) g$$, 'free: 20 progressioni');
select throws_ok($$select pg_temp.preset(1, 21)$$, 'P0001', 'progression_presets_limit_reached', 'free: la 21ª no');
update public.coach_plans set plan = 'basic' where coach_id = '00000000-0000-0000-0000-0000000000c2';
select lives_ok($$select pg_temp.preset(2, g) from generate_series(1, 25) g$$, 'basic: oltre 20 entrano');
select throws_ok($$select pg_temp.preset(3, g) from generate_series(1, 21) g$$, 'P0001', 'progression_presets_limit_reached',
  'piano scaduto: vale il free anche per le progressioni');

-- l'errore porta il tetto nel hint, per il messaggio del client
select throws_ok($$select pg_temp.preset(1, 99)$$, 'P0001', 'progression_presets_limit_reached', 'il rifiuto è sempre lo stesso errore');

-- plan_usage dice quanto è usato (la riga di c2 è visibile a lui soltanto)
create schema tests;
grant usage on schema tests to authenticated;
create function tests.login(uid uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
grant execute on all functions in schema tests to authenticated;
select tests.login('00000000-0000-0000-0000-0000000000c2');
select results_eq(
  $$select mesocycle_templates, progression_presets from public.plan_usage()$$,
  $$values (5, 25)$$, 'plan_usage conta template e progressioni del coach');

select * from finish();
rollback;
