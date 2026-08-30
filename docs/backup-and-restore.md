# Backup e restauração

## O que é protegido

| Item | Origem | Obrigatório |
|---|---|---|
| Banco SQLite | `data/db.sqlite3` | Sim |
| Anexos | `data/attachments/` | Sim |
| Sends | `data/sends/` | Opcional |
| Chaves RSA | `data/rsa_key.*` | Sim |
| Configuração | `config.json` (se existir) | Sim |
| Compose e operação | `compose.yaml`, `OPERACAO.md` | Sim |

## Backup local (diário)

O script `scripts/backup-vaultwarden.sh` executa:

1. backup nativo do banco via `docker exec vaultwarden /vaultwarden backup`;
2. pausa momentânea do contêiner para copiar o banco e arquivos de forma consistente;
3. `PRAGMA integrity_check` no SQLite;
4. empacotamento `tar --zstd` com manifesto;
5. gravação e verificação do SHA-256;
6. retenção: mantém as 14 cópias mais recentes.

Timer systemd:

```bash
systemctl enable --now vaultwarden-backup.timer
journalctl -u vaultwarden-backup.service
```

## Cópia off-host (diária, criptografada)

- O host de backup puxa o arquivo mais recente via SSH e valida o SHA-256 localmente.
- O arquivo é gravado em repositório **Restic** (`restic backup`) com repositório local no host principal.
- A senha do repositório fica em arquivo protegido (`0600`), fora do Git.
- Retenção: `--keep-daily 14 --keep-weekly 8 --keep-monthly 6`.
- Verificação: `restic check --read-data-subset=100%`.

```bash
set -a; . /etc/restic/vaultwarden.env; set +a   # RESTIC_REPOSITORY e RESTIC_PASSWORD
restic snapshots
restic check --read-data-subset=100%
```

## Teste de restauração

Fluxo validado:

```bash
restic restore latest --target /tmp/restore
(cd /tmp/restore && sha256sum -c *.sha256)
tar --zstd -xf <backup>.tar.zst -C extracted/
# integrity check
sqlite3 extracted/data/db.sqlite3 "PRAGMA integrity_check;"
# contêiner descartável com os dados restaurados
docker run -d --rm --name vaultwarden-restore-test \
  --user 1000:1000 --cap-drop ALL --security-opt no-new-privileges:true \
  -e DOMAIN=http://127.0.0.1:18222 -e SIGNUPS_ALLOWED=false \
  -v extracted/data:/data -p 127.0.0.1:18222:80 \
  vaultwarden/server:1.37.2@sha256:094b5689ed81549bd293418395c7cf495ae9d960fc2d4928cef2083ef913d912
curl -fsS http://127.0.0.1:18222/alive
```

Critérios de sucesso:

- SHA-256 confere;
- `integrity_check` retorna `ok`;
- contêiner restaurado inicia com HTTP 200 em `/alive`;
- dados (banco e anexos) presentes no volume montado.

## Riscos e mitigação

- **Perda do host:** a cópia off-host em repositório Restic permite restauração em qualquer máquina com Docker.
- **Corrupção do banco:** `PRAGMA integrity_check` detecta antes do empacotamento.
- **Erro humano:** retenção versionada (14d/8s/6m) permite recuperar versões anteriores.
- **Senha do Restic perdida:** sem ela os dados não são recuperáveis — guarde em cofre separado.
