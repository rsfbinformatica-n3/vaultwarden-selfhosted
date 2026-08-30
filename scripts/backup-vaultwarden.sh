#!/usr/bin/env bash
# Backup consistente do Vaultwarden.
# Uso: ajuste as variáveis abaixo e agende via systemd (veja systemd/).
set -Eeuo pipefail
umask 077

DATA_DIR=/opt/vaultwarden/data
BACKUP_DIR=/backup/vaultwarden
STACK_DIR=/opt/vaultwarden
LOCK_FILE=/run/lock/vaultwarden-backup.lock
STAMP=$(date -u +%Y%m%d-%H%M%S)
ARCHIVE="$BACKUP_DIR/vaultwarden-$STAMP.tar.zst"
STAGE=$(mktemp -d "$BACKUP_DIR/.stage-$STAMP-XXXXXX")
PAUSED=0

cleanup() {
  if [ "$PAUSED" = 1 ]; then
    docker unpause vaultwarden >/dev/null 2>&1 || true
  fi
  rm -rf -- "$STAGE"
}
trap cleanup EXIT

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

[ "$(docker inspect --format '{{.State.Running}}' vaultwarden 2>/dev/null)" = true ]
install -d -m 0700 "$BACKUP_DIR" "$STAGE/data"

docker exec vaultwarden /vaultwarden backup >/dev/null
LATEST_DB=$(python3 - "$DATA_DIR" <<'PY'
from pathlib import Path
import sys
files = sorted(Path(sys.argv[1]).glob('db_[0-9]*.sqlite3'), key=lambda p: p.stat().st_mtime)
if not files:
    raise SystemExit('nenhum backup SQLite nativo encontrado')
print(files[-1])
PY
)

docker pause vaultwarden >/dev/null
PAUSED=1
install -m 0600 "$LATEST_DB" "$STAGE/data/db.sqlite3"
for item in attachments sends rsa_key.pem rsa_key.der rsa_key.pub.der config.json; do
  if [ -e "$DATA_DIR/$item" ]; then
    cp -a "$DATA_DIR/$item" "$STAGE/data/"
  fi
done
cp -a "$STACK_DIR/compose.yaml" "$STAGE/"
docker unpause vaultwarden >/dev/null
PAUSED=0

python3 - "$STAGE/data/db.sqlite3" <<'PY'
import sqlite3, sys
con = sqlite3.connect(f'file:{sys.argv[1]}?mode=ro', uri=True)
result = con.execute('PRAGMA integrity_check').fetchone()[0]
con.close()
if result != 'ok':
    raise SystemExit(f'integrity_check={result}')
PY

{
  printf 'created_utc=%s\n' "$(date -u --iso-8601=seconds)"
  printf 'vaultwarden_image=%s\n' "$(docker inspect --format '{{.Config.Image}}' vaultwarden)"
  printf 'source_host=%s\n' "$(hostname)"
  printf 'database_integrity=ok\n'
} > "$STAGE/MANIFEST.txt"

tar --zstd -C "$STAGE" -cf "$ARCHIVE" .
chmod 0600 "$ARCHIVE"
tar --zstd -tf "$ARCHIVE" >/dev/null
(
  cd "$BACKUP_DIR"
  sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256"
)
chmod 0600 "$ARCHIVE.sha256"

python3 - "$DATA_DIR" "$BACKUP_DIR" <<'PY'
from pathlib import Path
import sys
live = sorted(Path(sys.argv[1]).glob('db_[0-9]*.sqlite3'), key=lambda p: p.stat().st_mtime, reverse=True)
for p in live[2:]:
    p.unlink()
archives = sorted(Path(sys.argv[2]).glob('vaultwarden-*.tar.zst'), key=lambda p: p.stat().st_mtime, reverse=True)
for p in archives[14:]:
    p.unlink(missing_ok=True)
    Path(str(p) + '.sha256').unlink(missing_ok=True)
PY

printf 'BACKUP=%s\n' "$ARCHIVE"
printf 'INTEGRITY=ok\n'