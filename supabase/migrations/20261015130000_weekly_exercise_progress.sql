-- weekly_exercise_progress(mesocycle_id): per esercizio e settimana, serie prescritte ed eseguite e
-- miglior serie registrata.
--
-- Serie di riscaldamento escluse, come in weekly_muscle_volume. La miglior serie è il segmento con la
-- stima del massimale più alta, e1RM = carico × (1 + ripetizioni / 30) (formula di Epley), tra i
-- segmenti con carico e ripetizioni. Una riga per (esercizio, settimana) con almeno una serie
-- prescritta o eseguita. security invoker: valgono le policy RLS del chiamante.

create function public.weekly_exercise_progress(p_mesocycle_id uuid)
returns table (
  exercise_id uuid,
  exercise_name text,
  week smallint,
  sets_prescribed integer,
  sets_done integer,
  top_load_kg numeric,
  top_reps smallint,
  e1rm numeric
)
language sql
stable
security invoker
set search_path = ''
as $$
  with prescribed as (
    select s.exercise_id as ex, bw.week as wk, sum(bw.sets)::int as sets
    from public.mesocycles m
    join public.block_weeks bw on bw.mesocycle_id = m.id and bw.deleted_at is null and bw.week <= m.weeks
    join public.set_blocks b on b.id = bw.block_id and b.deleted_at is null and b.role <> 'warmup'
    join public.slots s on s.id = b.slot_id and s.deleted_at is null
    join public.slot_groups g on g.id = s.group_id and g.deleted_at is null
    join public.sessions se on se.id = g.session_id and se.deleted_at is null
    where m.id = p_mesocycle_id
    group by s.exercise_id, bw.week
  ),
  logs as (
    select s.exercise_id as ex, w.week as wk, sl.id as log_id
    from public.mesocycles m
    join public.workouts w on w.mesocycle_id = m.id and w.deleted_at is null and w.week <= m.weeks
    join public.set_logs sl on sl.workout_id = w.id and sl.deleted_at is null
    join public.set_blocks b on b.id = sl.block_id and b.role <> 'warmup'
    join public.slots s on s.id = b.slot_id
    where m.id = p_mesocycle_id
  ),
  done as (
    select ex, wk, count(*)::int as sets from logs group by ex, wk
  ),
  best as (
    select distinct on (l.ex, l.wk)
      l.ex, l.wk, sg.load_kg, sg.reps, sg.load_kg * (1 + sg.reps / 30.0) as e1rm
    from logs l
    join public.set_segments sg on sg.set_log_id = l.log_id and sg.deleted_at is null
    where sg.load_kg is not null and sg.reps is not null and sg.reps > 0
    order by l.ex, l.wk, sg.load_kg * (1 + sg.reps / 30.0) desc, sg.load_kg desc
  ),
  keys as (
    select ex, wk from prescribed union select ex, wk from done
  )
  select k.ex, e.name, k.wk::smallint, coalesce(p.sets, 0), coalesce(d.sets, 0),
         bst.load_kg, bst.reps, round(bst.e1rm, 1)
  from keys k
  join public.exercises e on e.id = k.ex
  left join prescribed p on p.ex = k.ex and p.wk = k.wk
  left join done d on d.ex = k.ex and d.wk = k.wk
  left join best bst on bst.ex = k.ex and bst.wk = k.wk
  order by e.name, k.wk
$$;
