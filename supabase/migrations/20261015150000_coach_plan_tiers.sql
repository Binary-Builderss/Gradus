-- Livelli del piano: free (20 atleti), mid (60), pro (100), unlimited (senza tetto).
-- I valori nuovi di un enum non si possono usare nella stessa transazione in cui nascono: l'uso sta nella
-- migrazione successiva.
alter type public.coach_plan add value if not exists 'mid' before 'pro';
alter type public.coach_plan add value if not exists 'unlimited';
