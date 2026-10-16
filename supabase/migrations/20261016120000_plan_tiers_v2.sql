-- Piani v2: free / basic / advanced / custom.
--
-- - Nomi in inglese: mid → basic, pro → advanced, unlimited → custom (i coach che avevano i vecchi piani li
--   tengono con il nome nuovo; i tetti nuovi valgono per i collegamenti e le righe che aggiungono da ora).
-- - Tetti per piano, una sola fonte (private.plan_limit): atleti 20 / 50 / 100 / 500; template di sessione
--   5 / 35 / 70 / 140; template di mesociclo 1 / 5 / 10 / 20; progressioni salvate 20 / 350 / 700 / 1400; schede
--   dieta 0 / 7 / 15 / 30; snapshot dieta per atleta 0 / 12 / 12 / 12. I template di sessione e la dieta non
--   hanno ancora una tabella: i loro tetti sono dichiarati qui perché il web e le funzioni future li leggano
--   dallo stesso posto. Chi supera un tetto dopo un declassamento tiene quello che ha ma non ne aggiunge.
-- - Personalizzazione a livelli (private.branding_level): 0 nessuna (free), 1 basic = logo, nome e un colore
--   principale, 2 advanced = tavolozza completa, 3 custom = tavolozza completa e PDF senza la dicitura Gradus.
--   Sostituisce private.is_pro / has_pro_plan. Se un coach scende di livello il marchio si ridimensiona da solo.
-- - plan_usage e plan_limits restituiscono i dati nuovi (can_customize diventa branding_level).

alter type public.coach_plan rename value 'mid' to 'basic';
alter type public.coach_plan rename value 'pro' to 'advanced';
alter type public.coach_plan rename value 'unlimited' to 'custom';

-- Cosa dipendeva da is_pro / plan_limit / athlete_limit: via, poi si ricrea.
drop policy coach_branding_select on public.coach_branding;
drop policy coach_branding_insert on public.coach_branding;
drop policy coach_branding_update on public.coach_branding;
drop function public.has_pro_plan();
drop function public.plan_usage();
drop function public.plan_limits();
drop function private.is_pro(uuid);
drop function private.athlete_limit(uuid);
drop function private.plan_limit(public.coach_plan);

-- ---------------------------------------------------------------------------
-- Tetti e livelli (unica fonte dei numeri)
-- ---------------------------------------------------------------------------

create function private.plan_limit(p_plan public.coach_plan, p_kind text)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  result integer;
begin
  result := case p_kind
    when 'athletes' then case p_plan when 'free' then 20 when 'basic' then 50 when 'advanced' then 100 else 500 end
    when 'session_templates' then case p_plan when 'free' then 5 when 'basic' then 35 when 'advanced' then 70 else 140 end
    when 'mesocycle_templates' then case p_plan when 'free' then 1 when 'basic' then 5 when 'advanced' then 10 else 20 end
    when 'progression_presets' then case p_plan when 'free' then 20 when 'basic' then 350 when 'advanced' then 700 else 1400 end
    when 'diet_plans' then case p_plan when 'free' then 0 when 'basic' then 7 when 'advanced' then 15 else 30 end
    when 'diet_snapshots' then case p_plan when 'free' then 0 else 12 end
  end;
  -- un tipo sconosciuto non diventa mai «nessun tetto»: è un errore di chi chiama
  if result is null then
    raise exception 'unknown_limit_kind' using errcode = '22023', hint = p_kind;
  end if;
  return result;
end;
$$;

create function private.plan_branding_level(p_plan public.coach_plan)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_plan when 'free' then 0 when 'basic' then 1 when 'advanced' then 2 else 3 end;
$$;

-- Livello di personalizzazione di un coach oggi (un piano scaduto vale free). Security definer perché lo
-- chiamano anche le policy di coach_branding per conto dell'atleta, che non può leggere coach_plans.
create function private.branding_level(p_coach_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select private.plan_branding_level(private.effective_plan(p_coach_id));
$$;

create function private.athlete_limit(p_coach_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select private.plan_limit(private.effective_plan(p_coach_id), 'athletes');
$$;

-- ---------------------------------------------------------------------------
-- Tetti su template di mesociclo e progressioni salvate
-- ---------------------------------------------------------------------------

-- Il tetto vale per ogni via di scrittura. Security definer: conta le righe del coach a prescindere dalle policy.
create function private.enforce_owner_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  kind text := tg_argv[0];
  cap integer := private.plan_limit(private.effective_plan(new.owner_id), kind);
  used integer;
begin
  execute format('select count(*)::int from public.%I where owner_id = $1', tg_table_name) into used using new.owner_id;
  if used >= cap then
    raise exception using message = kind || '_limit_reached', errcode = 'P0001', hint = cap::text;
  end if;
  return new;
end;
$$;

create trigger enforce_owner_limit before insert on public.mesocycle_templates
  for each row execute function private.enforce_owner_limit('mesocycle_templates');
create trigger enforce_owner_limit before insert on public.progression_presets
  for each row execute function private.enforce_owner_limit('progression_presets');

-- ---------------------------------------------------------------------------
-- Personalizzazione a livelli
-- ---------------------------------------------------------------------------

-- Dal livello custom: il PDF non porta la dicitura Gradus.
alter table public.coach_branding add column hide_gradus_credit boolean not null default false;

create policy coach_branding_select on public.coach_branding for select to authenticated
  using (
    coach_id = (select auth.uid())
    or (private.is_my_coach(coach_id) and private.branding_level(coach_id) >= 1)
  );
create policy coach_branding_insert on public.coach_branding for insert to authenticated
  with check (coach_id = (select auth.uid()) and private.branding_level(coach_id) >= 1);
create policy coach_branding_update on public.coach_branding for update to authenticated
  using (coach_id = (select auth.uid()) and private.branding_level(coach_id) >= 1)
  with check (coach_id = (select auth.uid()) and private.branding_level(coach_id) >= 1);

-- Quanta libertà ha il coach: livello 1 solo il colore principale, 3 anche la dicitura. Vale per ogni via di
-- scrittura (anche service_role).
create function private.enforce_branding_level()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  lvl integer := private.branding_level(new.coach_id);
begin
  if lvl = 0 then
    raise exception 'branding_level_too_low' using errcode = 'P0001', hint = 'plan';
  end if;
  if new.hide_gradus_credit and lvl < 3 then
    raise exception 'branding_level_too_low' using errcode = 'P0001', hint = 'credit';
  end if;
  if lvl < 2 and exists (select 1 from jsonb_object_keys(new.colors) k where k <> 'primary') then
    raise exception 'branding_level_too_low' using errcode = 'P0001', hint = 'palette';
  end if;
  return new;
end;
$$;

create trigger enforce_branding_level before insert or update on public.coach_branding
  for each row execute function private.enforce_branding_level();

-- Se il piano cambia tra due livelli a pagamento (webhook), il marchio si ridimensiona: fuori i colori e la
-- dicitura che il livello nuovo non ammette. Nulla si cancella da sé: scendendo a free il marchio resta
-- ma l'atleta smette di vederlo (policy) e riprende se si risale.
create function private.prune_branding()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  lvl integer := private.branding_level(new.coach_id);
begin
  if lvl in (1, 2) then
    update public.coach_branding b
       set colors = coalesce(
             (select jsonb_object_agg(e.key, e.value) from jsonb_each(b.colors) e where lvl >= 2 or e.key = 'primary'),
             '{}'::jsonb),
           hide_gradus_credit = false
     where b.coach_id = new.coach_id;
  end if;
  return new;
end;
$$;

create trigger prune_branding after insert or update of plan, pro_until on public.coach_plans
  for each row execute function private.prune_branding();

-- ---------------------------------------------------------------------------
-- Per il client
-- ---------------------------------------------------------------------------

-- Piano, tetto e uso di chi chiama. branding_level: 0 nessuna personalizzazione … 3 anche senza dicitura Gradus.
create function public.plan_usage()
returns table (
  plan public.coach_plan,
  athlete_limit integer,
  athletes integer,
  branding_level integer,
  renews_until timestamptz,
  cancel_at_period_end boolean,
  has_subscription boolean,
  mesocycle_templates integer,
  progression_presets integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  select private.effective_plan((select auth.uid())),
         private.athlete_limit((select auth.uid())),
         private.athlete_count((select auth.uid())),
         private.branding_level((select auth.uid())),
         case when private.effective_plan((select auth.uid())) = 'free' then null else p.pro_until end,
         coalesce(p.cancel_at_period_end, false),
         p.billing_ref is not null,
         (select count(*)::int from public.mesocycle_templates where owner_id = (select auth.uid())),
         (select count(*)::int from public.progression_presets where owner_id = (select auth.uid()))
    from (select 1) one
    left join public.coach_plans p on p.coach_id = (select auth.uid());
-- has_subscription: c'è un abbonamento presso il servizio di pagamento (false = piano assegnato a mano).
$$;

-- Per la pagina dei piani: tutti i livelli con i loro tetti e il livello di personalizzazione.
create function public.plan_limits()
returns table (
  plan public.coach_plan,
  athlete_limit integer,
  session_templates integer,
  mesocycle_templates integer,
  progression_presets integer,
  diet_plans integer,
  diet_snapshots integer,
  branding_level integer
)
language sql
stable
security invoker
set search_path = ''
as $$
  select p,
         private.plan_limit(p, 'athletes'),
         private.plan_limit(p, 'session_templates'),
         private.plan_limit(p, 'mesocycle_templates'),
         private.plan_limit(p, 'progression_presets'),
         private.plan_limit(p, 'diet_plans'),
         private.plan_limit(p, 'diet_snapshots'),
         private.plan_branding_level(p)
    from unnest(enum_range(null::public.coach_plan)) as p;
$$;

revoke execute on function private.plan_limit(public.coach_plan, text), private.plan_branding_level(public.coach_plan),
  private.branding_level(uuid), private.athlete_limit(uuid), private.enforce_owner_limit(),
  private.enforce_branding_level(), private.prune_branding() from public, anon;
grant execute on function private.plan_limit(public.coach_plan, text), private.plan_branding_level(public.coach_plan),
  private.branding_level(uuid), private.athlete_limit(uuid), private.enforce_owner_limit(),
  private.enforce_branding_level(), private.prune_branding() to authenticated;
revoke execute on function public.plan_usage(), public.plan_limits() from public, anon;
grant execute on function public.plan_usage(), public.plan_limits() to authenticated;
