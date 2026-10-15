-- weekly_muscle_volume(mesocycle_id): serie per muscolo e settimana, prescritte ed eseguite.
--
-- Volume = Σ serie × exercise_muscles.weight, sempre calcolato dalle righe reali (mai da un numero
-- dichiarato). Prescritto: block_weeks dentro le settimane del mesociclo, escluse le serie di
-- riscaldamento. Eseguito: una set_log = una serie (le tecniche con più segmenti restano una serie),
-- stesse esclusioni. Righe eliminate logicamente non contano. Una riga per (settimana, muscolo) che
-- abbia almeno un valore. security invoker: valgono le policy RLS del chiamante.

create function public.weekly_muscle_volume(p_mesocycle_id uuid)
returns table (week smallint, muscle public.muscle, prescribed numeric, executed numeric)
language sql
stable
security invoker
set search_path = ''
as $$
  with prescribed as (
    select bw.week as wk, em.muscle as mu, sum(bw.sets * em.weight) as v
    from public.mesocycles m
    join public.block_weeks bw on bw.mesocycle_id = m.id and bw.deleted_at is null and bw.week <= m.weeks
    join public.set_blocks b on b.id = bw.block_id and b.deleted_at is null and b.role <> 'warmup'
    join public.slots s on s.id = b.slot_id and s.deleted_at is null
    join public.slot_groups g on g.id = s.group_id and g.deleted_at is null
    join public.sessions se on se.id = g.session_id and se.deleted_at is null
    join public.exercise_muscles em on em.exercise_id = s.exercise_id
    where m.id = p_mesocycle_id
    group by bw.week, em.muscle
  ),
  executed as (
    select w.week as wk, em.muscle as mu, sum(em.weight) as v
    from public.mesocycles m
    join public.workouts w on w.mesocycle_id = m.id and w.deleted_at is null and w.week <= m.weeks
    join public.set_logs sl on sl.workout_id = w.id and sl.deleted_at is null
    join public.set_blocks b on b.id = sl.block_id and b.role <> 'warmup'
    join public.slots s on s.id = b.slot_id
    join public.exercise_muscles em on em.exercise_id = s.exercise_id
    where m.id = p_mesocycle_id
    group by w.week, em.muscle
  )
  select coalesce(p.wk, e.wk)::smallint, coalesce(p.mu, e.mu), coalesce(p.v, 0), coalesce(e.v, 0)
  from prescribed p
  full join executed e on e.wk = p.wk and e.mu = p.mu
  order by 1, 2
$$;
