-- Catalogo globale degli esercizi (migrazioni *_catalog_*).

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

select ok(
  (select count(*) from public.exercises where owner_id is null) >= 130,
  'il catalogo globale contiene almeno i 130 esercizi della v1');
select is(
  (select count(*)::int from public.exercises e where e.owner_id is null and not exists (
     select 1 from public.exercise_muscles m where m.exercise_id = e.id and m.weight = 1)),
  0, 'ogni esercizio del catalogo ha almeno un muscolo diretto (peso 1)');
select is(
  (select count(*)::int from (select lower(name) from public.exercises where owner_id is null
                              group by 1 having count(*) > 1) d),
  0, 'nessun nome duplicato nel catalogo');

insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000a1', 'a@test.dev');
select set_config('role', 'authenticated', true),
       set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000a1"}', true);
select ok(
  (select count(*) from public.exercises where owner_id is null) >= 130,
  'qualunque utente autenticato vede il catalogo');
select results_eq($$
  with u as (update public.exercises set name = name || '!' where owner_id is null returning 1)
  select count(*)::int from u $$, 'values (0)', 'nessun utente modifica il catalogo');
select results_eq($$
  with u as (update public.exercise_muscles set weight = 0.5 returning 1)
  select count(*)::int from u $$, 'values (0)', 'nessun utente modifica i pesi del catalogo');

select * from finish();
rollback;
