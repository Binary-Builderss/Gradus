-- coach_plans e coach_branding: nessuna promozione da client, scrittura solo da basic in su, lettura
-- dell'atleta solo da un coach con personalizzazione collegato, colori e logo validati, libertà a livelli.
-- c1 = coach advanced (collegato ad a1), c2 = coach free (collegato a b1), c3 = coach con advanced scaduto
-- (collegato ad a3), c4 = coach senza riga di piano e senza marchio, c5 = basic, c6 = custom.

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c1@test.dev'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@test.dev'),
  ('00000000-0000-0000-0000-0000000000c3', 'c3@test.dev'),
  ('00000000-0000-0000-0000-0000000000c4', 'c4@test.dev'),
  ('00000000-0000-0000-0000-0000000000c5', 'c5@test.dev'),
  ('00000000-0000-0000-0000-0000000000c6', 'c6@test.dev'),
  ('00000000-0000-0000-0000-0000000000a1', 'a1@test.dev'),
  ('00000000-0000-0000-0000-0000000000b1', 'b1@test.dev'),
  ('00000000-0000-0000-0000-0000000000a3', 'a3@test.dev');
insert into public.coach_athletes (coach_id, athlete_id, status) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'active'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000b1', 'active'),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000a3', 'active');
-- Il marchio si scrive solo con un piano che lo ammette: si crea con advanced e poi si declassa c2 e c3.
insert into public.coach_plans (coach_id, plan, pro_until) values
  ('00000000-0000-0000-0000-0000000000c1', 'advanced', null),
  ('00000000-0000-0000-0000-0000000000c2', 'advanced', null),
  ('00000000-0000-0000-0000-0000000000c3', 'advanced', null),
  ('00000000-0000-0000-0000-0000000000c5', 'basic', null),
  ('00000000-0000-0000-0000-0000000000c6', 'custom', null);
insert into public.coach_branding (coach_id, brand_name, colors) values
  ('00000000-0000-0000-0000-0000000000c1', 'Studio Uno', '{"primary": "#0a7d4b"}'),
  ('00000000-0000-0000-0000-0000000000c2', 'Studio Due', '{}'),
  ('00000000-0000-0000-0000-0000000000c3', 'Studio Tre', '{}'),
  ('00000000-0000-0000-0000-0000000000c5', 'Studio Cinque', '{"primary": "#aa3300"}'),
  ('00000000-0000-0000-0000-0000000000c6', 'Studio Sei', '{"primary": "#003366"}');
update public.coach_plans set plan = 'free' where coach_id = '00000000-0000-0000-0000-0000000000c2';
update public.coach_plans set pro_until = now() - interval '1 day' where coach_id = '00000000-0000-0000-0000-0000000000c3';

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

-- coach advanced
select tests.login('00000000-0000-0000-0000-0000000000c1');
select is((select branding_level from public.plan_usage()), 2, 'il coach advanced ha il livello 2');
select is((select count(*)::int from public.coach_branding), 1, 'il coach vede solo il proprio marchio');
select lives_ok(
  $$update public.coach_branding set colors = '{"primary": "#112233", "background": "#FAFAFA"}', brand_name = 'Nuovo nome'
    where coach_id = '00000000-0000-0000-0000-0000000000c1'$$,
  'il coach advanced aggiorna il proprio marchio con la tavolozza');
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
select is((select branding_level from public.plan_usage()), 0, 'il coach free non ha personalizzazione');
select is((select count(*)::int from public.coach_branding), 1, 'il coach free legge il proprio marchio');
select is(
  tests.rows_affected($$update public.coach_branding set brand_name = 'Altro' where coach_id = '00000000-0000-0000-0000-0000000000c2'$$),
  0, 'il coach free non scrive il marchio');
select throws_ok(
  $$update public.coach_plans set plan = 'advanced' where coach_id = '00000000-0000-0000-0000-0000000000c2'$$,
  '42501', null, 'il coach free non si promuove');
select throws_ok(
  $$insert into public.coach_plans (coach_id, plan) values ('00000000-0000-0000-0000-0000000000c2', 'advanced')$$,
  '42501', null, 'nemmeno inserendo una riga di piano');

-- coach con advanced scaduto e coach senza piano
select tests.login('00000000-0000-0000-0000-0000000000c3');
select is((select branding_level from public.plan_usage()), 0, 'advanced scaduto = nessuna personalizzazione');
select tests.login('00000000-0000-0000-0000-0000000000c4');
select is((select branding_level from public.plan_usage()), 0, 'nessuna riga di piano = nessuna personalizzazione');
select throws_ok(
  $$insert into public.coach_branding (coach_id, brand_name) values ('00000000-0000-0000-0000-0000000000c4', 'X')$$,
  'P0001', 'branding_level_too_low', 'senza un piano che lo ammette non si crea il marchio');

-- atleta del coach pro: vede il marchio
select tests.login('00000000-0000-0000-0000-0000000000a1');
select is((select count(*)::int from public.coach_branding), 1, 'l''atleta del coach advanced vede il suo marchio');
select is((select count(*)::int from public.coach_plans), 0, 'l''atleta non legge i piani');
select is(
  tests.rows_affected($$update public.coach_branding set brand_name = 'Hack'$$),
  0, 'l''atleta non scrive il marchio');

-- atleta di un coach free o con piano scaduto, e coach di un altro: niente
select tests.login('00000000-0000-0000-0000-0000000000b1');
select is((select count(*)::int from public.coach_branding), 0, 'l''atleta di un coach free non vede marchio');
select tests.login('00000000-0000-0000-0000-0000000000a3');
select is((select count(*)::int from public.coach_branding), 0, 'con il piano scaduto l''atleta torna allo standard');

-- Libertà a livelli ---------------------------------------------------------------------------------------
-- basic (c5): logo, nome e un colore principale, non la tavolozza né la dicitura
select tests.login('00000000-0000-0000-0000-0000000000c5');
select is((select branding_level from public.plan_usage()), 1, 'il coach basic ha il livello 1');
select lives_ok(
  $$update public.coach_branding set colors = '{"primary": "#123456"}', brand_name = 'Cinque', logo_png = 'iVBORw0KGgo='
    where coach_id = '00000000-0000-0000-0000-0000000000c5'$$,
  'basic: logo, nome e colore principale');
select throws_ok(
  $$update public.coach_branding set colors = '{"primary": "#123456", "background": "#FFFFFF"}'
    where coach_id = '00000000-0000-0000-0000-0000000000c5'$$,
  'P0001', 'branding_level_too_low', 'basic: la tavolozza completa no');
select throws_ok(
  $$update public.coach_branding set hide_gradus_credit = true where coach_id = '00000000-0000-0000-0000-0000000000c5'$$,
  'P0001', 'branding_level_too_low', 'basic: la dicitura Gradus resta');

-- advanced (c1): tavolozza completa, ma non la dicitura
select tests.login('00000000-0000-0000-0000-0000000000c1');
select throws_ok(
  $$update public.coach_branding set hide_gradus_credit = true where coach_id = '00000000-0000-0000-0000-0000000000c1'$$,
  'P0001', 'branding_level_too_low', 'advanced: la dicitura Gradus resta');

-- custom (c6): anche il PDF senza la dicitura
select tests.login('00000000-0000-0000-0000-0000000000c6');
select is((select branding_level from public.plan_usage()), 3, 'il coach custom ha il livello 3');
select lives_ok(
  $$update public.coach_branding
       set colors = '{"primary": "#003366", "background": "#F0F0F0", "border": "#CCCCCC"}', hide_gradus_credit = true
     where coach_id = '00000000-0000-0000-0000-0000000000c6'$$,
  'custom: tavolozza completa e senza dicitura');

-- chi scende di livello vede il marchio ridimensionato (il piano lo cambia il servizio di pagamento, service_role)
reset role;
update public.coach_plans set plan = 'advanced' where coach_id = '00000000-0000-0000-0000-0000000000c6';
select is(
  (select hide_gradus_credit from public.coach_branding where coach_id = '00000000-0000-0000-0000-0000000000c6'),
  false, 'custom → advanced: la dicitura torna');
select is(
  (select colors ->> 'border' from public.coach_branding where coach_id = '00000000-0000-0000-0000-0000000000c6'),
  '#CCCCCC', 'custom → advanced: la tavolozza resta');
update public.coach_plans set plan = 'basic' where coach_id = '00000000-0000-0000-0000-0000000000c6';
select is(
  (select colors from public.coach_branding where coach_id = '00000000-0000-0000-0000-0000000000c6'),
  '{"primary": "#003366"}'::jsonb, 'advanced → basic: resta solo il colore principale');
-- scendendo a free il marchio resta (si riprende se si risale) ma nemmeno un'istruzione di servizio lo cambia
update public.coach_plans set plan = 'free' where coach_id = '00000000-0000-0000-0000-0000000000c6';
select is(
  (select brand_name from public.coach_branding where coach_id = '00000000-0000-0000-0000-0000000000c6'),
  'Studio Sei', 'basic → free: il marchio non si cancella');
select throws_ok(
  $$update public.coach_branding set brand_name = 'Hack' where coach_id = '00000000-0000-0000-0000-0000000000c6'$$,
  'P0001', 'branding_level_too_low', 'a livello 0 nessuna via di scrittura lo modifica');

select * from finish();
rollback;
