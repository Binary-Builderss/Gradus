-- Ciclo di vita di un mesociclo: bozza → attivo → concluso, con le regole nel database.
--
-- L'atleta vede solo active e completed: «Attiva» è il momento in cui il coach pubblica il programma.
--   draft → active     solo se il mesociclo ha almeno una prescrizione dentro una seduta con un esercizio
--                      (mesocycle_empty) e l'atleta non ne ha già un altro attivo (athlete_has_active, con il
--                      nome di quello attivo in hint);
--   active → completed sempre;
--   active → draft     solo se l'atleta non ha registrato nulla (mesocycle_has_workouts): serve a ritirare una
--                      pubblicazione sbagliata;
--   qualsiasi altro passaggio (draft → completed, da completed a qualunque stato) non è ammesso.
-- Si applica a ogni via di scrittura, non solo al web.

create function private.check_mesocycle_status_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  other_name text;
begin
  if new.status = old.status then
    return new;
  end if;

  if old.status = 'draft' and new.status = 'active' then
    if not exists (
      select 1
      from public.block_weeks bw
      join public.set_blocks b on b.id = bw.block_id and b.deleted_at is null
      join public.slots s on s.id = b.slot_id and s.deleted_at is null
      join public.slot_groups g on g.id = s.group_id and g.deleted_at is null
      join public.sessions se on se.id = g.session_id and se.deleted_at is null
      where bw.mesocycle_id = new.id and bw.deleted_at is null and bw.week <= new.weeks
    ) then
      raise exception 'mesocycle_empty' using errcode = 'P0001';
    end if;
    select name into other_name from public.mesocycles
      where athlete_id = new.athlete_id and status = 'active' and id <> new.id;
    if found then
      raise exception 'athlete_has_active' using errcode = 'P0001', hint = other_name;
    end if;
    return new;
  end if;

  if old.status = 'active' and new.status = 'completed' then
    return new;
  end if;

  if old.status = 'active' and new.status = 'draft' then
    if exists (select 1 from public.workouts where mesocycle_id = new.id and deleted_at is null) then
      raise exception 'mesocycle_has_workouts' using errcode = 'P0001';
    end if;
    return new;
  end if;

  raise exception 'mesocycle_status_change_not_allowed' using errcode = 'P0001';
end;
$$;

create trigger check_mesocycle_status_change
  before update of status on public.mesocycles
  for each row execute function private.check_mesocycle_status_change();
