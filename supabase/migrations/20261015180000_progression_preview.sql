-- Anteprima della progressione: stesso calcolo di generate_progression, senza scrivere.
--
-- Il calcolo sta in un'unica funzione, private.progression_plan, che dice per ogni settimana dell'intervallo cosa
-- succederebbe: 'write' (si scrive), 'deload' (settimana di scarico: saltata e non conta come passo) o 'locked'
-- (settimana già eseguita: intatta, ma conta come passo). generate_progression scrive le righe 'write';
-- preview_progression le mostra tutte. Così l'anteprima del web non può divergere da ciò che poi viene scritto.
-- security invoker: valgono le policy RLS di chi chiama (un blocco altrui «non esiste»).

create function private.progression_plan(p_block_id uuid, p_rule jsonb)
returns table (
  week integer,
  action text,
  sets integer,
  reps_min smallint,
  reps_max smallint,
  method public.intensity_method,
  intensity_value numeric
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_mesocycle_id uuid;
  v_weeks int;
  v_deload smallint[];
  v_from int;
  v_to int;
  v_method public.intensity_method;
  v_step int := 0;
  v_sets numeric;
  v_reps_min numeric;
  v_reps_max numeric;
  v_intensity numeric;
  w int;
begin
  select m.id, m.weeks, m.deload_weeks
    into v_mesocycle_id, v_weeks, v_deload
  from public.set_blocks b
  join public.mesocycles m on m.id = b.mesocycle_id
  where b.id = p_block_id and b.deleted_at is null;
  if not found then
    raise exception 'block not found' using errcode = 'P0002';
  end if;

  if p_rule is null or jsonb_typeof(p_rule) <> 'object' or jsonb_typeof(p_rule -> 'sets') is distinct from 'object' then
    raise exception 'rule must be an object with a "sets" series' using errcode = '22023';
  end if;
  if (p_rule ->> 'method' is null) <> (p_rule -> 'intensity' is null) then
    raise exception 'method and intensity go together' using errcode = '22023';
  end if;
  v_method := (p_rule ->> 'method')::public.intensity_method;

  v_from := coalesce((p_rule ->> 'from_week')::int, 1);
  v_to := coalesce((p_rule ->> 'to_week')::int, v_weeks);
  if v_from < 1 or v_to > v_weeks or v_from > v_to then
    raise exception 'weeks must satisfy 1 <= from_week <= to_week <= %', v_weeks using errcode = '22023';
  end if;

  for w in v_from .. v_to loop
    if w = any (v_deload) then
      week := w; action := 'deload';
      sets := null; reps_min := null; reps_max := null; method := null; intensity_value := null;
      return next;
      continue;
    end if;

    v_sets := private.rule_value(p_rule -> 'sets', v_step);
    v_reps_min := private.rule_value(p_rule -> 'reps_min', v_step);
    v_reps_max := private.rule_value(p_rule -> 'reps_max', v_step);
    v_intensity := private.rule_value(p_rule -> 'intensity', v_step);
    -- un solo estremo delle ripetizioni: vale per entrambi
    v_reps_min := coalesce(v_reps_min, v_reps_max);
    v_reps_max := coalesce(v_reps_max, v_reps_min);

    if v_sets < 0 or v_sets <> trunc(v_sets) then
      raise exception 'sets must be a non-negative integer (week %)', w using errcode = '22023';
    end if;
    if round(v_reps_min) > round(v_reps_max) then
      raise exception 'reps_min must not exceed reps_max (week %)', w using errcode = '23514';
    end if;

    week := w;
    action := case when exists (
      select 1 from public.workouts
      where mesocycle_id = v_mesocycle_id and workouts.week = w and deleted_at is null
    ) then 'locked' else 'write' end;
    sets := v_sets::int;
    reps_min := round(v_reps_min);
    reps_max := round(v_reps_max);
    method := v_method;
    intensity_value := v_intensity;
    return next;

    v_step := v_step + 1;
  end loop;
end;
$$;

create or replace function public.generate_progression(p_block_id uuid, p_rule jsonb)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_mesocycle_id uuid;
  v_written int := 0;
  r record;
begin
  select mesocycle_id into v_mesocycle_id
  from public.set_blocks where id = p_block_id and deleted_at is null;

  for r in select * from private.progression_plan(p_block_id, p_rule) p where p.action = 'write' loop
    insert into public.block_weeks (mesocycle_id, block_id, week, sets, reps_min, reps_max, method, intensity_value)
    values (v_mesocycle_id, p_block_id, r.week, r.sets, r.reps_min, r.reps_max, r.method, r.intensity_value)
    on conflict (block_id, week) do update
      set sets = excluded.sets,
          reps_min = excluded.reps_min,
          reps_max = excluded.reps_max,
          method = excluded.method,
          intensity_value = excluded.intensity_value,
          deleted_at = null;
    v_written := v_written + 1;
  end loop;

  return v_written;
end;
$$;

create function public.preview_progression(p_block_id uuid, p_rule jsonb)
returns table (
  week integer,
  action text,
  sets integer,
  reps_min smallint,
  reps_max smallint,
  method public.intensity_method,
  intensity_value numeric
)
language sql
security invoker
set search_path = ''
as $$
  select * from private.progression_plan(p_block_id, p_rule);
$$;

revoke execute on function private.progression_plan(uuid, jsonb) from public, anon;
grant execute on function private.progression_plan(uuid, jsonb) to authenticated;
revoke execute on function public.preview_progression(uuid, jsonb) from public, anon;
grant execute on function public.preview_progression(uuid, jsonb) to authenticated;
