-- Tetto di atleti per piano (free 20, mid 60, pro 100, unlimited nessuno), piano scaduto, collegamenti
-- che non occupano posti, plan_usage e disattivazione dell'account.
-- Coach: f = free, m = mid, p = pro, u = unlimited, x = pro scaduto, s = free con 19 atleti + sé stesso.

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

-- 7 coach e 330 atleti candidati (il trigger su auth.users crea i profili)
insert into auth.users (id, email)
select ('00000000-0000-0000-0000-0000000000' || lpad(to_hex(g), 2, '0'))::uuid, 'coach' || g || '@t.dev'
from generate_series(1, 7) g;
insert into auth.users (id, email)
select ('a0000000-0000-0000-0000-' || lpad(g::text, 12, '0'))::uuid, 'ath' || g || '@t.dev'
from generate_series(1, 330) g;

-- coach 01 = f, 02 = m, 03 = p, 04 = u, 05 = x, 06 = s (senza riga di piano = free)
insert into public.coach_plans (coach_id, plan, pro_until) values
  ('00000000-0000-0000-0000-000000000001', 'free', null),
  ('00000000-0000-0000-0000-000000000002', 'mid', null),
  ('00000000-0000-0000-0000-000000000003', 'pro', null),
  ('00000000-0000-0000-0000-000000000004', 'unlimited', null),
  ('00000000-0000-0000-0000-000000000005', 'pro', now() - interval '1 day');

create function pg_temp.link(c int, first_ath int, last_ath int, st public.link_status default 'pending') returns void
language sql as $$
  insert into public.coach_athletes (coach_id, athlete_id, status)
  select ('00000000-0000-0000-0000-0000000000' || lpad(to_hex(c), 2, '0'))::uuid,
         ('a0000000-0000-0000-0000-' || lpad(g::text, 12, '0'))::uuid, st
  from generate_series(first_ath, last_ath) g;
$$;

-- free: 20 sì, il 21° no
select lives_ok($$select pg_temp.link(1, 1, 20)$$, 'free: 20 atleti entrano');
select throws_ok($$select pg_temp.link(1, 21, 21)$$, 'P0001', 'athlete_limit_reached', 'free: il 21° è rifiutato');

-- anche chi scrive come service_role (la Edge Function degli inviti) passa dal tetto
set local role service_role;
select lives_ok(
  $$insert into public.coach_athletes (coach_id, athlete_id, status)
    values ('00000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000300', 'pending')$$,
  'service_role: il collegamento di un coach con posto libero entra');
select throws_ok(
  $$insert into public.coach_athletes (coach_id, athlete_id, status)
    values ('00000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000030', 'pending')$$,
  'P0001', 'athlete_limit_reached', 'service_role: il tetto vale anche per lui');
reset role;

-- il collegamento con sé stesso e quelli chiusi non contano
insert into public.coach_athletes (coach_id, athlete_id, status)
values ('00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000006', 'active');
select lives_ok($$select pg_temp.link(6, 31, 49)$$, 'coach s: 19 atleti più sé stesso');
select lives_ok($$select pg_temp.link(6, 50, 50)$$, 'coach s: il 20° entra, il collegamento con sé stesso non conta');
select throws_ok($$select pg_temp.link(6, 51, 51)$$, 'P0001', 'athlete_limit_reached', 'coach s: il 21° no');
update public.coach_athletes set status = 'ended'
 where coach_id = '00000000-0000-0000-0000-000000000006' and athlete_id = 'a0000000-0000-0000-0000-000000000031';
select lives_ok($$select pg_temp.link(6, 51, 51)$$, 'un collegamento chiuso libera un posto');
select throws_ok(
  $$update public.coach_athletes set status = 'pending'
     where coach_id = '00000000-0000-0000-0000-000000000006' and athlete_id = 'a0000000-0000-0000-0000-000000000031'$$,
  'P0001', 'athlete_limit_reached', 'riaprire un collegamento chiuso a tetto pieno è rifiutato');

-- pending → active non occupa un secondo posto
select lives_ok(
  $$update public.coach_athletes set status = 'active'
     where coach_id = '00000000-0000-0000-0000-000000000001' and athlete_id = 'a0000000-0000-0000-0000-000000000001'$$,
  'pending → active resta consentito a tetto pieno');

-- mid 60, pro 100, unlimited senza tetto, pro scaduto = free
select lives_ok($$select pg_temp.link(2, 1, 60)$$, 'mid: 60 atleti');
select throws_ok($$select pg_temp.link(2, 61, 61)$$, 'P0001', 'athlete_limit_reached', 'mid: il 61° no');
select lives_ok($$select pg_temp.link(3, 1, 100)$$, 'pro: 100 atleti');
select throws_ok($$select pg_temp.link(3, 101, 101)$$, 'P0001', 'athlete_limit_reached', 'pro: il 101° no');
select lives_ok($$select pg_temp.link(4, 1, 330)$$, 'unlimited: 330 atleti, nessun tetto');
select lives_ok($$select pg_temp.link(5, 1, 20)$$, 'pro scaduto: 20 atleti');
select throws_ok($$select pg_temp.link(5, 21, 21)$$, 'P0001', 'athlete_limit_reached', 'pro scaduto: vale il tetto del free');

-- Funzioni di Personalizza: da pro in su, non mid, non scaduto
select ok(private.is_pro('00000000-0000-0000-0000-000000000003'), 'pro è pro');
select ok(private.is_pro('00000000-0000-0000-0000-000000000004'), 'unlimited è pro');
select ok(not private.is_pro('00000000-0000-0000-0000-000000000002'), 'mid non ha Personalizza');
select ok(not private.is_pro('00000000-0000-0000-0000-000000000005'), 'pro scaduto no');

create schema tests;
grant usage on schema tests to authenticated;
create function tests.login(uid uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
grant execute on all functions in schema tests to authenticated;

select tests.login('00000000-0000-0000-0000-000000000002');
select results_eq(
  $$select plan::text, athlete_limit, athletes, can_customize from public.plan_usage()$$,
  $$values ('mid', 60, 60, false)$$, 'plan_usage del coach mid');
select tests.login('00000000-0000-0000-0000-000000000004');
select results_eq(
  $$select plan::text, athlete_limit, athletes, can_customize from public.plan_usage()$$,
  $$values ('unlimited', null::int, 330, true)$$, 'plan_usage di unlimited: nessun tetto');
select tests.login('00000000-0000-0000-0000-000000000005');
select results_eq(
  $$select plan::text, athlete_limit, can_customize from public.plan_usage()$$,
  $$values ('free', 20, false)$$, 'plan_usage con pro scaduto vale free');

-- Il catalogo dei piani per la pagina dei prezzi: stessi numeri dei tetti
select results_eq(
  $$select plan::text, athlete_limit from public.plan_limits() order by plan$$,
  $$values ('free', 20), ('mid', 60), ('pro', 100), ('unlimited', null::int)$$,
  'plan_limits elenca i quattro livelli con il loro tetto');

-- Disattivazione: la persona cambia solo il proprio profilo
select tests.login('00000000-0000-0000-0000-000000000001');
select lives_ok(
  $$update public.profiles set disabled_at = now() where id = '00000000-0000-0000-0000-000000000001'$$,
  'ognuno disattiva il proprio account');
select is(
  (select count(*)::int from public.profiles where id <> '00000000-0000-0000-0000-000000000001' and disabled_at is not null),
  0, 'nessun altro profilo risulta disattivato');

select * from finish();
rollback;
