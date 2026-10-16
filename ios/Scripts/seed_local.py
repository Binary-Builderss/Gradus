#!/usr/bin/env python3
"""Crea nel Supabase LOCALE (mai in remoto) un coach, due atleti e un programma d'esempio, per provare l'app.

    supabase start && python3 ios/Scripts/seed_local.py

Stampa solo gli indirizzi email di prova; la password è fissa e vale solo sul database locale.
Usa la service_role locale (letta da `supabase status`, mai salvata): serve a scrivere come farebbe un coach.
"""
import json, subprocess, sys, urllib.request

PASSWORD = "gradus-locale-1"
COACH, ATHLETE, OTHER = "coach@prova.local", "atleta@prova.local", "altro@prova.local"


def status():
    out = subprocess.run(["supabase", "status", "-o", "env"], capture_output=True, text=True, check=True).stdout
    env = dict(line.split("=", 1) for line in out.splitlines() if "=" in line)
    return env["API_URL"].strip('"'), env["SERVICE_ROLE_KEY"].strip('"')


API, KEY = status()
if "127.0.0.1" not in API and "localhost" not in API:
    sys.exit("Questo script scrive solo sul database locale.")


def call(method, path, body=None, prefer=None):
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body is not None else None)
    req.add_header("apikey", KEY)
    req.add_header("Authorization", f"Bearer {KEY}")
    req.add_header("Content-Type", "application/json")
    if prefer:
        req.add_header("Prefer", prefer)
    try:
        with urllib.request.urlopen(req) as r:
            data = r.read()
            return json.loads(data) if data else None
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path}: {e.code} {e.read().decode()}")


def user(email):
    found = call("GET", f"/rest/v1/profiles?email=eq.{email}&select=id")
    if found:
        return found[0]["id"]
    created = call("POST", "/auth/v1/admin/users", {"email": email, "password": PASSWORD, "email_confirm": True})
    return created["id"]


def insert(table, rows):
    call("POST", f"/rest/v1/{table}?on_conflict=id", rows, prefer="resolution=merge-duplicates,return=minimal")


coach, athlete, other = user(COACH), user(ATHLETE), user(OTHER)
call("PATCH", f"/rest/v1/profiles?id=eq.{athlete}", {"full_name": "Marco Rossi"}, prefer="return=minimal")
call("PATCH", f"/rest/v1/profiles?id=eq.{coach}", {"full_name": "Giulia Coach"}, prefer="return=minimal")
call("POST", "/rest/v1/coach_athletes?on_conflict=coach_id,athlete_id", [
    {"coach_id": coach, "athlete_id": athlete, "status": "active"},
    {"coach_id": coach, "athlete_id": other, "status": "active"},
], prefer="resolution=merge-duplicates,return=minimal")

ids = lambda n, k: f"{n}0000000-0000-4000-8000-{k:012d}"
EX1, EX2 = ids(9, 1), ids(9, 2)
insert("exercises", [{"id": EX1, "owner_id": coach, "name": "Panca piana (prova)"}, {"id": EX2, "owner_id": coach, "name": "Croci ai cavi (prova)"}])

M, M_DRAFT, M_OTHER = ids(1, 1), ids(1, 2), ids(1, 3)
insert("mesocycles", [
    {"id": M, "athlete_id": athlete, "name": "Ipertrofia 1", "start_date": "2026-10-05", "weeks": 6, "deload_weeks": [6], "status": "active", "coach_notes": "Scalda bene"},
    {"id": M_DRAFT, "athlete_id": athlete, "name": "Bozza che l'atleta non vede", "start_date": "2026-12-01", "weeks": 4, "deload_weeks": [], "status": "draft", "coach_notes": None},
    {"id": M_OTHER, "athlete_id": other, "name": "Di un altro atleta", "start_date": "2026-10-05", "weeks": 4, "deload_weeks": [], "status": "active", "coach_notes": None},
])
S1, S2, S_OTHER = ids(2, 1), ids(2, 2), ids(2, 3)
insert("sessions", [
    {"id": S1, "mesocycle_id": M, "position": 0, "name": "Spinta"},
    {"id": S2, "mesocycle_id": M, "position": 1, "name": "Tirata"},
    {"id": S_OTHER, "mesocycle_id": M_OTHER, "position": 0, "name": "Seduta di un altro"},
])
G1 = ids(3, 1)
insert("slot_groups", [{"id": G1, "mesocycle_id": M, "session_id": S1, "position": 0, "kind": "superset", "rest_after_round_s": 90}])
SL1, SL2 = ids(4, 1), ids(4, 2)
insert("slots", [
    {"id": SL1, "mesocycle_id": M, "group_id": G1, "position": 0, "exercise_id": EX1, "coach_notes": "Gomiti stretti"},
    {"id": SL2, "mesocycle_id": M, "group_id": G1, "position": 1, "exercise_id": EX2, "coach_notes": None},
])
TOP, BACK = ids(5, 1), ids(5, 2)
insert("set_blocks", [
    {"id": TOP, "mesocycle_id": M, "slot_id": SL1, "position": 0, "role": "top", "rest_s": 180, "ref_block_id": None},
    {"id": BACK, "mesocycle_id": M, "slot_id": SL1, "position": 1, "role": "backoff", "rest_s": 120, "ref_block_id": TOP},
])
insert("block_weeks", [
    {"id": ids(7, w), "mesocycle_id": M, "block_id": TOP, "week": w, "sets": 1, "reps_min": 5, "reps_max": 5, "method": "BUF", "intensity_value": max(3 - (w - 1) * 0.5, 0), "ref_pct": None}
    for w in range(1, 6)
] + [{"id": ids(8, 1), "mesocycle_id": M, "block_id": BACK, "week": 1, "sets": 2, "reps_min": 8, "reps_max": 10, "method": None, "intensity_value": None, "ref_pct": 85}])

print(f"Creati sul database locale: {COACH}, {ATHLETE}, {OTHER} (password di prova: vedi lo script)")
