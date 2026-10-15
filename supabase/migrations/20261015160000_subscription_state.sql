-- Stato dell'abbonamento: smettere di pagare deve essere sempre possibile.
--
-- La disdetta passa dal servizio di pagamento (portale clienti); quando arriva, chi scrive qui (webhook con
-- service_role) mette cancel_at_period_end = true e lascia pro_until alla fine del periodo già pagato: il
-- piano resta attivo fino a quella data e poi torna free da solo (effective_plan lo calcola). Nessun dato
-- viene cancellato: chi supera il tetto del free tiene i suoi atleti ma non ne aggiunge.
--
-- billing_ref = identificativo opaco dell'abbonamento presso il servizio di pagamento (null = piano
-- assegnato a mano, nessun addebito). Serve a non lasciar eliminare un account con un abbonamento che
-- continua a rinnovarsi: l'eliminazione non lo fermerebbe e la persona verrebbe addebitata.

alter table public.coach_plans
  add column cancel_at_period_end boolean not null default false,
  add column billing_ref text;

-- Il tipo di ritorno cambia: si ricrea.
drop function public.plan_usage();
create function public.plan_usage()
returns table (
  plan public.coach_plan,
  athlete_limit integer,
  athletes integer,
  can_customize boolean,
  renews_until timestamptz,
  cancel_at_period_end boolean,
  has_subscription boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
  select private.effective_plan((select auth.uid())),
         private.athlete_limit((select auth.uid())),
         private.athlete_count((select auth.uid())),
         private.is_pro((select auth.uid())),
         case when private.effective_plan((select auth.uid())) = 'free' then null else p.pro_until end,
         coalesce(p.cancel_at_period_end, false),
         p.billing_ref is not null
    from (select 1) one
    left join public.coach_plans p on p.coach_id = (select auth.uid());
-- has_subscription: c'è un abbonamento presso il servizio di pagamento (false = piano assegnato a mano).
$$;
revoke execute on function public.plan_usage() from public, anon;
grant execute on function public.plan_usage() to authenticated;

-- Un abbonamento che si rinnova ancora ferma la cancellazione dell'account (la persona deve prima disdire).
create or replace function public.prepare_account_deletion(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists (
    select 1 from public.coach_plans
    where coach_id = p_user_id and billing_ref is not null and not cancel_at_period_end
      and private.effective_plan(p_user_id) <> 'free'
  ) then
    raise exception 'subscription_active' using errcode = 'P0001';
  end if;
  update public.exercises e
     set owner_id = null, deleted_at = coalesce(e.deleted_at, now())
   where e.owner_id = p_user_id
     and exists (select 1 from public.slots s where s.exercise_id = e.id);
  delete from public.workouts where athlete_id = p_user_id;
end;
$$;
revoke execute on function public.prepare_account_deletion(uuid) from public, anon, authenticated;
grant execute on function public.prepare_account_deletion(uuid) to service_role;
