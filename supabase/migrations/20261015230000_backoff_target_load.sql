-- backoff_target_load(top_load_kg, ref_pct): il carico indicato per un back-off legato a un top set.
-- È la regola che l'app iOS ripete in Swift (serve offline): casi comuni in /fixtures/backoff_cases.json e test
-- pgTAP `backoff_fixtures.test.sql` generato da lì (node fixtures/generate-sql.mjs).
--
-- carico del top set × percentuale ÷ 100, arrotondato al 2,5 kg più vicino (a metà si sale: `round` di numeric
-- arrotonda lontano da zero). Indicazione, mai un valore scritto nei campi dell'atleta.

create function public.backoff_target_load(p_top_load_kg numeric, p_ref_pct numeric)
returns numeric
language sql
immutable
security invoker
set search_path = ''
as $$
  select round(p_top_load_kg * p_ref_pct / 100 / 2.5) * 2.5
$$;

revoke execute on function public.backoff_target_load(numeric, numeric) from public, anon;
grant execute on function public.backoff_target_load(numeric, numeric) to authenticated;
