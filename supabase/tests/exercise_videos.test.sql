-- exercise_videos: link scelti dal coach. c1 = coach (collegato ad a1, con a2 in attesa), c2 = altro coach,
-- a1 = suo atleta, a2 = atleta con invito in attesa, b1 = atleta di c2.
-- ex1 = esercizio di c1, ex2 = esercizio di c2, il catalogo ha esercizi senza proprietario.

begin;
create extension if not exists pgtap with schema extensions;
select no_plan();

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000c1', 'c1@test.dev'),
  ('00000000-0000-0000-0000-0000000000c2', 'c2@test.dev'),
  ('00000000-0000-0000-0000-0000000000a1', 'a1@test.dev'),
  ('00000000-0000-0000-0000-0000000000a2', 'a2@test.dev'),
  ('00000000-0000-0000-0000-0000000000b1', 'b1@test.dev');
insert into public.coach_athletes (coach_id, athlete_id, status) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'active'),
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a2', 'pending'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000b1', 'active');
insert into public.exercises (id, owner_id, name) values
  ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000c1', 'Esercizio di c1'),
  ('00000000-0000-0000-0000-00000000e002', '00000000-0000-0000-0000-0000000000c2', 'Esercizio di c2');

create schema tests;
grant usage on schema tests to authenticated;
create function tests.login(uid uuid) returns void language sql as $$
  select set_config('role', 'authenticated', true),
         set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
$$;
create function tests.rows_affected(q text) returns int language plpgsql as $$
declare n int;
begin
  execute q;
  get diagnostics n = row_count;
  return n;
end;
$$;
grant execute on all functions in schema tests to authenticated;

select ok(
  not exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'exercises' and column_name = 'video_url'),
  'exercises non ha più il link unico: i video stanno in exercise_videos');
select is((select count(*)::int from public.exercise_videos), 0, 'nessun video di default');

-- coach proprietario
select tests.login('00000000-0000-0000-0000-0000000000c1');
select lives_ok($$
  insert into public.exercise_videos (exercise_id, owner_id, url, title) values
    ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000c1', 'https://youtu.be/abc', 'Esecuzione'),
    ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000c1', 'https://vimeo.com/123', null) $$,
  'il coach aggiunge più link a un suo esercizio');
select lives_ok($$
  insert into public.exercise_videos (exercise_id, owner_id, url)
  select id, '00000000-0000-0000-0000-0000000000c1', 'https://www.instagram.com/reel/xyz/'
  from public.exercises where owner_id is null limit 1 $$,
  'il coach aggiunge un suo link a un esercizio del catalogo');
select is((select count(*)::int from public.exercise_videos), 3, 'il coach vede i propri tre link');
select throws_ok($$
  insert into public.exercise_videos (exercise_id, owner_id, url) values
    ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000c1', 'http://example.com/v') $$,
  '23514', null, 'solo https');
select throws_ok($$
  insert into public.exercise_videos (exercise_id, owner_id, url) values
    ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000c1', 'javascript:alert(1)') $$,
  '23514', null, 'niente schemi che non siano https');
select throws_ok($$
  insert into public.exercise_videos (exercise_id, owner_id, url) values
    ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000c1', 'https://youtu.be/abc') $$,
  '23505', null, 'lo stesso link non si ripete sullo stesso esercizio');
select throws_ok($$
  insert into public.exercise_videos (exercise_id, owner_id, url) values
    ('00000000-0000-0000-0000-00000000e002', '00000000-0000-0000-0000-0000000000c1', 'https://youtu.be/zzz') $$,
  '42501', null, 'non si aggiungono link all''esercizio di un altro coach');
select throws_ok($$
  insert into public.exercise_videos (exercise_id, owner_id, url) values
    ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000c2', 'https://youtu.be/zzz') $$,
  '42501', null, 'non si scrive a nome di un altro');
select is(tests.rows_affected($$
  update public.exercise_videos set title = 'Nuovo titolo' where url = 'https://youtu.be/abc' $$),
  1, 'il coach modifica il titolo di un suo link');

-- atleta collegato
select tests.login('00000000-0000-0000-0000-0000000000a1');
select is((select count(*)::int from public.exercise_videos), 3, 'l''atleta collegato vede i link del suo coach');
select is(tests.rows_affected($$ update public.exercise_videos set title = 'x' $$), 0, 'l''atleta non modifica');
select is(tests.rows_affected($$ delete from public.exercise_videos $$), 0, 'l''atleta non elimina');
select throws_ok($$
  insert into public.exercise_videos (exercise_id, owner_id, url) values
    ('00000000-0000-0000-0000-00000000e001', '00000000-0000-0000-0000-0000000000a1', 'https://youtu.be/k') $$,
  '42501', null, 'l''atleta non aggiunge link');

-- invito ancora in attesa: nessun accesso
select tests.login('00000000-0000-0000-0000-0000000000a2');
select is((select count(*)::int from public.exercise_videos), 0, 'invito in attesa: nessun link visibile');

-- atleta di un altro coach
select tests.login('00000000-0000-0000-0000-0000000000b1');
select is((select count(*)::int from public.exercise_videos), 0, 'l''atleta di un altro coach non vede nulla');

-- coach non collegato
select tests.login('00000000-0000-0000-0000-0000000000c2');
select is((select count(*)::int from public.exercise_videos), 0, 'un altro coach non vede i link di c1');
select is(tests.rows_affected($$ update public.exercise_videos set title = 'x' $$), 0, 'un altro coach non modifica');
select is(tests.rows_affected($$ delete from public.exercise_videos $$), 0, 'un altro coach non elimina');
select lives_ok($$
  insert into public.exercise_videos (exercise_id, owner_id, url) values
    ('00000000-0000-0000-0000-00000000e002', '00000000-0000-0000-0000-0000000000c2', 'https://youtu.be/abc') $$,
  'ogni coach ha i suoi link, anche uguali a quelli di un altro');

-- il coach elimina i propri
select tests.login('00000000-0000-0000-0000-0000000000c1');
select is(tests.rows_affected($$ delete from public.exercise_videos where url = 'https://vimeo.com/123' $$),
  1, 'il coach elimina un suo link');

-- anonimo
select set_config('role', 'anon', true);
select throws_ok($$ select * from public.exercise_videos $$, '42501', null, 'l''anonimo non legge');

select * from finish();
rollback;
