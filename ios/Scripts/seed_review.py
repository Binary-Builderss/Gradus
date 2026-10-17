#!/usr/bin/env python3
"""Crea (o riporta alla settimana 2) l'account DEMO per la revisione di Apple: un coach e un atleta collegati, un
mesociclo attivo di 8 settimane e la settimana 1 già registrata, così nell'app si vedono subito il riferimento alla
settimana precedente e il carico del back-off.

Lo lanci tu, dal tuo terminale, contro il progetto che vuoi (di solito quello online):

    SUPABASE_URL=https://<ref>.supabase.co \\
    SUPABASE_SERVICE_ROLE_KEY=<chiave secret> \\
    REVIEW_PASSWORD=<password di almeno 12 caratteri> \\
    python3 ios/Scripts/seed_review.py

La chiave secret e la password si passano solo come variabili d'ambiente: lo script non le salva né le stampa.
Rieseguirlo aggiorna le righe (non duplica) e sposta l'inizio del mesociclo a 7 giorni fa: lancialo di nuovo poco
prima di inviare l'app in revisione. La password va scritta nelle note per il revisore su App Store Connect.
"""
import os, sys, uuid
from datetime import date, datetime, time, timedelta, timezone

from seedlib import Api

COACH_EMAIL = "demo.coach@binarybuilders.dev"
ATHLETE_EMAIL = "demo.atleta@binarybuilders.dev"

url, key, password = (os.environ.get(n) for n in ("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "REVIEW_PASSWORD"))
if not (url and key and password):
    sys.exit("Servono SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY e REVIEW_PASSWORD (vedi l'intestazione dello script).")
if len(password) < 12:
    sys.exit("REVIEW_PASSWORD: almeno 12 caratteri.")

api = Api(url, key)
insert = api.insert

# --- id ----------------------------------------------------------------------------------------------------------
DEMO = uuid.UUID("0D3A5C11-6B2E-4F7A-8C19-5E2B7A9D4C30")  # solo per gli id della programmazione demo
demo_id = lambda name: str(uuid.uuid5(DEMO, name))

# Gli id dell'esecuzione sono quelli che calcola l'app (ios/Domain/DeterministicID.swift): stesso namespace e stessi
# nomi, altrimenti una serie registrata dall'app non coinciderebbe con quella già sul server.
APP = uuid.UUID("6F0C1B5A-3D7E-4A2B-9C84-1E5D0A7B9F31")
app_id = lambda name: str(uuid.uuid5(APP, name))
workout_id = lambda session, week: app_id(f"workout/{session.lower()}/{week}")
set_log_id = lambda workout, block, idx: app_id(f"set/{workout.lower()}/{block.lower()}/{idx}")
segment_id = lambda log, idx: app_id(f"segment/{log.lower()}/{idx}")

# --- persone -----------------------------------------------------------------------------------------------------
coach = api.user(COACH_EMAIL, password, "Giulia Bianchi")
athlete = api.user(ATHLETE_EMAIL, password, "Marco Rossi")
api.call(
    "POST", "/rest/v1/coach_athletes?on_conflict=coach_id,athlete_id",
    [{"coach_id": coach, "athlete_id": athlete, "status": "active"}], prefer="resolution=merge-duplicates,return=minimal",
)

# --- esercizi (del coach demo) -------------------------------------------------------------------------------------
EXERCISES = ["Panca piana", "Croci ai cavi", "Alzate laterali", "Lat machine", "Rematore con manubrio", "Curl con manubri",
             "Squat", "Leg curl"]
ex = {name: demo_id(f"exercise/{name}") for name in EXERCISES}
insert("exercises", [{"id": ex[n], "owner_id": coach, "name": n, "notes": None} for n in EXERCISES])

# --- mesociclo ---------------------------------------------------------------------------------------------------
WEEKS, DELOAD = 8, 8
today = date.today()
start = today - timedelta(days=7)  # oggi è la settimana 2
M = demo_id("mesocycle")
insert("mesocycles", [{
    "id": M, "athlete_id": athlete, "name": "Ipertrofia · blocco 1", "start_date": start.isoformat(), "weeks": WEEKS,
    "deload_weeks": [DELOAD], "status": "active", "coach_notes": "Scalda bene prima del top set e annota le sensazioni.",
}])

# Sedute: [(nome, [gruppo: (tipo, [slot: (esercizio, [blocchi: (ruolo, serie, rip min, rip max, recupero s)])])])]
BUF = [3, 3, 2, 2, 1, 1, 0, 4]  # ripetizioni in riserva per settimana (l'ultima è lo scarico)
SESSIONS = [
    ("Spinta", [
        ("single", [("Panca piana", [("top", 1, 5, 5, 180), ("backoff", 2, 8, 10, 120)])]),
        ("superset", [("Croci ai cavi", [("working", 3, 10, 12, 0)]), ("Alzate laterali", [("working", 3, 12, 15, 0)])]),
    ]),
    ("Tirata", [
        ("single", [("Lat machine", [("working", 3, 8, 10, 120)])]),
        ("single", [("Rematore con manubrio", [("working", 3, 8, 10, 120)])]),
        ("single", [("Curl con manubri", [("working", 3, 10, 12, 90)])]),
    ]),
    ("Gambe", [
        ("single", [("Squat", [("top", 1, 5, 5, 240), ("backoff", 2, 8, 8, 150)])]),
        ("single", [("Leg curl", [("working", 3, 10, 12, 90)])]),
    ]),
]

sessions, groups, slots, blocks, weeks_rows = [], [], [], [], []
block_index = {}  # (seduta, esercizio, ruolo) -> id blocco
for s_pos, (s_name, s_groups) in enumerate(SESSIONS):
    S = demo_id(f"session/{s_name}")
    sessions.append({"id": S, "mesocycle_id": M, "position": s_pos, "name": s_name, "coach_notes": None})
    for g_pos, (kind, g_slots) in enumerate(s_groups):
        G = demo_id(f"group/{s_name}/{g_pos}")
        groups.append({
            "id": G, "mesocycle_id": M, "session_id": S, "position": g_pos, "kind": kind,
            "rest_between_s": 15 if kind != "single" else 0, "rest_after_round_s": 90 if kind != "single" else 0,
        })
        for sl_pos, (ex_name, ex_blocks) in enumerate(g_slots):
            SL = demo_id(f"slot/{s_name}/{ex_name}")
            slots.append({"id": SL, "mesocycle_id": M, "group_id": G, "position": sl_pos, "exercise_id": ex[ex_name], "coach_notes": None})
            top_id = None
            for b_pos, (role, sets, rmin, rmax, rest) in enumerate(ex_blocks):
                B = demo_id(f"block/{s_name}/{ex_name}/{role}")
                if role == "top":
                    top_id = B
                block_index[(s_name, ex_name, role)] = B
                blocks.append({
                    "id": B, "mesocycle_id": M, "slot_id": SL, "position": b_pos, "role": role, "technique": "none",
                    "rest_s": rest or None, "ref_block_id": top_id if role == "backoff" else None,
                })
                for w in range(1, WEEKS + 1):
                    deload = w == DELOAD
                    row = {
                        "id": demo_id(f"week/{B}/{w}"), "mesocycle_id": M, "block_id": B, "week": w,
                        "sets": max(sets - 1, 1) if deload else sets, "reps_min": rmin, "reps_max": rmax,
                        "method": None, "intensity_value": None, "ref_pct": None,
                    }
                    if role == "backoff":
                        row["ref_pct"] = 85
                    else:
                        row["method"], row["intensity_value"] = "BUF", BUF[w - 1]
                    weeks_rows.append(row)

insert("sessions", sessions)
insert("slot_groups", groups)
insert("slots", slots)
# I back-off puntano al top set (chiave esterna): i top si inseriscono per primi.
insert("set_blocks", [b for b in blocks if b["ref_block_id"] is None])
insert("set_blocks", [b for b in blocks if b["ref_block_id"] is not None])
insert("block_weeks", weeks_rows)

# --- settimana 1 già registrata -----------------------------------------------------------------------------------
LOADS = {  # (seduta, esercizio): carico del primo set della settimana 1 (kg)
    ("Spinta", "Panca piana"): 90, ("Spinta", "Croci ai cavi"): 15, ("Spinta", "Alzate laterali"): 8,
    ("Tirata", "Lat machine"): 55, ("Tirata", "Rematore con manubrio"): 28, ("Tirata", "Curl con manubri"): 14,
    ("Gambe", "Squat"): 110, ("Gambe", "Leg curl"): 40,
}
workouts, logs, segments = [], [], []
for day, (s_name, s_groups) in enumerate(SESSIONS):
    S = demo_id(f"session/{s_name}")
    W = workout_id(S, 1)
    stamp = datetime.combine(start + timedelta(days=day * 2), time(18, 30), tzinfo=timezone.utc)
    workouts.append({
        "id": W, "athlete_id": athlete, "mesocycle_id": M, "session_id": S, "week": 1, "athlete_notes": None, "deleted_at": None,
    })
    for _, g_slots in s_groups:
        for ex_name, ex_blocks in g_slots:
            for role, sets, rmin, rmax, _rest in ex_blocks:
                B = block_index[(s_name, ex_name, role)]
                base = LOADS[(s_name, ex_name)]
                for idx in range(sets):
                    L = set_log_id(W, B, idx)
                    load = round(base * (0.85 if role == "backoff" else 1.0) / 2.5) * 2.5
                    effort = 3.0 if role == "top" else None
                    logs.append({
                        "id": L, "athlete_id": athlete, "mesocycle_id": M, "workout_id": W, "block_id": B, "set_idx": idx,
                        "effort_value": effort, "effort_scale": "BUF" if effort is not None else None,
                        "done_at": (stamp + timedelta(minutes=idx * 4)).isoformat(), "deleted_at": None,
                    })
                    segments.append({
                        "id": segment_id(L, 0), "athlete_id": athlete, "set_log_id": L, "seg_idx": 0, "load_kg": load,
                        "reps": rmax, "deleted_at": None,
                    })
insert("workouts", workouts)
insert("set_logs", logs)
insert("set_segments", segments)

# --- macro (li scrive il coach, con la dichiarazione) ------------------------------------------------------------
# Il consenso dell'atleta non si dà qui: il revisore vede la schermata del consenso prima di registrare un giorno.
P = demo_id("nutrition-plan")
insert("nutrition_plans", [{
    "id": P, "athlete_id": athlete, "author_id": coach, "kind": "macros", "valid_from": start.isoformat(), "tolerance_pct": 10,
    "declared_at": datetime.now(timezone.utc).isoformat(), "declaration_version": "2026-10-16", "deleted_at": None,
}])
insert("nutrition_plan_days", [{
    "id": demo_id("nutrition-plan/all"), "plan_id": P, "day_type": "all", "kcal": 2800, "protein_g": 180, "carbs_g": 330,
    "fat_g": 80, "fiber_g": 30,
}])

print(f"Demo pronta su {url}")
print(f"  coach : {COACH_EMAIL}")
print(f"  atleta: {ATHLETE_EMAIL}  (mesociclo «Ipertrofia · blocco 1», oggi settimana 2, settimana 1 registrata, macro 2800 kcal)")
print("La password è quella che hai passato in REVIEW_PASSWORD: scrivila nelle note per il revisore su App Store Connect.")
