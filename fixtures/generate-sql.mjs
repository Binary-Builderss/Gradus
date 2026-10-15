#!/usr/bin/env node
// Genera i test pgTAP dalle fixture condivise (stessi casi dei test Swift).
//   node fixtures/generate-sql.mjs          scrive supabase/tests/previous_week_fixtures.test.sql e backoff_fixtures.test.sql
//   node fixtures/generate-sql.mjs --check  non scrive: esce con errore se un file non è aggiornato (CI)
import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const fixture = (name) => join(root, 'fixtures', name)
const testFile = (name) => join(root, 'supabase', 'tests', name)

const q = (s) => `'${String(s).replaceAll("'", "''")}'`
const pad = (n, len) => String(n).padStart(len, '0')
/** UUID deterministico: `kind` (una cifra esadecimale) + numero del caso + progressivo. */
const uuid = (kind, caseNo, n) => `${kind}${pad(caseNo, 7)}-0000-4000-8000-${pad(n, 12)}`
const sqlNumber = (n) => (n === null || n === undefined ? 'null' : String(n))

function buildPreviousWeek() {
  const { cases } = JSON.parse(readFileSync(fixture('previous_week_cases.json'), 'utf8'))
  const out = []
  const emit = (s = '') => out.push(s)

  emit('-- GENERATO da fixtures/generate-sql.mjs a partire da fixtures/previous_week_cases.json: non modificare a mano.')
  emit('-- previous_week_reference: gli stessi casi della fixture che passa anche l\'implementazione Swift.')
  emit('')
  emit('begin;')
  emit('create extension if not exists pgtap with schema extensions;')
  emit(`select plan(${cases.length});`)
  emit('')
  emit('create schema tests;')
  emit('grant usage on schema tests to authenticated;')
  emit('create function tests.login(uid uuid) returns void language sql as $$')
  emit("  select set_config('role', 'authenticated', true),")
  emit("         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);")
  emit('$$;')
  emit('grant execute on all functions in schema tests to authenticated;')
  emit('')
  emit(`insert into public.exercises (id, owner_id, name) values ('e0000000-0000-4000-8000-000000000001', null, 'Esercizio di prova') on conflict do nothing;`)
  emit('')

  const asserts = []
  cases.forEach((c, idx) => {
    const no = idx + 1
    const { input: inp } = c
    const athlete = uuid('a', no, 1)
    const meso = uuid('b', no, 1)
    const prevMeso = uuid('c', no, 1)
    const sessions = { main: uuid('d', no, 1), other: uuid('e', no, 1), prev: uuid('f', no, 1) }
    const mesoOf = { main: meso, other: meso, prev: prevMeso }
    const blockKind = { main: '3', other: '4', prev: '5' }
    const blockId = (which, name) => uuid(blockKind[which], no, inp.blocks.indexOf(name) + 1)
    const hasPrev = (inp.previous_mesocycle_logs ?? []).length > 0

    emit(`-- ${no}. ${c.name.replaceAll('\n', ' ')}`)
    emit(`insert into auth.users (id, email) values (${q(athlete)}, ${q(`caso${no}@fixture.test`)});`)
    const deload = `'{${inp.deload_weeks.join(',')}}'`
    emit(
      `insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values (${q(meso)}, ${q(athlete)}, ${q(`Caso ${no}`)}, '2026-01-05', ${inp.weeks}, ${deload}, 'active');`,
    )
    if (hasPrev)
      emit(
        `insert into public.mesocycles (id, athlete_id, name, start_date, weeks, deload_weeks, status) values (${q(prevMeso)}, ${q(athlete)}, ${q(`Caso ${no} precedente`)}, '2025-10-06', ${inp.weeks}, ${deload}, 'completed');`,
      )
    const used = ['main', 'other', ...(hasPrev ? ['prev'] : [])]
    used.forEach((which, k) => {
      const group = uuid('1', no, k + 1)
      const slot = uuid('2', no, k + 1)
      emit(`insert into public.sessions (id, mesocycle_id, position, name) values (${q(sessions[which])}, ${q(mesoOf[which])}, ${k}, ${q(which)});`)
      emit(`insert into public.slot_groups (id, mesocycle_id, session_id, position) values (${q(group)}, ${q(mesoOf[which])}, ${q(sessions[which])}, 0);`)
      emit(`insert into public.slots (id, mesocycle_id, group_id, position, exercise_id) values (${q(slot)}, ${q(mesoOf[which])}, ${q(group)}, 0, 'e0000000-0000-4000-8000-000000000001');`)
      inp.blocks.forEach((name, j) =>
        emit(`insert into public.set_blocks (id, mesocycle_id, slot_id, position, role) values (${q(blockId(which, name))}, ${q(mesoOf[which])}, ${q(slot)}, ${j}, 'working');`),
      )
    })

    let logCounter = 0
    const logsOf = { main: inp.logs ?? [], other: inp.other_session_logs ?? [], prev: inp.previous_mesocycle_logs ?? [] }
    used.forEach((which, k) => {
      const weeks = [...new Set(logsOf[which].map((l) => l.week))].sort((a, b) => a - b)
      for (const week of weeks) {
        const workout = uuid('6', no, 1000 * (k + 1) + week)
        emit(
          `insert into public.workouts (id, athlete_id, mesocycle_id, session_id, week) values (${q(workout)}, ${q(athlete)}, ${q(mesoOf[which])}, ${q(sessions[which])}, ${week});`,
        )
        for (const log of logsOf[which].filter((l) => l.week === week)) {
          logCounter += 1
          const logId = uuid('7', no, logCounter)
          const effort = log.effort
          emit(
            `insert into public.set_logs (id, athlete_id, mesocycle_id, workout_id, block_id, set_idx, effort_value, effort_scale) values (${q(logId)}, ${q(athlete)}, ${q(mesoOf[which])}, ${q(workout)}, ${q(blockId(which, log.block))}, ${log.set_idx}, ${sqlNumber(effort?.value)}, ${effort ? `${q(effort.scale)}::public.effort_scale` : 'null'});`,
          )
          log.segments.forEach((s, segIdx) =>
            emit(
              `insert into public.set_segments (athlete_id, set_log_id, seg_idx, load_kg, reps) values (${q(athlete)}, ${q(logId)}, ${segIdx}, ${sqlNumber(s.load_kg)}, ${sqlNumber(s.reps)});`,
            ),
          )
        }
      }
    })
    emit('')

    const expected = c.expected.map((e) => ({
      block_id: blockId('main', e.block),
      set_idx: e.set_idx,
      week: e.week,
      segments: e.segments,
      effort: e.effort,
    }))
    asserts.push(
      [
        `select tests.login(${q(athlete)});`,
        'select is(',
        "  (select coalesce(jsonb_agg(jsonb_build_object('block_id', r.block_id, 'set_idx', r.set_idx, 'week', r.ref_week,",
        "           'segments', r.segments,",
        "           'effort', case when r.effort_value is null then null",
        "                          else jsonb_build_object('value', r.effort_value, 'scale', r.effort_scale::text) end)",
        "         order by r.n), '[]'::jsonb)",
        `   from public.previous_week_reference(${q(sessions.main)}, ${inp.week}) with ordinality as r(block_id, set_idx, ref_week, segments, effort_value, effort_scale, n)),`,
        `  ${q(JSON.stringify(expected))}::jsonb,`,
        `  ${q(c.name)});`,
        '',
      ].join('\n'),
    )
  })

  out.push(...asserts)
  emit('select * from finish();')
  emit('rollback;')
  return out.join('\n') + '\n'
}

function buildBackoff() {
  const { cases } = JSON.parse(readFileSync(fixture('backoff_cases.json'), 'utf8'))
  const out = [
    '-- GENERATO da fixtures/generate-sql.mjs a partire da fixtures/backoff_cases.json: non modificare a mano.',
    "-- backoff_target_load: gli stessi casi della fixture che passa anche l'implementazione Swift.",
    '',
    'begin;',
    'create extension if not exists pgtap with schema extensions;',
    `select plan(${cases.length});`,
    '',
  ]
  for (const c of cases)
    out.push(
      `select is(public.backoff_target_load(${c.input.top_load_kg}, ${c.input.ref_pct}), ${c.expected.target_kg}::numeric, ${q(c.name)});`,
    )
  out.push('', 'select * from finish();', 'rollback;')
  return out.join('\n') + '\n'
}

const outputs = [
  [testFile('previous_week_fixtures.test.sql'), buildPreviousWeek()],
  [testFile('backoff_fixtures.test.sql'), buildBackoff()],
]
let stale = false
for (const [file, content] of outputs) {
  if (process.argv.includes('--check')) {
    const current = existsSync(file) ? readFileSync(file, 'utf8') : ''
    if (current !== content) {
      console.error(`${file} non è aggiornato: esegui \`node fixtures/generate-sql.mjs\`.`)
      stale = true
    }
  } else {
    writeFileSync(file, content)
    console.log(`Scritto ${file}`)
  }
}
if (stale) process.exit(1)
if (process.argv.includes('--check')) console.log('I test SQL generati sono aggiornati.')
