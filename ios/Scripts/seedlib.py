"""Piccola libreria per gli script di seed (locale e account demo): chiamate REST con la service_role."""
import json, sys, urllib.request


class Api:
    def __init__(self, url, service_key):
        self.url = url.rstrip("/")
        self.key = service_key

    def call(self, method, path, body=None, prefer=None):
        req = urllib.request.Request(
            self.url + path, method=method, data=json.dumps(body).encode() if body is not None else None
        )
        req.add_header("apikey", self.key)
        req.add_header("Authorization", f"Bearer {self.key}")
        req.add_header("Content-Type", "application/json")
        if prefer:
            req.add_header("Prefer", prefer)
        try:
            with urllib.request.urlopen(req) as r:
                data = r.read()
                return json.loads(data) if data else None
        except urllib.error.HTTPError as e:
            raise SystemExit(f"{method} {path}: {e.code} {e.read().decode()}")

    def user(self, email, password, full_name=None):
        """Crea l'utente (email già confermata) o, se c'è, ne riallinea la password. Restituisce l'id."""
        found = self.call("GET", f"/rest/v1/profiles?email=eq.{email}&select=id")
        if found:
            uid = found[0]["id"]
            self.call("PUT", f"/auth/v1/admin/users/{uid}", {"password": password, "email_confirm": True})
        else:
            uid = self.call("POST", "/auth/v1/admin/users", {"email": email, "password": password, "email_confirm": True})["id"]
        if full_name:
            self.call("PATCH", f"/rest/v1/profiles?id=eq.{uid}", {"full_name": full_name}, prefer="return=minimal")
        return uid

    def insert(self, table, rows, conflict="id"):
        """Upsert: rieseguire lo script aggiorna le righe invece di duplicarle. Tutte le righe con le stesse chiavi."""
        keys = set(rows[0])
        assert all(set(r) == keys for r in rows), f"{table}: chiavi diverse tra le righe (PostgREST le vuole uguali)"
        self.call("POST", f"/rest/v1/{table}?on_conflict={conflict}", rows, prefer="resolution=merge-duplicates,return=minimal")
