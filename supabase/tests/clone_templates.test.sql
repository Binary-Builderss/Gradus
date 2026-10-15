-- clone_mesocycle, template del coach (save_mesocycle_as_template / instantiate_template) e serie migliori
-- (athlete_best_sets / top_set_history).
-- c1 = coach collegato ad a1 (a2 ha un invito in attesa), c2 = altro coach con b1.
-- Mesociclo 01 di a1, 4 settimane, scarico in settimana 4: una seduta (e una eliminata), un gruppo con due esercizi
-- (e1: top + back-off legato + riscaldamento; e2: lavoro + un blocco eliminato).

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c1@test.dev'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@test.dev'),
  ('00000000-0000-0000-0000-0000000000a1', 'a1@test.dev'),
  ('00000000-0000-0000-0000-0000000000a2', 'a2@test.dev'),
  ('00000000-0000-0000-0000-0000000000b1', 'b1@test.dev');
insert into public.coach_athletes (coach_id, athlete_id, status) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'active'),
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a2', 'pending'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000b1', 'active');
insert into public.exercises (id, owner_id, name) values
  ('e0000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000c1', 'Panca'),
  ('e0000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000c1', 'Croci');
insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status, coach_notes) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', 'Blocco 1', '2026-10-05', 4, '{4}', 'active', 'Note del coach');
insert into public.sessions (id, mesocycle_id, position, name, coach_notes, deleted_at) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 0, 'Spinta', 'Scalda bene', null),
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 1, 'Eliminata', null, now());
insert into public.slot_groups (id, mesocycle_id, session_id, position, kind, rest_between_s, rest_after_round_s) values
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 0, 'superset', 10, 90);
insert into public.slots (id, mesocycle_id, group_id, position, exercise_id, coach_notes) values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 0, 'e0000000-0000-0000-0000-0000000000e1', 'Gomiti stretti'),
  ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 1, 'e0000000-0000-0000-0000-0000000000e2', null);
insert into public.set_blocks (id, mesocycle_id, slot_id, position, role, technique, tut_eccentric_s, tut_bottom_pause_s, tut_concentric_s, tut_top_pause_s, rest_s, deleted_at) values
  ('50000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 0, 'top', 'none', 3, 1, 1, 0, 180, null),
  ('50000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 1, 'backoff', 'drop', null, null, null, null, 120, null),
  ('50000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000002', 0, 'working', 'none', null, null, null, null, null, null),
  ('50000000-0000-0000-0000-000000000004', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000002', 1, 'working', 'none', null, null, null, null, null, now()),
  ('50000000-0000-0000-0000-000000000005', '10000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 2, 'warmup', 'none', null, null, null, null, null, null);
update public.set_blocks set ref_block_id = '50000000-0000-0000-0000-000000000001'
  where id = '50000000-0000-0000-0000-000000000002';
insert into public.block_weeks (mesocycle_id, block_id, week, sets, reps_min, reps_max, method, intensity_value, ref_pct) values
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 1, 1, 5, 5, 'BUF', 3, null),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 2, 1, 5, 5, 'BUF', 2, null),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 3, 1, 5, 5, 'BUF', 1, null),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', 1, 2, 8, 10, null, null, 85),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', 2, 2, 8, 10, null, null, 85),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000002', 3, 3, 8, 10, null, null, 85),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 1, 3, 12, 15, 'RPE', 8, null),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000004', 1, 7, 12, 15, null, null, null),
  ('10000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000005', 1, 2, 10, 10, null, null, null);
-- esecuzione: w1 (sett. 1) e w2 (sett. 2). Top e1: 100×5 e 90×8 in w1; 105×5 in w2. Riscaldamento 130×3 (non conta).
-- Back-off 80×10 in w2. e2: 50×10 in w1.
insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values
  ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 1),
  ('70000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', 2);
insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx) values
  ('80000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 0),
  ('80000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', 1),
  ('80000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', 0),
  ('80000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000005', 0),
  ('80000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000002', 0),
  ('80000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-0000000000a1', '10000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000003', 0);
insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values
  ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000001', 0, 100, 5),
  ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000002', 0, 90, 8),
  ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000003', 0, 105, 5),
  ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000004', 0, 130, 3),
  ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000005', 0, 80, 10),
  ('00000000-0000-0000-0000-0000000000a1', '80000000-0000-0000-0000-000000000006', 0, 50, 10);

create schema tests;
grant usage on schema tests to authenticated;
create function tests.login(uid uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
grant execute on all functions in schema tests to authenticated;

-- ===================== copia =====================
select tests.login('00000000-0000-0000-0000-0000000000c1');
select set_config('t.clone', public.clone_mesocycle('10000000-0000-0000-0000-000000000001', '2026-12-01')::text, true);

select isnt(current_setting('t.clone')::uuid, '10000000-0000-0000-0000-000000000001'::uuid, 'la copia è un mesociclo nuovo');
select results_eq(
  $$select athlete_id, name, start_date, weeks::int, deload_weeks, status::text, coach_notes
    from public.mesocycles where id = current_setting('t.clone')::uuid$$,
  $$values ('00000000-0000-0000-0000-0000000000a1'::uuid, 'Copia di Blocco 1', '2026-12-01'::date, 4, '{4}'::smallint[], 'draft', 'Note del coach')$$,
  'stesso atleta, nome «Copia di …», nuova data, stessa durata e scarico, sempre bozza');
select is((select count(*)::int from public.sessions where mesocycle_id = current_setting('t.clone')::uuid), 1,
  'le sedute eliminate non si copiano');
select is((select name || '/' || coach_notes from public.sessions where mesocycle_id = current_setting('t.clone')::uuid),
  'Spinta/Scalda bene', 'nome e note della seduta');
select results_eq(
  $$select kind::text, rest_between_s::int, rest_after_round_s::int from public.slot_groups
    where mesocycle_id = current_setting('t.clone')::uuid$$,
  $$values ('superset', 10, 90)$$, 'tipo di gruppo e recuperi');
select results_eq(
  $$select exercise_id, coach_notes from public.slots where mesocycle_id = current_setting('t.clone')::uuid order by position$$,
  $$values ('e0000000-0000-0000-0000-0000000000e1'::uuid, 'Gomiti stretti'), ('e0000000-0000-0000-0000-0000000000e2'::uuid, null)$$,
  'gli stessi esercizi, con le note');
select is((select count(*)::int from public.set_blocks where mesocycle_id = current_setting('t.clone')::uuid), 4,
  'quattro blocchi: il blocco eliminato non si copia');
select results_eq(
  $$select role::text, technique::text, tut_eccentric_s::int, tut_bottom_pause_s::int, tut_concentric_s::int,
           tut_top_pause_s::int, rest_s::int
    from public.set_blocks where mesocycle_id = current_setting('t.clone')::uuid and role = 'top'$$,
  $$values ('top', 'none', 3, 1, 1, 0, 180)$$, 'tipo, tecnica, TUT e recupero del blocco');
select is((select count(*)::int from public.block_weeks where mesocycle_id = current_setting('t.clone')::uuid), 8,
  'prescrizioni settimanali dei blocchi copiati (non quelle del blocco eliminato)');
select results_eq(
  $$select bw.week::int, bw.sets::int, bw.reps_min::int, bw.reps_max::int, bw.method::text, bw.intensity_value::float8
    from public.block_weeks bw join public.set_blocks b on b.id = bw.block_id
    where bw.mesocycle_id = current_setting('t.clone')::uuid and b.role = 'top' order by bw.week$$,
  $$values (1, 1, 5, 5, 'BUF', 3::float8), (2, 1, 5, 5, 'BUF', 2::float8), (3, 1, 5, 5, 'BUF', 1::float8)$$,
  'serie, ripetizioni e sforzo per settimana');
select results_eq(
  $$select ref_pct::float8 from public.block_weeks bw join public.set_blocks b on b.id = bw.block_id
    where bw.mesocycle_id = current_setting('t.clone')::uuid and b.role = 'backoff' and bw.week = 1$$,
  $$values (85::float8)$$, 'percentuale del back-off');
select ok(
  (select bo.ref_block_id = tp.id
   from public.set_blocks bo, public.set_blocks tp
   where bo.mesocycle_id = current_setting('t.clone')::uuid and bo.role = 'backoff'
     and tp.mesocycle_id = current_setting('t.clone')::uuid and tp.role = 'top'),
  'il back-off è legato al top set della copia, non a quello dell''originale');
select is((select count(*)::int from public.workouts where mesocycle_id = current_setting('t.clone')::uuid), 0,
  'nessuna esecuzione nella copia');
select is((select count(*)::int from public.sessions where mesocycle_id = '10000000-0000-0000-0000-000000000001'), 2,
  'l''originale è intatto');
select is(public.weekly_muscle_volume(current_setting('t.clone')::uuid) is not null, true, 'la copia è un mesociclo normale');
select set_config('t.clone2', public.clone_mesocycle('10000000-0000-0000-0000-000000000001', '2027-01-04', '  Blocco 2  ')::text, true);
select is((select name from public.mesocycles where id = current_setting('t.clone2')::uuid), 'Blocco 2', 'nome scelto');

-- chi non è il coach dell'atleta non copia
select tests.login('00000000-0000-0000-0000-0000000000c2');
select throws_ok($$ select public.clone_mesocycle('10000000-0000-0000-0000-000000000001', '2026-12-01') $$,
  'P0002', null, 'un altro coach non vede il mesociclo, quindi non lo copia');
select tests.login('00000000-0000-0000-0000-0000000000a1');
select throws_ok($$ select public.clone_mesocycle('10000000-0000-0000-0000-000000000001', '2026-12-01') $$,
  '42501', null, 'l''atleta non copia i propri mesocicli');

-- ===================== template =====================
select tests.login('00000000-0000-0000-0000-0000000000c1');
select set_config('t.tpl', public.save_mesocycle_as_template(
  '10000000-0000-0000-0000-000000000001', '  Spinta 4 settimane  ', 'Per ipertrofia')::text, true);
select results_eq(
  $$select name, description, weeks::int, sessions::int, owner_id from public.mesocycle_templates$$,
  $$values ('Spinta 4 settimane', 'Per ipertrofia', 4, 1, '00000000-0000-0000-0000-0000000000c1'::uuid)$$,
  'il template ha nome, durata e numero di sedute');
select throws_ok($$ select public.save_mesocycle_as_template('10000000-0000-0000-0000-000000000001', 'Spinta 4 settimane') $$,
  '23505', null, 'il nome del template è unico per coach');

-- si può modificare l'originale: il template resta una copia
delete from public.block_weeks where block_id = '50000000-0000-0000-0000-000000000003';

select set_config('t.inst', public.instantiate_template(
  current_setting('t.tpl')::uuid, '00000000-0000-0000-0000-0000000000a1', '2027-02-01')::text, true);
select results_eq(
  $$select name, start_date, weeks::int, status::text from public.mesocycles where id = current_setting('t.inst')::uuid$$,
  $$values ('Spinta 4 settimane', '2027-02-01'::date, 4, 'draft')$$,
  'dal template nasce una bozza con il nome del template');
select is((select count(*)::int from public.block_weeks where mesocycle_id = current_setting('t.inst')::uuid), 8,
  'il template porta la programmazione com''era al momento del salvataggio');
select ok(
  (select bo.ref_block_id = tp.id from public.set_blocks bo, public.set_blocks tp
   where bo.mesocycle_id = current_setting('t.inst')::uuid and bo.role = 'backoff'
     and tp.mesocycle_id = current_setting('t.inst')::uuid and tp.role = 'top'),
  'anche dal template il back-off resta legato al top set');
select set_config('t.inst2', public.instantiate_template(
  current_setting('t.tpl')::uuid, '00000000-0000-0000-0000-0000000000a1', '2027-03-01', 'Altro nome')::text, true);
select is((select name from public.mesocycles where id = current_setting('t.inst2')::uuid), 'Altro nome', 'nome scelto');
select throws_ok($$ select public.instantiate_template(current_setting('t.tpl')::uuid, '00000000-0000-0000-0000-0000000000b1', '2027-02-01') $$,
  '42501', null, 'non si crea un mesociclo per l''atleta di un altro coach');
select throws_ok($$ select public.instantiate_template(current_setting('t.tpl')::uuid, '00000000-0000-0000-0000-0000000000a2', '2027-02-01') $$,
  '42501', null, 'né per un atleta con invito ancora in attesa');
select throws_ok($$ select public.instantiate_template('99999999-9999-9999-9999-999999999999', '00000000-0000-0000-0000-0000000000a1', '2027-02-01') $$,
  'P0002', null, 'template inesistente');
select throws_ok($$ insert into public.mesocycle_templates (owner_id, name, weeks, sessions, structure)
  values ('00000000-0000-0000-0000-0000000000c1', 'Rotto', 4, 0, '{"version": 2}') $$,
  '23514', null, 'una struttura non valida non si salva');

-- permessi sul template
select tests.login('00000000-0000-0000-0000-0000000000c2');
select is((select count(*)::int from public.mesocycle_templates), 0, 'un altro coach non vede i template');
select throws_ok($$ select public.instantiate_template(current_setting('t.tpl')::uuid, '00000000-0000-0000-0000-0000000000b1', '2027-02-01') $$,
  'P0002', null, 'né li usa');
select throws_ok($$ select public.save_mesocycle_as_template('10000000-0000-0000-0000-000000000001', 'Rubato') $$,
  'P0002', null, 'né salva come template il mesociclo di un altro');
select tests.login('00000000-0000-0000-0000-0000000000a1');
select is((select count(*)::int from public.mesocycle_templates), 0, 'l''atleta non vede i template del suo coach');
select throws_ok($$ select public.save_mesocycle_as_template('10000000-0000-0000-0000-000000000001', 'Mio') $$,
  '42501', null, 'l''atleta non salva template dai programmi del coach');

-- ===================== serie migliori =====================
select tests.login('00000000-0000-0000-0000-0000000000c1');
select results_eq(
  $$select exercise_name, best_load_kg::float8, best_reps::int, best_e1rm::float8, workouts, last_on = current_date
    from public.athlete_best_sets('00000000-0000-0000-0000-0000000000a1') order by exercise_name$$,
  $$values ('Croci', 50::float8, 10, 66.7::float8, 1, true), ('Panca', 105::float8, 5, 122.5::float8, 2, true)$$,
  'miglior serie per esercizio: massimale stimato più alto, riscaldamento (130×3) escluso');
select results_eq(
  $$select week::int, load_kg::float8, reps::int, e1rm::float8
    from public.top_set_history('00000000-0000-0000-0000-0000000000a1', 'e0000000-0000-0000-0000-0000000000e1') order by week$$,
  $$values (1, 100::float8, 5, 116.7::float8), (2, 105::float8, 5, 122.5::float8)$$,
  'storico: una riga per seduta con la miglior serie del giorno (in w1 vince 100×5 su 90×8)');
select is((select count(*)::int from public.top_set_history('00000000-0000-0000-0000-0000000000a1', 'e0000000-0000-0000-0000-0000000000e2')), 1,
  'uno storico per esercizio');
select is((select mesocycle_name from public.top_set_history('00000000-0000-0000-0000-0000000000a1', 'e0000000-0000-0000-0000-0000000000e2')),
  'Blocco 1', 'con il mesociclo di provenienza');

select tests.login('00000000-0000-0000-0000-0000000000c2');
select is((select count(*)::int from public.athlete_best_sets('00000000-0000-0000-0000-0000000000a1')), 0,
  'un altro coach non vede le serie dell''atleta');
select is((select count(*)::int from public.top_set_history('00000000-0000-0000-0000-0000000000a1', 'e0000000-0000-0000-0000-0000000000e1')), 0,
  'né lo storico');
select tests.login('00000000-0000-0000-0000-0000000000a1');
select is((select count(*)::int from public.athlete_best_sets('00000000-0000-0000-0000-0000000000a1')), 0,
  'l''atleta non usa la vista del coach');
select is((select count(*)::int from public.top_set_history('00000000-0000-0000-0000-0000000000a1', 'e0000000-0000-0000-0000-0000000000e1')), 0,
  'nemmeno lo storico');
select set_config('role', 'anon', true);
select throws_ok($$ select * from public.athlete_best_sets('00000000-0000-0000-0000-0000000000a1') $$, '42501', null, 'anonimo no');
select throws_ok($$ select * from public.mesocycle_templates $$, '42501', null, 'anonimo non legge i template');

select * from finish();
rollback;
