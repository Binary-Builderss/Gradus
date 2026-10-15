-- coach_plans e coach_branding: nessuna promozione da client, scrittura solo con piano pro, lettura
-- dell'atleta solo da coach pro collegato, colori e logo validati.
-- c1 = coach pro (collegato ad a1), c2 = coach free (collegato a b1), c3 = coach con pro scaduto
-- (collegato ad a3), c4 = coach senza riga di piano e senza marchio.

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c1@test.dev'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@test.dev'),
  ('00000000-0000-0000-0000-0000000000c3', 'c3@test.dev'),
  ('00000000-0000-0000-0000-0000000000c4', 'c4@test.dev'),
  ('00000000-0000-0000-0000-0000000000a1', 'a1@test.dev'),
  ('00000000-0000-0000-0000-0000000000b1', 'b1@test.dev'),
  ('00000000-0000-0000-0000-0000000000a3', 'a3@test.dev');
insert into public.coach_athletes (coach_id, athlete_id, status) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'active'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000b1', 'active'),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000a3', 'active');
insert into public.coach_plans (coach_id, plan, pro_until) values
  ('00000000-0000-0000-0000-0000000000c1', 'pro', null),
  ('00000000-0000-0000-0000-0000000000c2', 'free', null),
  ('00000000-0000-0000-0000-0000000000c3', 'pro', now() - interval '1 day');
insert into public.coach_branding (coach_id, brand_name, colors) values
  ('00000000-0000-0000-0000-0000000000c1', 'Studio Uno', '{"primary": "#0a7d4b"}'),
  ('00000000-0000-0000-0000-0000000000c2', 'Studio Due', '{}'),
  ('00000000-0000-0000-0000-0000000000c3', 'Studio Tre', '{}');

create schema tests;
grant usage on schema tests to authenticated;
create function tests.login(uid uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
-- Righe toccate da un'istruzione: con RLS una scrittura non permessa non dà errore, tocca 0 righe.
create function tests.rows_affected(q text) returns int language plpgsql as $$
declare n int;
begin
  execute q;
  get diagnostics n = row_count;
  return n;
end;
$$;
grant execute on all functions in schema tests to authenticated;

-- coach pro
select tests.login('00000000-0000-0000-0000-0000000000c1');
select ok(public.has_pro_plan(), 'il coach pro risulta pro');
select is((select count(*)::int from public.coach_branding), 1, 'il coach vede solo il proprio marchio');
select lives_ok(
  $$update public.coach_branding set colors = '{"primary": "#112233", "background": "#FAFAFA"}', brand_name = 'Nuovo nome'
    where coach_id = '00000000-0000-0000-0000-0000000000c1'$$,
  'il coach pro aggiorna il proprio marchio');
select throws_ok(
  $$update public.coach_branding set colors = '{"primary": "verde"}' where coach_id = '00000000-0000-0000-0000-0000000000c1'$$,
  '23514', null, 'un colore che non è #RRGGBB è rifiutato');
select throws_ok(
  $$update public.coach_branding set colors = '{"sfondo": "#112233"}' where coach_id = '00000000-0000-0000-0000-0000000000c1'$$,
  '23514', null, 'una chiave di colore sconosciuta è rifiutata');
select throws_ok(
  $$update public.coach_branding set logo_png = 'data:image/png;base64,AAAA' where coach_id = '00000000-0000-0000-0000-0000000000c1'$$,
  '23514', null, 'il logo deve essere base64 puro, senza prefisso');
select throws_ok(
  $$update public.coach_branding set logo_png = repeat('A', 400001) where coach_id = '00000000-0000-0000-0000-0000000000c1'$$,
  '23514', null, 'un logo troppo grande è rifiutato');
select lives_ok(
  $$update public.coach_branding set logo_png = 'iVBORw0KGgo=' where coach_id = '00000000-0000-0000-0000-0000000000c1'$$,
  'un logo base64 valido è accettato');
select is((select count(*)::int from public.coach_plans), 1, 'il coach legge solo il proprio piano');
select throws_ok(
  $$update public.coach_plans set plan = 'free' where coach_id = '00000000-0000-0000-0000-0000000000c1'$$,
  '42501', null, 'il coach non modifica il proprio piano');

-- coach free: legge, non scrive; non può promuoversi
select tests.login('00000000-0000-0000-0000-0000000000c2');
select ok(not public.has_pro_plan(), 'il coach free non risulta pro');
select is((select count(*)::int from public.coach_branding), 1, 'il coach free legge il proprio marchio');
select is(
  tests.rows_affected($$update public.coach_branding set brand_name = 'Altro' where coach_id = '00000000-0000-0000-0000-0000000000c2'$$),
  0, 'il coach free non scrive il marchio');
select throws_ok(
  $$update public.coach_plans set plan = 'pro' where coach_id = '00000000-0000-0000-0000-0000000000c2'$$,
  '42501', null, 'il coach free non si promuove a pro');
select throws_ok(
  $$insert into public.coach_plans (coach_id, plan) values ('00000000-0000-0000-0000-0000000000c2', 'pro')$$,
  '42501', null, 'nemmeno inserendo una riga di piano');

-- coach con pro scaduto e coach senza piano
select tests.login('00000000-0000-0000-0000-0000000000c3');
select ok(not public.has_pro_plan(), 'pro scaduto = non pro');
select tests.login('00000000-0000-0000-0000-0000000000c4');
select ok(not public.has_pro_plan(), 'nessuna riga di piano = non pro');
select throws_ok(
  $$insert into public.coach_branding (coach_id, brand_name) values ('00000000-0000-0000-0000-0000000000c4', 'X')$$,
  '42501', null, 'senza piano pro non si crea il marchio');

-- atleta del coach pro: vede il marchio
select tests.login('00000000-0000-0000-0000-0000000000a1');
select is((select count(*)::int from public.coach_branding), 1, 'l''atleta del coach pro vede il suo marchio');
select is((select count(*)::int from public.coach_plans), 0, 'l''atleta non legge i piani');
select is(
  tests.rows_affected($$update public.coach_branding set brand_name = 'Hack'$$),
  0, 'l''atleta non scrive il marchio');

-- atleta di un coach free o con pro scaduto, e coach di un altro: niente
select tests.login('00000000-0000-0000-0000-0000000000b1');
select is((select count(*)::int from public.coach_branding), 0, 'l''atleta di un coach free non vede marchio');
select tests.login('00000000-0000-0000-0000-0000000000a3');
select is((select count(*)::int from public.coach_branding), 0, 'con il pro scaduto l''atleta torna allo standard');

select * from finish();
rollback;
