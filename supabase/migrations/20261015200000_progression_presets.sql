-- Modelli di progressione: regole di progressione (le stesse di generate_progression) salvate dal coach con un nome,
-- per riusarle su altre serie e altri mesocicli. Sono del coach e solo suoi: l'atleta non li vede.
-- La regola è il jsonb di generate_progression/preview_progression: il web la compila nel modulo, la applica con
-- quelle funzioni e il calcolo resta uno solo.

-- Una serie di valori: parte da `start`, cambia di `step` a settimana, tra `min` e `max`.
create function private.valid_progression_series(p_series jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select coalesce(
    jsonb_typeof(p_series) = 'object'
    and jsonb_typeof(p_series -> 'start') = 'number'
    and not exists (
      select 1 from jsonb_each(p_series) e
      where e.key not in ('start', 'step', 'min', 'max') or jsonb_typeof(e.value) <> 'number'
    ),
    false);
$$;

-- Solo le chiavi che generate_progression conosce, con la forma giusta. I limiti che dipendono dal mesociclo
-- (settimane oltre la durata, ripetizioni invertite) restano alla funzione, che li verifica quando si applica.
create function private.valid_progression_rule(p_rule jsonb)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  k text;
  v_from numeric;
  v_to numeric;
begin
  if jsonb_typeof(p_rule) is distinct from 'object' then return false; end if;
  for k in select jsonb_object_keys(p_rule) loop
    if k not in ('sets', 'reps_min', 'reps_max', 'method', 'intensity', 'from_week', 'to_week') then
      return false;
    end if;
  end loop;

  if not private.valid_progression_series(p_rule -> 'sets') then return false; end if;
  if p_rule ? 'reps_min' and not private.valid_progression_series(p_rule -> 'reps_min') then return false; end if;
  if p_rule ? 'reps_max' and not private.valid_progression_series(p_rule -> 'reps_max') then return false; end if;

  -- metodo e valore vanno insieme
  if (p_rule ? 'method') <> (p_rule ? 'intensity') then return false; end if;
  if p_rule ? 'method' then
    if jsonb_typeof(p_rule -> 'method') <> 'string'
       or (p_rule ->> 'method') not in ('BUF', 'RPE', 'RM', 'PCT_1RM', 'LOAD') then
      return false;
    end if;
    if not private.valid_progression_series(p_rule -> 'intensity') then return false; end if;
  end if;

  if p_rule ? 'from_week' then
    if jsonb_typeof(p_rule -> 'from_week') <> 'number' then return false; end if;
    v_from := (p_rule ->> 'from_week')::numeric;
    if v_from <> trunc(v_from) or v_from < 1 or v_from > 52 then return false; end if;
  end if;
  if p_rule ? 'to_week' then
    if jsonb_typeof(p_rule -> 'to_week') <> 'number' then return false; end if;
    v_to := (p_rule ->> 'to_week')::numeric;
    if v_to <> trunc(v_to) or v_to < 1 or v_to > 52 then return false; end if;
  end if;
  if v_from is not null and v_to is not null and v_from > v_to then return false; end if;
  return true;
end;
$$;

create table public.progression_presets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  name text not null check (btrim(name) <> '' and length(name) <= 80),
  rule jsonb not null check (private.valid_progression_rule(rule)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, name)
);

create trigger set_updated_at before update on public.progression_presets
  for each row execute function private.set_updated_at();
alter table public.progression_presets enable row level security;

create policy progression_presets_select on public.progression_presets for select to authenticated
  using (owner_id = (select auth.uid()));
create policy progression_presets_insert on public.progression_presets for insert to authenticated
  with check (owner_id = (select auth.uid()));
create policy progression_presets_update on public.progression_presets for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy progression_presets_delete on public.progression_presets for delete to authenticated
  using (owner_id = (select auth.uid()));
revoke all on public.progression_presets from anon;

revoke execute on function private.valid_progression_series(jsonb), private.valid_progression_rule(jsonb)
  from public, anon;
grant execute on function private.valid_progression_series(jsonb), private.valid_progression_rule(jsonb)
  to authenticated;
