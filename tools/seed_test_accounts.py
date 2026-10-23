"""Demo accounts for the jury, all in one company "Echo Demo", without any email.

    python tools/seed_test_accounts.py

Makes (or refreshes) three accounts with a password on the hosted Supabase and links them:
  admin.demo@echo-app.test    Andrei Ionescu   admin
  ana.demo@echo-app.test      Ana Pop          employee, reads what is said (visual)
  ion.demo@echo-app.test      Ion Ene          employee, hears what is said (standard)
plus a fresh company code, so a fourth person can join live. Real accounts keep signing in with an
emailed code; only these have a password (the app's "Cont de test pentru demo").

Needs SUPABASE_ACCESS_TOKEN in supabase/.env. The password is ECHO_DEMO_PASSWORD there; the script
makes one the first time. The service key is read from the project for this run only, never saved.
Safe to run again: it only resets these three accounts and the demo company.
"""

import json
import secrets
import string
import sys
import urllib.error
import urllib.request
from pathlib import Path

ENV = Path(__file__).resolve().parents[1] / "supabase" / ".env"
PROJECT = "djbbtstcbelgkrfkvdoc"
AUTH = f"https://{PROJECT}.supabase.co/auth/v1"
API = f"https://api.supabase.com/v1/projects/{PROJECT}"
ORG_ID = "00000000-0000-4000-8000-0000000ec400"
ORG_NAME = "Echo Demo"
PEOPLE = [
    ("admin.demo@echo-app.test", "Andrei Ionescu", "admin", "standard"),
    ("ana.demo@echo-app.test", "Ana Pop", "employee", "visual"),
    ("ion.demo@echo-app.test", "Ion Ene", "employee", "standard"),
]
CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"  # as in new_join_code: no 0/O, 1/I/L


def read_env() -> dict[str, str]:
    values = {}
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def call(url: str, token: str | None = None, body=None, method: str | None = None, headers=None):
    request = urllib.request.Request(
        url,
        data=None if body is None else json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "echo-seed", **(headers or {})}
        | ({"Authorization": f"Bearer {token}"} if token else {}),
        method=method or ("POST" if body is not None else "GET"),
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        text = response.read().decode()
        return json.loads(text) if text else None


def sql(token: str, query: str):
    return call(f"{API}/database/query", token, {"query": query})


def quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")  # Romanian letters on a Windows console
    env = read_env()
    token = env.get("SUPABASE_ACCESS_TOKEN") or sys.exit("SUPABASE_ACCESS_TOKEN lipsește din supabase/.env")
    password = env.get("ECHO_DEMO_PASSWORD")
    if not password:
        password = "Echo-Demo-" + "".join(secrets.choice(string.ascii_letters + string.digits) for _ in range(8))
        with ENV.open("a", encoding="utf-8") as f:
            f.write(f"\nECHO_DEMO_PASSWORD={password}\n")

    keys = call(f"{API}/api-keys?reveal=true", token)
    service = next((k["api_key"] for k in keys if k.get("name") == "service_role"), None)
    secret = next((k["api_key"] for k in keys if k.get("type") == "secret"), None)
    # The legacy service key is a JWT; a new secret key goes only in the apikey header.
    admin_headers = (
        {"apikey": service, "Authorization": f"Bearer {service}"} if service else {"apikey": secret or ""}
    )

    ids = {}
    for email, name, _, _ in PEOPLE:
        existing = sql(token, f"select id from auth.users where email = {quote(email)}")
        if existing:
            user_id = existing[0]["id"]
            call(f"{AUTH}/admin/users/{user_id}", body={"password": password, "email_confirm": True},
                 method="PUT", headers=admin_headers)
        else:
            user = call(f"{AUTH}/admin/users", body={"email": email, "password": password, "email_confirm": True},
                        headers=admin_headers)
            user_id = user["id"]
        ids[email] = user_id

    members = ",\n".join(
        f"({quote(ORG_ID)}, {quote(ids[email])}, {quote(role)}, {quote(email)}, {quote(name)}, {quote(kind)}, now())"
        for email, name, role, kind in PEOPLE
    )
    code = "".join(secrets.choice(CODE_ALPHABET) for _ in range(8))
    sql(token, f"""
        begin;
        insert into public.organizations (id, name) values ({quote(ORG_ID)}, {quote(ORG_NAME)})
          on conflict (id) do update set name = excluded.name;
        insert into public.org_members (org_id, user_id, role, email, display_name, experience, experience_confirmed_at)
        values {members}
        on conflict (org_id, user_id) do update set role = excluded.role, email = excluded.email,
          display_name = excluded.display_name, experience = excluded.experience,
          experience_confirmed_at = excluded.experience_confirmed_at;
        update public.profiles p set display_name = v.name
          from (values {", ".join(f"({quote(ids[e])}::uuid, {quote(n)})" for e, n, _, _ in PEOPLE)}) as v (id, name)
          where p.id = v.id;
        insert into public.org_join_codes (org_id, code_hash, created_by, expires_at)
        values ({quote(ORG_ID)}, public.join_code_fingerprint({quote(code)}), {quote(ids[PEOPLE[0][0]])},
                now() + interval '7 days')
        on conflict (org_id) do update set code_hash = excluded.code_hash, created_by = excluded.created_by,
          created_at = now(), expires_at = excluded.expires_at;
        commit;
    """)

    print(f"Compania: {ORG_NAME}")
    for email, name, role, kind in PEOPLE:
        what = "admin" if role == "admin" else ("citește ce se spune" if kind == "visual" else "aude ce se spune")
        print(f"  {email:28} {name:16} {what}")
    print(f"Parola (toate trei): {password}")
    print(f"Codul companiei (7 zile): {code[:4]}-{code[4:]}")


if __name__ == "__main__":
    try:
        main()
    except urllib.error.HTTPError as e:
        sys.exit(f"Eroare {e.code}: {e.read().decode()[:400]}")
