-- GENERATO da fixtures/generate-sql.mjs a partire da fixtures/nutrition_target_cases.json: non modificare a mano.
-- nutrition_target_on: gli stessi casi della fixture che passa anche l'implementazione Swift.

begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

-- 1. un solo piano, il giorno dopo l'inizio
insert into auth.users (id, email) values ('a0000001-0000-4000-8000-000000000001', 'macro1@fixture.test');
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000001-0000-4000-8000-000000000001', 'a0000001-0000-4000-8000-000000000001', '2026-10-01', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000001-0000-4000-8000-000000000001', 2500, 150, 250, 70);
select is((select kcal from public.nutrition_target_on('a0000001-0000-4000-8000-000000000001', '2026-10-02'::date)), 2500::int, 'un solo piano, il giorno dopo l''inizio');

-- 2. il giorno stesso dell'inizio il piano vale già
insert into auth.users (id, email) values ('a0000002-0000-4000-8000-000000000001', 'macro2@fixture.test');
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000002-0000-4000-8000-000000000001', 'a0000002-0000-4000-8000-000000000001', '2026-10-01', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000002-0000-4000-8000-000000000001', 2500, 150, 250, 70);
select is((select kcal from public.nutrition_target_on('a0000002-0000-4000-8000-000000000001', '2026-10-01'::date)), 2500::int, 'il giorno stesso dell''inizio il piano vale già');

-- 3. prima dell'inizio non c'è obiettivo
insert into auth.users (id, email) values ('a0000003-0000-4000-8000-000000000001', 'macro3@fixture.test');
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000003-0000-4000-8000-000000000001', 'a0000003-0000-4000-8000-000000000001', '2026-10-01', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000003-0000-4000-8000-000000000001', 2500, 150, 250, 70);
select is((select kcal from public.nutrition_target_on('a0000003-0000-4000-8000-000000000001', '2026-09-30'::date)), null::int, 'prima dell''inizio non c''è obiettivo');

-- 4. nessun piano: nessun obiettivo
insert into auth.users (id, email) values ('a0000004-0000-4000-8000-000000000001', 'macro4@fixture.test');
select is((select kcal from public.nutrition_target_on('a0000004-0000-4000-8000-000000000001', '2026-10-01'::date)), null::int, 'nessun piano: nessun obiettivo');

-- 5. più piani: vale il più recente già iniziato
insert into auth.users (id, email) values ('a0000005-0000-4000-8000-000000000001', 'macro5@fixture.test');
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000005-0000-4000-8000-000000000001', 'a0000005-0000-4000-8000-000000000001', '2026-10-01', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000005-0000-4000-8000-000000000001', 2500, 150, 250, 70);
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000005-0000-4000-8000-000000000002', 'a0000005-0000-4000-8000-000000000001', '2026-10-11', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000005-0000-4000-8000-000000000002', 2200, 150, 250, 70);
select is((select kcal from public.nutrition_target_on('a0000005-0000-4000-8000-000000000001', '2026-10-20'::date)), 2200::int, 'più piani: vale il più recente già iniziato');

-- 6. più piani: il giorno prima del cambio vale il vecchio
insert into auth.users (id, email) values ('a0000006-0000-4000-8000-000000000001', 'macro6@fixture.test');
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000006-0000-4000-8000-000000000001', 'a0000006-0000-4000-8000-000000000001', '2026-10-01', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000006-0000-4000-8000-000000000001', 2500, 150, 250, 70);
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000006-0000-4000-8000-000000000002', 'a0000006-0000-4000-8000-000000000001', '2026-10-11', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000006-0000-4000-8000-000000000002', 2200, 150, 250, 70);
select is((select kcal from public.nutrition_target_on('a0000006-0000-4000-8000-000000000001', '2026-10-10'::date)), 2500::int, 'più piani: il giorno prima del cambio vale il vecchio');

-- 7. un piano che inizia più avanti non vale ancora
insert into auth.users (id, email) values ('a0000007-0000-4000-8000-000000000001', 'macro7@fixture.test');
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000007-0000-4000-8000-000000000001', 'a0000007-0000-4000-8000-000000000001', '2026-10-01', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000007-0000-4000-8000-000000000001', 2500, 150, 250, 70);
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000007-0000-4000-8000-000000000002', 'a0000007-0000-4000-8000-000000000001', '2026-11-01', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000007-0000-4000-8000-000000000002', 2000, 150, 250, 70);
select is((select kcal from public.nutrition_target_on('a0000007-0000-4000-8000-000000000001', '2026-10-20'::date)), 2500::int, 'un piano che inizia più avanti non vale ancora');

-- 8. un piano eliminato non vale: torna il precedente
insert into auth.users (id, email) values ('a0000008-0000-4000-8000-000000000001', 'macro8@fixture.test');
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000008-0000-4000-8000-000000000001', 'a0000008-0000-4000-8000-000000000001', '2026-10-01', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000008-0000-4000-8000-000000000001', 2500, 150, 250, 70);
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000008-0000-4000-8000-000000000002', 'a0000008-0000-4000-8000-000000000001', '2026-10-11', now(), 'fixture', now());
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000008-0000-4000-8000-000000000002', 2200, 150, 250, 70);
select is((select kcal from public.nutrition_target_on('a0000008-0000-4000-8000-000000000001', '2026-10-20'::date)), 2500::int, 'un piano eliminato non vale: torna il precedente');

-- 9. l'unico piano è eliminato: nessun obiettivo
insert into auth.users (id, email) values ('a0000009-0000-4000-8000-000000000001', 'macro9@fixture.test');
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000009-0000-4000-8000-000000000001', 'a0000009-0000-4000-8000-000000000001', '2026-10-01', now(), 'fixture', now());
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000009-0000-4000-8000-000000000001', 2500, 150, 250, 70);
select is((select kcal from public.nutrition_target_on('a0000009-0000-4000-8000-000000000001', '2026-10-20'::date)), null::int, 'l''unico piano è eliminato: nessun obiettivo');

-- 10. l'ordine in cui arrivano i piani non conta
insert into auth.users (id, email) values ('a0000010-0000-4000-8000-000000000001', 'macro10@fixture.test');
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000010-0000-4000-8000-000000000001', 'a0000010-0000-4000-8000-000000000001', '2026-10-11', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000010-0000-4000-8000-000000000001', 2200, 150, 250, 70);
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000010-0000-4000-8000-000000000002', 'a0000010-0000-4000-8000-000000000001', '2026-10-01', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000010-0000-4000-8000-000000000002', 2500, 150, 250, 70);
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000010-0000-4000-8000-000000000003', 'a0000010-0000-4000-8000-000000000001', '2026-09-01', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000010-0000-4000-8000-000000000003', 3000, 150, 250, 70);
select is((select kcal from public.nutrition_target_on('a0000010-0000-4000-8000-000000000001', '2026-10-15'::date)), 2200::int, 'l''ordine in cui arrivano i piani non conta');

-- 11. a cavallo dell'anno
insert into auth.users (id, email) values ('a0000011-0000-4000-8000-000000000001', 'macro11@fixture.test');
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000011-0000-4000-8000-000000000001', 'a0000011-0000-4000-8000-000000000001', '2026-12-20', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000011-0000-4000-8000-000000000001', 2400, 150, 250, 70);
insert into public.nutrition_plans (id, athlete_id, valid_from, declared_at, declaration_version, deleted_at) values ('b0000011-0000-4000-8000-000000000002', 'a0000011-0000-4000-8000-000000000001', '2027-01-05', now(), 'fixture', null);
insert into public.nutrition_plan_days (plan_id, kcal, protein_g, carbs_g, fat_g) values ('b0000011-0000-4000-8000-000000000002', 2300, 150, 250, 70);
select is((select kcal from public.nutrition_target_on('a0000011-0000-4000-8000-000000000001', '2027-01-02'::date)), 2400::int, 'a cavallo dell''anno');

select * from finish();
rollback;
