-- generate_progression(block_id, rule): riempie block_weeks di un blocco da una regola di progressione.
--
-- rule (jsonb), ogni serie di valori è { "start": n, "step": n, "min": n?, "max": n? } e la settimana
-- k-esima (k = 0 per la prima settimana calcolata) vale clamp(start + step * k, min, max):
--   sets       obbligatorio
--   reps_min   facoltativo (con reps_max: stesso valore se manca uno dei due)
--   reps_max   facoltativo
--   method     'BUF' | 'RPE' | 'RM' | 'PCT_1RM' | 'LOAD', obbligatorio se c'è intensity (e viceversa)
--   intensity  facoltativo
--   from_week, to_week  facoltativi (default: tutto il mesociclo)
--
-- Le settimane di scarico non vengono scritte e non fanno avanzare la progressione. Le settimane già
-- eseguite (con una seduta registrata) non vengono toccate, ma contano come passi. Ritorna il numero di
-- settimane scritte. security invoker: valgono le policy RLS del chiamante, un blocco altrui "non esiste".

create function private.rule_value(p_series jsonb, p_step int)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  v numeric;
begin
  if p_series is null or jsonb_typeof(p_series) <> 'object' then
    return null;
  end if;
  v := (p_series ->> 'start')::numeric + coalesce((p_series ->> 'step')::numeric, 0) * p_step;
  if p_series ? 'min' then v := greatest(v, (p_series ->> 'min')::numeric); end if;
  if p_series ? 'max' then v := least(v, (p_series ->> 'max')::numeric); end if;
  return v;
end;
$$;

create function public.generate_progression(p_block_id uuid, p_rule jsonb)
returns integer
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
  v_written int := 0;
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
      continue;
    end if;

    if not exists (
      select 1 from public.workouts
      where mesocycle_id = v_mesocycle_id and week = w and deleted_at is null
    ) then
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

      insert into public.block_weeks (mesocycle_id, block_id, week, sets, reps_min, reps_max, method, intensity_value)
      values (v_mesocycle_id, p_block_id, w, v_sets, round(v_reps_min), round(v_reps_max), v_method, v_intensity)
      on conflict (block_id, week) do update
        set sets = excluded.sets,
            reps_min = excluded.reps_min,
            reps_max = excluded.reps_max,
            method = excluded.method,
            intensity_value = excluded.intensity_value,
            deleted_at = null;
      v_written := v_written + 1;
    end if;

    v_step := v_step + 1;
  end loop;

  return v_written;
end;
$$;

revoke execute on function public.generate_progression(uuid, jsonb) from public, anon;
grant execute on function public.generate_progression(uuid, jsonb) to authenticated;
