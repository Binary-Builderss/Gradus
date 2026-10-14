"""Trasforma un CSV del catalogo globale in SQL per una migrazione.

    python3 supabase/catalog/to_sql.py supabase/catalog/esercizi_v1.csv > supabase/migrations/<ts>_catalog_v1.sql

L'id di ogni esercizio deriva dallo slug (uuid5): una migrazione successiva può correggere nome o
pesi con `on conflict (id)` senza creare doppioni. Uno slug non si cambia mai.
"""
import csv
import sys
import uuid

NAMESPACE = uuid.uuid5(uuid.NAMESPACE_URL, 'https://gradus.app/catalog/exercises')


def q(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


rows = list(csv.DictReader(open(sys.argv[1], encoding='utf-8')))
exercises, muscles = [], []
for r in rows:
    eid = uuid.uuid5(NAMESPACE, r['slug'])
    exercises.append(f"  ('{eid}', {q(r['nome'])})")
    for part in r['muscoli'].split('; '):
        muscle, weight = part.split(' ')
        muscles.append(f"  ('{eid}', '{muscle}', {weight})")

print(f'-- Catalogo globale generato da {sys.argv[1]} ({len(rows)} esercizi).')
print('insert into public.exercises (id, name) values')
print(',\n'.join(exercises))
print('on conflict (id) do update set name = excluded.name;\n')
print('insert into public.exercise_muscles (exercise_id, muscle, weight) values')
print(',\n'.join(muscles))
print('on conflict (exercise_id, muscle) do update set weight = excluded.weight;')
