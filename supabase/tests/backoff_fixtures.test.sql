-- GENERATO da fixtures/generate-sql.mjs a partire da fixtures/backoff_cases.json: non modificare a mano.
-- backoff_target_load: gli stessi casi della fixture che passa anche l'implementazione Swift.

begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

select is(public.backoff_target_load(100, 85), 85::numeric, '85% di 100 kg è già un multiplo di 2,5');
select is(public.backoff_target_load(100, 90), 90::numeric, '90% di 100 kg');
select is(public.backoff_target_load(105, 85), 90::numeric, '85% di 105 kg = 89,25 → 90');
select is(public.backoff_target_load(100, 82.5), 82.5::numeric, 'percentuale con decimali: 82,5% di 100 kg');
select is(public.backoff_target_load(90.9, 80), 72.5::numeric, 'carico con decimali: 80% di 90,9 kg = 72,72 → 72,5');
select is(public.backoff_target_load(100, 83.75), 85::numeric, 'a metà si sale: 83,75 → 85');
select is(public.backoff_target_load(100, 81.25), 82.5::numeric, 'a metà si sale: 81,25 → 82,5');
select is(public.backoff_target_load(60, 70), 42.5::numeric, '70% di 60 kg = 42 → 42,5');
select is(public.backoff_target_load(140, 75), 105::numeric, '75% di 140 kg = 105');
select is(public.backoff_target_load(20, 50), 10::numeric, '50% di 20 kg = 10');
select is(public.backoff_target_load(127.5, 90), 115::numeric, '90% di 127,5 kg = 114,75 → 115');
select is(public.backoff_target_load(100, 105), 105::numeric, 'oltre il 100%: 105% di 100 kg');
select is(public.backoff_target_load(7, 85), 5::numeric, 'carichi leggeri: 85% di 7 kg = 5,95 → 5');

select * from finish();
rollback;
