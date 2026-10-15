-- Piano del coach e personalizzazione del marchio.
--
-- coach_plans: quale piano ha un coach. Nessuna riga = piano gratuito. Si scrive solo con service_role
-- o da SQL (nessun coach può promuoversi da solo); i pagamenti veri verranno dopo e scriveranno qui.
-- Per provare le funzioni a pagamento: insert into coach_plans (coach_id, plan) values ('<uuid>', 'pro').
--
-- coach_branding: logo e colori scelti dal coach. Si scrive solo con piano pro, e l'atleta collegato li
-- vede solo finché il coach è pro: se il piano scade, app e PDF tornano allo stile standard.
-- Il logo è un PNG in base64 dentro la riga (piccolo, già ridimensionato dal web): niente Storage.

create type public.coach_plan as enum ('free', 'pro');

create table public.coach_plans (
  coach_id uuid primary key references public.profiles (id) on delete cascade,
  plan public.coach_plan not null default 'free',
  -- Fine del periodo pro; null = senza scadenza.
  pro_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Pro oggi: piano pro e periodo non scaduto. Security definer perché lo chiamano anche le policy di
-- coach_branding per conto dell'atleta, che non può leggere coach_plans.
create function private.is_pro(p_coach_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.coach_plans
    where coach_id = p_coach_id and plan = 'pro' and (pro_until is null or pro_until > now())
  );
$$;

-- Il coach collegato a me (l'atleta che chiama) con collegamento attivo.
create function private.is_my_coach(p_coach_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.coach_athletes
    where coach_id = p_coach_id and athlete_id = (select auth.uid()) and status = 'active'
  );
$$;

-- Colori ammessi: solo queste chiavi, ognuna #RRGGBB. Le chiavi mancanti restano quelle standard.
create function private.valid_brand_colors(p_colors jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(p_colors) = 'object'
    and not exists (
      select 1 from jsonb_each(p_colors) e
      where e.key not in ('primary', 'on_primary', 'background', 'foreground', 'surface', 'muted_foreground', 'border')
         or jsonb_typeof(e.value) <> 'string'
         or (e.value #>> '{}') !~ '^#[0-9a-fA-F]{6}$'
    );
$$;

create table public.coach_branding (
  coach_id uuid primary key references public.profiles (id) on delete cascade,
  -- Nome mostrato nel PDF e nell'app al posto di quello del profilo.
  brand_name text check (brand_name is null or (btrim(brand_name) <> '' and length(brand_name) <= 80)),
  logo_png text check (logo_png is null or (length(logo_png) <= 400000 and logo_png ~ '^[A-Za-z0-9+/]+=*$')),
  colors jsonb not null default '{}' check (private.valid_brand_colors(colors)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger set_updated_at before update on public.coach_plans
  for each row execute function private.set_updated_at();
create trigger set_updated_at before update on public.coach_branding
  for each row execute function private.set_updated_at();

alter table public.coach_plans enable row level security;
alter table public.coach_branding enable row level security;

-- coach_plans: il coach legge il proprio, nessuno scrive da client.
create policy coach_plans_select on public.coach_plans for select to authenticated
  using (coach_id = (select auth.uid()));
revoke insert, update, delete on public.coach_plans from anon, authenticated;

-- coach_branding: lo scrive solo il coach pro; lo leggono lui e, se il coach è pro, i suoi atleti attivi.
create policy coach_branding_select on public.coach_branding for select to authenticated
  using (
    coach_id = (select auth.uid())
    or (private.is_my_coach(coach_id) and private.is_pro(coach_id))
  );
create policy coach_branding_insert on public.coach_branding for insert to authenticated
  with check (coach_id = (select auth.uid()) and private.is_pro(coach_id));
create policy coach_branding_update on public.coach_branding for update to authenticated
  using (coach_id = (select auth.uid()) and private.is_pro(coach_id))
  with check (coach_id = (select auth.uid()) and private.is_pro(coach_id));
create policy coach_branding_delete on public.coach_branding for delete to authenticated
  using (coach_id = (select auth.uid()));

-- Per il client: ho il piano pro oggi? (la regola sta nel database, il web non la ricalcola)
create function public.has_pro_plan()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select private.is_pro((select auth.uid()));
$$;

-- Come gli altri helper: solo gli utenti autenticati li eseguono.
revoke execute on function private.is_pro(uuid), private.is_my_coach(uuid), private.valid_brand_colors(jsonb)
  from public, anon;
grant execute on function private.is_pro(uuid), private.is_my_coach(uuid), private.valid_brand_colors(jsonb)
  to authenticated;
revoke execute on function public.has_pro_plan() from public, anon;
grant execute on function public.has_pro_plan() to authenticated;
