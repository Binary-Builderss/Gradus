-- Video degli esercizi: link scelti dal coach, nessun video di default.
--
-- Ogni coach aggiunge i propri link (YouTube, Vimeo, Instagram, un sito…) a qualunque esercizio che vede,
-- anche del catalogo globale, senza duplicarlo. Il link è del coach che lo ha messo: lo vede lui e i suoi atleti.
-- Il catalogo non porta video: resta così finché non si decide una fonte con i diritti a posto.
-- Sostituisce exercises.video_url (un solo link): i link già scritti vengono spostati qui.

create table public.exercise_videos (
  id uuid primary key default gen_random_uuid(),
  exercise_id uuid not null references public.exercises (id) on delete cascade,
  owner_id uuid not null references public.profiles (id) on delete cascade,
  -- Solo https: il link si apre o si incorpora nell'app, niente schemi strani né contenuti non cifrati.
  url text not null check (length(url) <= 2048 and url ~* '^https://[^\s/]+\S*$'),
  title text check (title is null or (btrim(title) <> '' and length(title) <= 120)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (exercise_id, owner_id, url)
);
create index exercise_videos_exercise_id_idx on public.exercise_videos (exercise_id);
create index exercise_videos_owner_id_idx on public.exercise_videos (owner_id);

create trigger set_updated_at before update on public.exercise_videos
  for each row execute function private.set_updated_at();
alter table public.exercise_videos enable row level security;

-- Lo vede chi l'ha messo e chi ha (o ha avuto) quel coach, come per gli esercizi.
create policy exercise_videos_select on public.exercise_videos for select to authenticated
  using (owner_id = (select auth.uid()) or private.is_coached_by(owner_id));
-- Si scrive solo per sé e su un esercizio visibile: del catalogo o proprio.
create policy exercise_videos_insert on public.exercise_videos for insert to authenticated
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.exercises e
      where e.id = exercise_id and (e.owner_id is null or e.owner_id = (select auth.uid()))
    )
  );
create policy exercise_videos_update on public.exercise_videos for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (
    owner_id = (select auth.uid())
    and exists (
      select 1 from public.exercises e
      where e.id = exercise_id and (e.owner_id is null or e.owner_id = (select auth.uid()))
    )
  );
create policy exercise_videos_delete on public.exercise_videos for delete to authenticated
  using (owner_id = (select auth.uid()));
revoke all on public.exercise_videos from anon;

-- I link già scritti passano alla nuova tabella (http diventa https: oggi tutte le piattaforme lo reggono).
insert into public.exercise_videos (exercise_id, owner_id, url)
select e.id, e.owner_id, regexp_replace(btrim(e.video_url), '^http://', 'https://', 'i')
from public.exercises e
where e.owner_id is not null
  and e.video_url is not null
  and regexp_replace(btrim(e.video_url), '^http://', 'https://', 'i') ~* '^https://[^\s/]+\S*$'
  and length(btrim(e.video_url)) <= 2048
on conflict do nothing;

alter table public.exercises drop column video_url;
