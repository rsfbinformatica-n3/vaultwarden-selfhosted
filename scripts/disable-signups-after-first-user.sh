#!/usr/bin/env bash
# Desabilita o cadastro do Vaultwarden automaticamente após a primeira conta.
# Instale como serviço/timer systemd (veja systemd/vaultwarden-signup-guard.*).
set -Eeuo pipefail

DB=/opt/vaultwarden/data/db.sqlite3
COMPOSE=/opt/vaultwarden/compose.yaml
LOCK=/run/lock/vaultwarden-signup-guard.lock

exec 9>"$LOCK"
flock -n 9 || exit 0
[ -r "$DB" ] || exit 0

COUNT=$(python3 - "$DB" <<'PY'
import sqlite3, sys
con = sqlite3.connect(f'file:{sys.argv[1]}?mode=ro', uri=True)
count = con.execute('SELECT COUNT(*) FROM users').fetchone()[0]
con.close()
print(count)
PY
)

[ "$COUNT" -ge 1 ] || exit 0

python3 - "$COMPOSE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = '      SIGNUPS_ALLOWED: "true"'
new = '      SIGNUPS_ALLOWED: "false"'
if old in s:
    s = s.replace(old, new, 1)
elif new not in s:
    raise SystemExit('SIGNUPS_ALLOWED não encontrado no formato esperado')
p.write_text(s)
p.chmod(0o600)
PY

cd /opt/vaultwarden
docker compose up -d vaultwarden
for _ in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:8222/api/config | python3 -c 'import json, sys; raise SystemExit(json.load(sys.stdin).get("settings", {}).get("disableUserRegistration") is not True)'; then
    systemctl start vaultwarden-backup.service
    systemctl disable vaultwarden-signup-guard.timer >/dev/null 2>&1 || true
    systemctl stop vaultwarden-signup-guard.timer >/dev/null 2>&1 || true
    printf 'SIGNUPS_DISABLED=ok USERS=%s\n' "$COUNT"
    exit 0
  fi
  sleep 2
done

exit 1