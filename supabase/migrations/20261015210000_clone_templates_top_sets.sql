-- Copia di un mesociclo, template del coach e storico delle serie migliori dell'atleta.
--
-- Un solo percorso per costruire un mesociclo da una struttura: la «fotografia» (jsonb) della programmazione.
--   clone_mesocycle        = fotografia di un mesociclo → nuova bozza per lo stesso atleta
--   save_mesocycle_as_template = fotografia → riga di mesocycle_templates (copia, mai un riferimento)
--   instantiate_template   = fotografia del template → nuova bozza per un atleta del coach
-- Si copia solo la programmazione (sedute, gruppi, esercizi, serie, prescrizioni settimanali, serie collegate), mai
-- l'esecuzione. Il risultato è sempre una bozza: l'atleta non la vede finché il coach non l'attiva.
-- Tutte security invoker: valgono le policy RLS di chi chiama (solo un coach scrive per i propri atleti).

-- ---------------------------------------------------------------------------
-- Fotografia di un mesociclo
-- ---------------------------------------------------------------------------
-- Le righe eliminate (deleted_at) non entrano. `key` è l'id del blocco di origine: serve solo a ricollegare i
-- back-off (`ref_key`) quando si ricostruisce, poi non resta da nessuna parte.
create function private.mesocycle_snapshot(p_mesocycle_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'version', 1,
    'weeks', m.weeks,
    'deload_weeks', to_jsonb(m.deload_weeks),
    'coach_notes', m.coach_notes,
    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', se.name,
        'coach_notes', se.coach_notes,
        'position', se.position,
        'groups', coalesce((
          select jsonb_agg(jsonb_build_object(
            'position', g.position,
            'kind', g.kind,
            'rest_between_s', g.rest_between_s,
            'rest_after_round_s', g.rest_after_round_s,
            'slots', coalesce((
              select jsonb_agg(jsonb_build_object(
                'position', sl.position,
                'exercise_id', sl.exercise_id,
                'coach_notes', sl.coach_notes,
                'blocks', coalesce((
                  select jsonb_agg(jsonb_build_object(
                    'key', b.id,
                    'ref_key', (select r.id from public.set_blocks r
                                where r.id = b.ref_block_id and r.deleted_at is null),
                    'position', b.position,
                    'role', b.role,
                    'technique', b.technique,
                    'technique_params', b.technique_params,
                    'tut_eccentric_s', b.tut_eccentric_s,
                    'tut_bottom_pause_s', b.tut_bottom_pause_s,
                    'tut_concentric_s', b.tut_concentric_s,
                    'tut_top_pause_s', b.tut_top_pause_s,
                    'rest_s', b.rest_s,
                    'prep_s', b.prep_s,
                    'weeks', coalesce((
                      select jsonb_agg(jsonb_build_object(
                        'week', bw.week,
                        'sets', bw.sets,
                        'reps_min', bw.reps_min,
                        'reps_max', bw.reps_max,
                        'method', bw.method,
                        'intensity_value', bw.intensity_value,
                        'ref_pct', bw.ref_pct
                      ) order by bw.week)
                      from public.block_weeks bw where bw.block_id = b.id and bw.deleted_at is null
                    ), '[]'::jsonb)
                  ) order by b.position)
                  from public.set_blocks b where b.slot_id = sl.id and b.deleted_at is null
                ), '[]'::jsonb)
              ) order by sl.position)
              from public.slots sl where sl.group_id = g.id and sl.deleted_at is null
            ), '[]'::jsonb)
          ) order by g.position)
          from public.slot_groups g where g.session_id = se.id and g.deleted_at is null
        ), '[]'::jsonb)
      ) order by se.position)
      from public.sessions se where se.mesocycle_id = m.id and se.deleted_at is null
    ), '[]'::jsonb)
  )
  from public.mesocycles m
  where m.id = p_mesocycle_id
$$;

-- ---------------------------------------------------------------------------
-- Costruzione di un mesociclo da una fotografia
-- ---------------------------------------------------------------------------
create function private.build_mesocycle(p_athlete_id uuid, p_name text, p_start_date date, p_snapshot jsonb)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_id uuid;
  v_session uuid;
  v_group uuid;
  v_slot uuid;
  v_block uuid;
  se jsonb;
  g jsonb;
  sl jsonb;
  b jsonb;
  w jsonb;
  v_keys jsonb := '{}'::jsonb;   -- id del blocco di origine → id del blocco nuovo
  r record;
begin
  if jsonb_typeof(p_snapshot) is distinct from 'object' or (p_snapshot ->> 'version') is distinct from '1'
     or jsonb_typeof(p_snapshot -> 'sessions') is distinct from 'array' then
    raise exception 'invalid mesocycle snapshot' using errcode = '22023';
  end if;

  insert into public.mesocycles (athlete_id, name, start_date, weeks, deload_weeks, status, coach_notes)
  values (
    p_athlete_id, p_name, p_start_date, (p_snapshot ->> 'weeks')::smallint,
    coalesce(array(select jsonb_array_elements_text(p_snapshot -> 'deload_weeks')::smallint), '{}'),
    'draft', p_snapshot ->> 'coach_notes')
  returning id into v_id;

  for se in select * from jsonb_array_elements(p_snapshot -> 'sessions') loop
    insert into public.sessions (mesocycle_id, position, name, coach_notes)
    values (v_id, (se ->> 'position')::smallint, se ->> 'name', se ->> 'coach_notes')
    returning id into v_session;

    for g in select * from jsonb_array_elements(se -> 'groups') loop
      insert into public.slot_groups (mesocycle_id, session_id, position, kind, rest_between_s, rest_after_round_s)
      values (v_id, v_session, (g ->> 'position')::smallint, (g ->> 'kind')::public.group_kind,
              (g ->> 'rest_between_s')::smallint, (g ->> 'rest_after_round_s')::smallint)
      returning id into v_group;

      for sl in select * from jsonb_array_elements(g -> 'slots') loop
        insert into public.slots (mesocycle_id, group_id, position, exercise_id, coach_notes)
        values (v_id, v_group, (sl ->> 'position')::smallint, (sl ->> 'exercise_id')::uuid, sl ->> 'coach_notes')
        returning id into v_slot;

        for b in select * from jsonb_array_elements(sl -> 'blocks') loop
          insert into public.set_blocks (
            mesocycle_id, slot_id, position, role, technique, technique_params,
            tut_eccentric_s, tut_bottom_pause_s, tut_concentric_s, tut_top_pause_s, rest_s, prep_s)
          values (
            v_id, v_slot, (b ->> 'position')::smallint, (b ->> 'role')::public.block_role,
            (b ->> 'technique')::public.technique, coalesce(b -> 'technique_params', '{}'::jsonb),
            (b ->> 'tut_eccentric_s')::smallint, (b ->> 'tut_bottom_pause_s')::smallint,
            (b ->> 'tut_concentric_s')::smallint, (b ->> 'tut_top_pause_s')::smallint,
            (b ->> 'rest_s')::smallint, (b ->> 'prep_s')::smallint)
          returning id into v_block;
          v_keys := v_keys || jsonb_build_object(b ->> 'key', v_block);

          for w in select * from jsonb_array_elements(b -> 'weeks') loop
            insert into public.block_weeks (
              mesocycle_id, block_id, week, sets, reps_min, reps_max, method, intensity_value, ref_pct)
            values (
              v_id, v_block, (w ->> 'week')::smallint, (w ->> 'sets')::smallint,
              (w ->> 'reps_min')::smallint, (w ->> 'reps_max')::smallint,
              (w ->> 'method')::public.intensity_method, (w ->> 'intensity_value')::numeric,
              (w ->> 'ref_pct')::numeric);
          end loop;
        end loop;
      end loop;
    end loop;
  end loop;

  -- i back-off si ricollegano ai blocchi nuovi, dopo che esistono tutti
  for r in
    select s.key, s.ref_key
    from (
      select b2 ->> 'key' as key, b2 ->> 'ref_key' as ref_key
      from jsonb_array_elements(p_snapshot -> 'sessions') se2,
           jsonb_array_elements(se2 -> 'groups') g2,
           jsonb_array_elements(g2 -> 'slots') sl2,
           jsonb_array_elements(sl2 -> 'blocks') b2
    ) s
    where s.ref_key is not null and v_keys ? s.key and v_keys ? s.ref_key
  loop
    update public.set_blocks set ref_block_id = (v_keys ->> r.ref_key)::uuid
    where id = (v_keys ->> r.key)::uuid;
  end loop;

  return v_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Copia di un mesociclo (stesso atleta)
-- ---------------------------------------------------------------------------
create function public.clone_mesocycle(p_mesocycle_id uuid, p_start_date date, p_name text default null)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_athlete uuid;
  v_name text;
begin
  select athlete_id, name into v_athlete, v_name
  from public.mesocycles where id = p_mesocycle_id;
  if not found then
    raise exception 'mesocycle not found' using errcode = 'P0002';
  end if;
  return private.build_mesocycle(
    v_athlete,
    coalesce(nullif(btrim(p_name), ''), left('Copia di ' || v_name, 120)),
    p_start_date,
    private.mesocycle_snapshot(p_mesocycle_id));
end;
$$;

-- ---------------------------------------------------------------------------
-- Template del coach
-- ---------------------------------------------------------------------------
create table public.mesocycle_templates (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (btrim(name) <> '' and length(name) <= 120),
  description text check (description is null or length(description) <= 500),
  -- per l'elenco, senza aprire la fotografia
  weeks smallint not null check (weeks between 1 and 52),
  sessions smallint not null check (sessions >= 0),
  structure jsonb not null check (
    jsonb_typeof(structure) = 'object' and structure ->> 'version' = '1'
    and jsonb_typeof(structure -> 'sessions') = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, name)
);

create trigger set_updated_at before update on public.mesocycle_templates
  for each row execute function private.set_updated_at();
alter table public.mesocycle_templates enable row level security;

create policy mesocycle_templates_select on public.mesocycle_templates for select to authenticated
  using (owner_id = (select auth.uid()));
create policy mesocycle_templates_insert on public.mesocycle_templates for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy mesocycle_templates_update on public.mesocycle_templates for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy mesocycle_templates_delete on public.mesocycle_templates for delete to authenticated
  using (owner_id = (select auth.uid()));
revoke all on public.mesocycle_templates from anon;

-- Salva la programmazione di un mesociclo (di un atleta del coach) come template.
create function public.save_mesocycle_as_template(p_mesocycle_id uuid, p_name text, p_description text default null)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_athlete uuid;
  v_snapshot jsonb;
  v_id uuid;
begin
  select athlete_id into v_athlete from public.mesocycles where id = p_mesocycle_id;
  if not found then
    raise exception 'mesocycle not found' using errcode = 'P0002';
  end if;
  if not private.is_coach_of(v_athlete) then
    raise exception 'only the coach of the athlete can save a template' using errcode = '42501';
  end if;
  v_snapshot := private.mesocycle_snapshot(p_mesocycle_id);
  insert into public.mesocycle_templates (owner_id, name, description, weeks, sessions, structure)
  values (
    (select auth.uid()), btrim(p_name), nullif(btrim(p_description), ''),
    (v_snapshot ->> 'weeks')::smallint, jsonb_array_length(v_snapshot -> 'sessions'), v_snapshot)
  returning id into v_id;
  return v_id;
end;
$$;

-- Nuova bozza per un atleta del coach, copiata dal template.
create function public.instantiate_template(
  p_template_id uuid, p_athlete_id uuid, p_start_date date, p_name text default null)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  t public.mesocycle_templates;
begin
  select * into t from public.mesocycle_templates where id = p_template_id;
  if not found then
    raise exception 'template not found' using errcode = 'P0002';
  end if;
  return private.build_mesocycle(
    p_athlete_id, coalesce(nullif(btrim(p_name), ''), t.name), p_start_date, t.structure);
end;
$$;

-- ---------------------------------------------------------------------------
-- Serie migliori dell'atleta (solo per il suo coach)
-- ---------------------------------------------------------------------------
-- Stessa regola di weekly_exercise_progress: riscaldamento escluso, il segmento con la stima del massimale più
-- alta, e1RM = carico × (1 + ripetizioni / 30). Attraversano tutti i mesocicli dell'atleta.

-- Una riga per esercizio: la miglior serie di sempre, quante sedute e quando l'ultima.
create function public.athlete_best_sets(p_athlete_id uuid)
returns table (
  exercise_id uuid,
  exercise_name text,
  best_load_kg numeric,
  best_reps smallint,
  best_e1rm numeric,
  best_on date,
  workouts integer,
  last_on date
)
language sql
stable
security invoker
set search_path = ''
as $$
  with sets as (
    select s.exercise_id as ex, w.id as workout_id, sl.done_at::date as day,
           sg.load_kg, sg.reps, sg.load_kg * (1 + sg.reps / 30.0) as e1rm
    from public.workouts w
    join public.set_logs sl on sl.workout_id = w.id and sl.deleted_at is null
    join public.set_blocks b on b.id = sl.block_id and b.role <> 'warmup'
    join public.slots s on s.id = b.slot_id
    join public.set_segments sg on sg.set_log_id = sl.id and sg.deleted_at is null
    where w.athlete_id = p_athlete_id
      and w.deleted_at is null
      and private.is_coach_of(p_athlete_id)
      and sg.load_kg is not null and sg.reps is not null and sg.reps > 0
  ),
  best as (
    select distinct on (ex) ex, load_kg, reps, e1rm, day
    from sets
    order by ex, e1rm desc, load_kg desc, day desc
  ),
  totals as (
    select ex, count(distinct workout_id)::int as n, max(day) as last_day from sets group by ex
  )
  select e.id, e.name, b.load_kg, b.reps, round(b.e1rm, 1), b.day, t.n, t.last_day
  from best b
  join totals t on t.ex = b.ex
  join public.exercises e on e.id = b.ex
  order by t.last_day desc, e.name
$$;

-- Una riga per seduta in cui l'atleta ha fatto quell'esercizio: la sua miglior serie di quel giorno.
create function public.top_set_history(p_athlete_id uuid, p_exercise_id uuid)
returns table (
  workout_id uuid,
  mesocycle_id uuid,
  mesocycle_name text,
  week smallint,
  performed_on date,
  load_kg numeric,
  reps smallint,
  e1rm numeric
)
language sql
stable
security invoker
set search_path = ''
as $$
  select distinct on (w.id)
    w.id, m.id, m.name, w.week, sl.done_at::date, sg.load_kg, sg.reps,
    round(sg.load_kg * (1 + sg.reps / 30.0), 1)
  from public.workouts w
  join public.mesocycles m on m.id = w.mesocycle_id
  join public.set_logs sl on sl.workout_id = w.id and sl.deleted_at is null
  join public.set_blocks b on b.id = sl.block_id and b.role <> 'warmup'
  join public.slots s on s.id = b.slot_id and s.exercise_id = p_exercise_id
  join public.set_segments sg on sg.set_log_id = sl.id and sg.deleted_at is null
  where w.athlete_id = p_athlete_id
    and w.deleted_at is null
    and private.is_coach_of(p_athlete_id)
    and sg.load_kg is not null and sg.reps is not null and sg.reps > 0
  order by w.id, sg.load_kg * (1 + sg.reps / 30.0) desc, sg.load_kg desc
$$;

revoke execute on function private.mesocycle_snapshot(uuid), private.build_mesocycle(uuid, text, date, jsonb)
  from public, anon;
grant execute on function private.mesocycle_snapshot(uuid), private.build_mesocycle(uuid, text, date, jsonb)
  to authenticated;
revoke execute on function public.clone_mesocycle(uuid, date, text),
  public.save_mesocycle_as_template(uuid, text, text),
  public.instantiate_template(uuid, uuid, date, text),
  public.athlete_best_sets(uuid),
  public.top_set_history(uuid, uuid)
  from public, anon;
grant execute on function public.clone_mesocycle(uuid, date, text),
  public.save_mesocycle_as_template(uuid, text, text),
  public.instantiate_template(uuid, uuid, date, text),
  public.athlete_best_sets(uuid),
  public.top_set_history(uuid, uuid)
  to authenticated;
