# Operação

## Acesso

- Aplicação local: `http://127.0.0.1:8222/alive`
- Tailnet HTTPS: `https://<seu-dominio-tailnet>:8443/`
- Após a primeira conta, o cadastro é desabilitado automaticamente (via `vaultwarden-signup-guard.timer`).

## Verificações diárias

```bash
docker inspect --format '{{.State.Status}}/{{.State.Health.Status}} restarts={{.RestartCount}}' vaultwarden
curl -fsS http://127.0.0.1:8222/alive
systemctl is-active vaultwarden-backup.timer vaultwarden-offsite-backup.timer
```

Checagem da API:

```bash
curl -fsS http://127.0.0.1:8222/api/config
```

Campo `settings.disableUserRegistration` deve ser `true` após a primeira conta.

## Atualização

1. Registre a versão atual e crie um backup (`systemctl start vaultwarden-backup.service`).
2. Consulte o release notes do Vaultwarden.
3. Atualize a tag e o digest no `compose.yaml`.
4. `docker compose pull && docker compose up -d`.
5. Valide `/alive`, login e backup seguinte.

Nunca use `latest` em produção sem pinagem por digest.

## Manutenção

- **Disk:** `df -h /opt/vaultwarden /backup`.
- **Retenção:** o script local mantém 14 cópias; o Restic mantém 14 diários, 8 semanais e 6 mensais.
- **Logs:** `docker logs vaultwarden --tail 100`.
- **Restauração:** veja `docs/backup-and-restore.md`.

## Incidentes

### Contêiner reiniciando (crash loop)

```bash
docker logs vaultwarden --tail 80
```

Verifique permissões do volume (`1000:1000`) e espaço em disco.

### Cadastro aberto indevidamente

Verifique `GET /api/config`; se `disableUserRegistration` for `false`, execute:

```bash
cd /opt/vaultwarden
sed -i 's/SIGNUPS_ALLOWED: "true"/SIGNUPS_ALLOWED: "false"/' compose.yaml
docker compose up -d
```

### Backup ausente

```bash
systemctl start vaultwarden-backup.service
journalctl -u vaultwarden-backup.service -n 50
```

## Segredos

- Nenhum segredo é versionado.
- A senha do repositório Restic fica em arquivo `0600` (`/etc/restic/vaultwarden.env`) e em cofre de senhas do operador.
- A senha mestra do cofre nunca é armazenada em arquivos do servidor.
