-- Nutrizione: i macro oggi, la dieta domani.
--
-- Chi scrive cosa (un solo autore per dato):
--   - nutrition_plans / nutrition_plan_days: gli obiettivi li scrive il coach collegato all'atleta (web). Un piano vale
--     da `valid_from` finché non ne arriva uno più recente. Ogni piano porta la dichiarazione del coach («questi obiettivi
--     mi sono stati forniti da un professionista abilitato»), con data e versione del testo.
--   - nutrition_days: l'aderenza giornaliera la scrive l'atleta (app): rispettato / non rispettato, la fonte
--     (conferma, Apple Salute, a mano) e i macro assunti se noti. Nessuna riga = giorno non registrato.
--
-- Predisposizione per la dieta: nutrition_plans.kind ('macros' | 'diet'). La dieta compilabile non esiste ancora e
-- arriverà solo per un professionista verificato: finché non c'è la verifica, kind = 'diet' è rifiutato.
--
-- Privacy: sono dati sulla salute. L'atleta deve aver dato il consenso esplicito (profiles.nutrition_consent_at) per
-- scriverli, e il coach li legge solo con quel consenso. Ritirarlo cancella i giorni registrati
-- (withdraw_nutrition_consent). Dall'app escono solo i totali giornalieri, mai i singoli alimenti.

create type public.nutrition_kind as enum ('macros', 'diet');
create type public.nutrition_day_type as enum ('all', 'training', 'rest');
create type public.nutrition_day_status as enum ('respected', 'not_respected');
create type public.nutrition_source as enum ('confirm', 'healthkit', 'manual');

alter table public.profiles
  add column nutrition_consent_at timestamptz,
  add column nutrition_consent_version text;

-- Il consenso dell'atleta a trattare e condividere i dati nutrizionali. Security definer: lo chiamano le policy per
-- conto del coach, che non può leggere il consenso di un altro profilo.
create function private.has_nutrition_consent(p_athlete_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles where id = p_athlete_id and nutrition_consent_at is not null
  );
$$;

-- ---------------------------------------------------------------------------
-- Obiettivi (scrive il coach)
-- ---------------------------------------------------------------------------

create table public.nutrition_plans (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.profiles (id) on delete cascade,
  -- Chi li ha scritti. Se il coach cancella l'account il piano resta all'atleta, senza autore.
  author_id uuid references public.profiles (id) on delete set null,
  kind public.nutrition_kind not null default 'macros',
  -- Vale da questo giorno finché non ne arriva uno più recente.
  valid_from date not null,
  -- Scarto accettato sui macro assunti, in percentuale, per dire «rispettato».
  tolerance_pct smallint not null default 10 check (tolerance_pct between 0 and 50),
  declared_at timestamptz not null,
  declaration_version text not null check (btrim(declaration_version) <> ''),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
-- Un solo piano per atleta, tipo e giorno di inizio (tra quelli non eliminati).
create unique index nutrition_plans_start_key
  on public.nutrition_plans (athlete_id, kind, valid_from) where deleted_at is null;
create index nutrition_plans_athlete_id_idx on public.nutrition_plans (athlete_id);

create table public.nutrition_plan_days (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.nutrition_plans (id) on delete cascade,
  -- Oggi un solo obiettivo per giorno ('all'); giorni di allenamento e di riposo diversi sono una decisione aperta.
  day_type public.nutrition_day_type not null default 'all' check (day_type = 'all'),
  kcal integer not null check (kcal between 500 and 15000),
  protein_g integer not null check (protein_g between 0 and 1000),
  carbs_g integer not null check (carbs_g between 0 and 2000),
  fat_g integer not null check (fat_g between 0 and 1000),
  fiber_g integer check (fiber_g is null or fiber_g between 0 and 300),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (plan_id, day_type)
);

-- La dieta compilabile non c'è ancora: finché non esiste la verifica del professionista nessuno può scriverla.
create function private.reject_unavailable_kind()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.kind = 'diet' then
    raise exception 'diet_requires_verified_professional' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger reject_unavailable_kind before insert or update on public.nutrition_plans
  for each row execute function private.reject_unavailable_kind();

-- ---------------------------------------------------------------------------
-- Aderenza giornaliera (scrive l'atleta)
-- ---------------------------------------------------------------------------

create table public.nutrition_days (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  status public.nutrition_day_status not null,
  source public.nutrition_source not null,
  -- Macro assunti: null se l'atleta ha solo confermato e non li ha inseriti.
  kcal numeric(7, 1) check (kcal is null or kcal between 0 and 30000),
  protein_g numeric(6, 1) check (protein_g is null or protein_g between 0 and 2000),
  carbs_g numeric(6, 1) check (carbs_g is null or carbs_g between 0 and 3000),
  fat_g numeric(6, 1) check (fat_g is null or fat_g between 0 and 2000),
  fiber_g numeric(6, 1) check (fiber_g is null or fiber_g between 0 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (athlete_id, day),
  -- Da Apple Salute o a mano ci sono sempre dei numeri; solo la conferma può non averne.
  check (source = 'confirm' or coalesce(kcal, protein_g, carbs_g, fat_g, fiber_g) is not null)
);

do $$
declare
  t text;
begin
  foreach t in array array['nutrition_plans', 'nutrition_plan_days', 'nutrition_days'] loop
    execute format(
      'create trigger set_updated_at before update on public.%I
         for each row execute function private.set_updated_at()', t);
    execute format('alter table public.%I enable row level security', t);
    -- Niente cancellazioni fisiche dal client (si ritira con deleted_at) e nessun accesso anonimo.
    execute format('revoke delete on public.%I from anon, authenticated', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

-- Obiettivi: li legge l'atleta e il coach collegato; li scrive solo il coach collegato, a suo nome.
create policy nutrition_plans_select on public.nutrition_plans for select to authenticated
  using (athlete_id = (select auth.uid()) or private.is_coach_of(athlete_id));
create policy nutrition_plans_insert on public.nutrition_plans for insert to authenticated
  with check (author_id = (select auth.uid()) and private.is_coach_of(athlete_id));
create policy nutrition_plans_update on public.nutrition_plans for update to authenticated
  using (author_id = (select auth.uid()) and private.is_coach_of(athlete_id))
  with check (author_id = (select auth.uid()) and private.is_coach_of(athlete_id));

create policy nutrition_plan_days_select on public.nutrition_plan_days for select to authenticated
  using (exists (select 1 from public.nutrition_plans p where p.id = plan_id));
create policy nutrition_plan_days_insert on public.nutrition_plan_days for insert to authenticated
  with check (exists (
    select 1 from public.nutrition_plans p
    where p.id = plan_id and p.author_id = (select auth.uid()) and private.is_coach_of(p.athlete_id)));
create policy nutrition_plan_days_update on public.nutrition_plan_days for update to authenticated
  using (exists (
    select 1 from public.nutrition_plans p
    where p.id = plan_id and p.author_id = (select auth.uid()) and private.is_coach_of(p.athlete_id)))
  with check (exists (
    select 1 from public.nutrition_plans p
    where p.id = plan_id and p.author_id = (select auth.uid()) and private.is_coach_of(p.athlete_id)));

-- Aderenza: la scrive solo l'atleta, e solo con il suo consenso; il coach collegato la legge solo con quel consenso.
create policy nutrition_days_select on public.nutrition_days for select to authenticated
  using (
    athlete_id = (select auth.uid())
    or (private.is_coach_of(athlete_id) and private.has_nutrition_consent(athlete_id))
  );
create policy nutrition_days_insert on public.nutrition_days for insert to authenticated
  with check (athlete_id = (select auth.uid()) and private.has_nutrition_consent(athlete_id));
create policy nutrition_days_update on public.nutrition_days for update to authenticated
  using (athlete_id = (select auth.uid()))
  with check (athlete_id = (select auth.uid()) and private.has_nutrition_consent(athlete_id));

-- ---------------------------------------------------------------------------
-- Per i client
-- ---------------------------------------------------------------------------

-- L'obiettivo in vigore un certo giorno: il piano `macros` non eliminato con l'inizio più recente fino a quel giorno.
create function public.nutrition_target_on(p_athlete_id uuid, p_day date)
returns table (
  plan_id uuid,
  kcal integer,
  protein_g integer,
  carbs_g integer,
  fat_g integer,
  fiber_g integer,
  tolerance_pct smallint
)
language sql
stable
security invoker
set search_path = ''
as $$
  select p.id, d.kcal, d.protein_g, d.carbs_g, d.fat_g, d.fiber_g, p.tolerance_pct
    from public.nutrition_plans p
    join public.nutrition_plan_days d on d.plan_id = p.id and d.day_type = 'all'
   where p.athlete_id = p_athlete_id and p.kind = 'macros' and p.deleted_at is null and p.valid_from <= p_day
   order by p.valid_from desc
   limit 1;
$$;

-- Un giorno per riga, da p_from a p_to, con l'obiettivo di quel giorno e quello che l'atleta ha registrato.
-- Per il coach: lo scarto lo calcola il sito, lo stato (rispettato / non rispettato) lo ha scelto l'atleta.
create function public.nutrition_overview(p_athlete_id uuid, p_from date, p_to date)
returns table (
  day date,
  status public.nutrition_day_status,
  source public.nutrition_source,
  kcal numeric,
  protein_g numeric,
  carbs_g numeric,
  fat_g numeric,
  fiber_g numeric,
  target_kcal integer,
  target_protein_g integer,
  target_carbs_g integer,
  target_fat_g integer,
  tolerance_pct smallint
)
language sql
stable
security invoker
set search_path = ''
as $$
  select g::date, n.status, n.source, n.kcal, n.protein_g, n.carbs_g, n.fat_g, n.fiber_g,
         t.kcal, t.protein_g, t.carbs_g, t.fat_g, t.tolerance_pct
    from generate_series(p_from::timestamp, least(p_to, p_from + 366)::timestamp, interval '1 day') g
    left join public.nutrition_days n
           on n.athlete_id = p_athlete_id and n.day = g::date and n.deleted_at is null
    left join lateral public.nutrition_target_on(p_athlete_id, g::date) t on true
   order by g;
$$;

-- Ritirare il consenso: i giorni registrati si cancellano davvero e si smette di condividere. Security definer perché
-- il client non può cancellare righe; agisce solo sull'utente che chiama.
create function public.withdraw_nutrition_consent()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := (select auth.uid());
begin
  if uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  delete from public.nutrition_days where athlete_id = uid;
  update public.profiles set nutrition_consent_at = null, nutrition_consent_version = null where id = uid;
end;
$$;

revoke execute on function private.has_nutrition_consent(uuid), private.reject_unavailable_kind()
  from public, anon;
grant execute on function private.has_nutrition_consent(uuid), private.reject_unavailable_kind() to authenticated;
revoke execute on function public.nutrition_target_on(uuid, date), public.nutrition_overview(uuid, date, date),
  public.withdraw_nutrition_consent() from public, anon;
grant execute on function public.nutrition_target_on(uuid, date), public.nutrition_overview(uuid, date, date),
  public.withdraw_nutrition_consent() to authenticated;
