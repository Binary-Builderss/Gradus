-- Limiti di atleti per piano, disattivazione e cancellazione dell'account.
--
-- Piano effettivo: quello scritto in coach_plans, ma un piano a pagamento scaduto (pro_until nel passato)
-- vale free. Tetto di atleti: free 20, mid 60, pro 100, unlimited nessuno. Conta chi ha un collegamento
-- pending o active con il coach (l'invito in attesa occupa il posto), senza il collegamento con sé stesso.
-- Chi supera il tetto dopo un declassamento tiene gli atleti che ha (non si cancella nessuno) ma non ne
-- aggiunge altri. Le funzioni di Personalizza (marchio) valgono da pro in su, non per mid.

create function private.effective_plan(p_coach_id uuid)
returns public.coach_plan
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select case when plan = 'free' or pro_until is null or pro_until > now() then plan else 'free'::public.coach_plan end
       from public.coach_plans where coach_id = p_coach_id),
    'free'::public.coach_plan
  );
$$;

-- Tetto di atleti di un piano; null = senza tetto. Unica fonte dei numeri: il web li legge da plan_limits().
create function private.plan_limit(p_plan public.coach_plan)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_plan when 'free' then 20 when 'mid' then 60 when 'pro' then 100 else null end;
$$;

create function private.athlete_limit(p_coach_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select private.plan_limit(private.effective_plan(p_coach_id));
$$;

create function private.athlete_count(p_coach_id uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int from public.coach_athletes
  where coach_id = p_coach_id and athlete_id <> coach_id and status in ('pending', 'active');
$$;

-- Pro da qui in su (pro e unlimited): marchio personalizzato e funzioni collegate.
create or replace function private.is_pro(p_coach_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.effective_plan(p_coach_id) in ('pro', 'unlimited');
$$;

-- Il tetto vale anche se qualcuno scrive nel database senza passare dal web (Edge Function, SQL).
-- Security definer: le funzioni di conteggio non sono eseguibili da service_role (l'Edge Function che
-- invita), e il trigger deve funzionare per qualunque ruolo.
create function private.enforce_athlete_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  cap integer;
begin
  if new.coach_id = new.athlete_id or new.status not in ('pending', 'active') then
    return new;
  end if;
  -- Occupa un posto solo un collegamento nuovo o riaperto da «ended»; pending → active no.
  if tg_op = 'UPDATE' and old.status in ('pending', 'active') then
    return new;
  end if;
  cap := private.athlete_limit(new.coach_id);
  if cap is not null and private.athlete_count(new.coach_id) >= cap then
    raise exception 'athlete_limit_reached' using errcode = 'P0001', hint = cap::text;
  end if;
  return new;
end;
$$;

create trigger enforce_athlete_limit
  before insert or update of status on public.coach_athletes
  for each row execute function private.enforce_athlete_limit();

-- Per il client: piano, tetto e atleti attuali di chi chiama.
create function public.plan_usage()
returns table (plan public.coach_plan, athlete_limit integer, athletes integer, can_customize boolean)
language sql
stable
security invoker
set search_path = ''
as $$
  select private.effective_plan((select auth.uid())),
         private.athlete_limit((select auth.uid())),
         private.athlete_count((select auth.uid())),
         private.is_pro((select auth.uid()));
$$;

-- Per la pagina dei piani: tutti i livelli con il loro tetto.
create function public.plan_limits()
returns table (plan public.coach_plan, athlete_limit integer)
language sql
stable
security invoker
set search_path = ''
as $$
  select p, private.plan_limit(p) from unnest(enum_range(null::public.coach_plan)) as p;
$$;

-- Account disattivato: reversibile, lo decide la persona. Il web e l'app mostrano una schermata per
-- riattivarlo; i dati restano. Non si scrive altro che questa colonna.
alter table public.profiles add column disabled_at timestamptz;

-- Cancellazione dell'account (la completa la Edge Function con service_role, subito dopo questa):
-- - gli esercizi del coach usati in qualche programma restano come «ritirati» (senza proprietario e con
--   deleted_at: spariscono da tutte le librerie ma i programmi degli atleti continuano a leggerne il nome);
--   gli altri se ne vanno con l'account;
-- - le sedute registrate dalla persona come atleta si cancellano qui perché la FK verso i mesocicli non ha
--   cascade; il resto (collegamenti, piano, marchio, mesocicli dove è atleta) va in cascata con il profilo;
-- - i mesocicli scritti da un coach per i suoi atleti restano agli atleti.
create function public.prepare_account_deletion(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.exercises e
     set owner_id = null, deleted_at = coalesce(e.deleted_at, now())
   where e.owner_id = p_user_id
     and exists (select 1 from public.slots s where s.exercise_id = e.id);
  delete from public.workouts where athlete_id = p_user_id;
end;
$$;

revoke execute on function private.effective_plan(uuid), private.plan_limit(public.coach_plan), private.athlete_limit(uuid),
  private.athlete_count(uuid), private.enforce_athlete_limit() from public, anon;
grant execute on function private.effective_plan(uuid), private.plan_limit(public.coach_plan), private.athlete_limit(uuid),
  private.athlete_count(uuid), private.enforce_athlete_limit() to authenticated;
revoke execute on function public.plan_usage(), public.plan_limits() from public, anon;
grant execute on function public.plan_usage(), public.plan_limits() to authenticated;
-- Solo la Edge Function (service_role): un client non deve poter lanciare la cancellazione di un altro.
revoke execute on function public.prepare_account_deletion(uuid) from public, anon, authenticated;
grant execute on function public.prepare_account_deletion(uuid) to service_role;
