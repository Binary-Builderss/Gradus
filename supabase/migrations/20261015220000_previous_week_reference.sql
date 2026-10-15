-- previous_week_reference(session_id, week): cosa ha fatto l'atleta, serie per serie, la settimana di riferimento
-- della stessa seduta. È la regola che l'app iOS ripete in Swift (serve offline); i casi comuni stanno in
-- /fixtures/previous_week_cases.json e il test pgTAP `previous_week_fixtures.test.sql` è generato da quel file
-- (fixtures/generate-sql.mjs): chi cambia la regola aggiorna fixture, SQL e Swift insieme.
--
-- Regole (specifiche, «Riferimento alla settimana precedente»):
--   · settimana 1 → nessun riferimento;
--   · si cerca a ritroso la prima settimana prima di N che non è di scarico (le settimane di scarico sono
--     escluse dalla ricerca); con N−1 normale è semplicemente N−1;
--   · stessa seduta, stessi blocchi, stessa serie (set_idx), dentro il mesociclo della seduta;
--   · se in quella settimana la seduta non ha dati (saltata) → nessun riferimento, non si risale oltre;
--   · mai dati di un mesociclo precedente (le sedute e i blocchi appartengono a un solo mesociclo).
-- Prende la seduta e la settimana, non un workout: le righe di esecuzione esistono solo con dati reali, quindi
-- prima della prima serie il workout della settimana N non c'è ancora. security invoker: valgono le policy RLS
-- (l'atleta legge le proprie serie, il coach quelle dei suoi atleti).

create function public.previous_week_reference(p_session_id uuid, p_week integer)
returns table (
  block_id uuid,
  set_idx smallint,
  ref_week smallint,
  segments jsonb,
  effort_value numeric,
  effort_scale public.effort_scale
)
language sql
stable
security invoker
set search_path = ''
as $$
  with target as (
    select se.id as session_id, m.id as mesocycle_id, m.deload_weeks
    from public.sessions se
    join public.mesocycles m on m.id = se.mesocycle_id
    where se.id = p_session_id and se.deleted_at is null
  ),
  ref as (
    select t.session_id, t.mesocycle_id, max(w) as week
    from target t
    cross join lateral generate_series(1, p_week - 1) w
    where not (w = any (t.deload_weeks))
    group by t.session_id, t.mesocycle_id
  )
  select sl.block_id, sl.set_idx, wo.week,
         coalesce((
           select jsonb_agg(jsonb_build_object('load_kg', sg.load_kg, 'reps', sg.reps) order by sg.seg_idx)
           from public.set_segments sg
           where sg.set_log_id = sl.id and sg.deleted_at is null
         ), '[]'::jsonb),
         sl.effort_value, sl.effort_scale
  from ref r
  join public.workouts wo
    on wo.session_id = r.session_id and wo.mesocycle_id = r.mesocycle_id
   and wo.week = r.week and wo.deleted_at is null
  join public.set_logs sl on sl.workout_id = wo.id and sl.deleted_at is null
  join public.set_blocks b on b.id = sl.block_id and b.deleted_at is null
  join public.slots sx on sx.id = b.slot_id and sx.deleted_at is null
  join public.slot_groups g on g.id = sx.group_id and g.deleted_at is null and g.session_id = r.session_id
  order by g.position, sx.position, b.position, sl.set_idx
$$;

revoke execute on function public.previous_week_reference(uuid, integer) from public, anon;
grant execute on function public.previous_week_reference(uuid, integer) to authenticated;
