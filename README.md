# Vaultwarden Self-Hosted — Cofre de Senhas

Servidor de cofre de senhas **auto-hospedado e compatível com Bitwarden**, baseado no [Vaultwarden](https://github.com/dani-garcia/vaultwarden), executado em Docker Compose com acesso privado via Tailscale, HTTPS confiável e backup criptografado em Restic.

> Este repositório documenta a implantação e a operação do projeto. Nenhum segredo, banco de dados, chave privada, backup ou configuração de produção é publicado aqui.

## Visão geral

```text
Clientes Bitwarden (apps, extensões, web vault)
                    │
              HTTPS (Tailscale)
                    │
        Tailscale Serve (:8443)
                    │
   ┌────────────────┴───────────────┐
   │  vaultwarden (Docker)          │
   │  imagem 1.37.2 fixada por      │
   │  digest, usuário não-root      │
   │  bind somente em 127.0.0.1     │
   │  volume persistente ./data     │
   └────────────────┬───────────────┘
                    │
        Backup consistente (SQLite)
                    │
   ┌────────────────┴───────────────┐
   │  local: /backup/vaultwarden    │
   │  off-host: Restic criptografado│
   └────────────────────────────────┘
```

- **Acesso:** somente pela malha Tailscale; nenhuma porta exposta à Internet.
- **HTTPS:** certificado emitido pelo próprio Tailscale (confiável pelos clientes Bitwarden).
- **Segurança:** cadastro aberto apenas para a primeira conta, com trava automática; painel administrativo desativado; container sem privilégios.

## Recursos

- Cofre pessoal, Sends, anexos e organização compatíveis com clientes Bitwarden;
- Web Vault embutido;
- API `/api/config` e healthcheck `/alive`;
- molde de implantação em Docker Compose com pinagem por digest;
- responsividade para dispositivos móveis e aplicativos.

## Arquitetura

| Componente   | Detalhe                                        |
|--------------|------------------------------------------------|
| Aplicação    | `vaultwarden/server:1.37.2` (fixada por digest)|
| Banco        | SQLite (arquivo em `data/db.sqlite3`)          |
| Acesso       | Tailscale Serve com HTTPS na porta `8443`      |
| Proxy        | Nenhum proxy público; bind somente em `127.0.0.1:8222` |
| Persistência | Diretório `./data` (anexos, Sends, chaves RSA, banco) |
| Backups      | Local diário + cópia off-host criptografada (Restic) |

## Pré-requisitos

- Host com Docker e Docker Compose V2;
- Tailscale instalado e conectado na mesma tailnet;
- Diretório de dados com proprietário `1000:1000` (container não-root);
- Espaço para `./data` e para o destino de backup.

## Implantação

1. Crie o diretório do projeto:

```bash
install -d -m 0700 /opt/vaultwarden/data
chown 1000:1000 /opt/vaultwarden/data
```

- Ajuste o arquivo `compose.yaml` com o domínio da sua instância (var. `DOMAIN`).

- Inicie o serviço:

```bash
cd /opt/vaultwarden
docker compose config --quiet
docker compose up -d
```

- Exponha na tailnet (HTTPS):

```bash
tailscale serve --bg --https=8443 http://127.0.0.1:8222
```

- Verifique:

```bash
curl -fsS http://127.0.0.1:8222/alive
curl -fsS https://<seu-dominio-tailnet>:8443/
```

## Primeira conta e bloqueio de cadastro

O cadastro fica habilitado somente para a criação da primeira conta. O serviço `vaultwarden-signup-guard` (timer systemd) verifica a quantidade de usuários no banco e, ao detectar a primeira conta:

1. altera `SIGNUPS_ALLOWED` para `false`;
2. recria somente o contêiner do Vaultwarden;
3. valida o bloqueio via `GET /api/config`;
4. executa um backup;
5. desativa o próprio timer.

As variáveis de ambiente recomendadas:

```yaml
SIGNUPS_ALLOWED: "false"        # após a primeira conta
INVITATIONS_ALLOWED: "false"
SHOW_PASSWORD_HINT: "false"
DOMAIN: "https://vault.example.com"
```

## Backups

### Local (diário)

- `scripts/backup-vaultwarden.sh` — gera backup nativo do banco (`/vaultwarden backup`), pausa o contêiner, copia banco, anexos, Sends e chaves RSA, valida `PRAGMA integrity_check`, empacota com `tar --zstd` e grava o SHA-256.
- Timer `vaultwarden-backup.timer` dispara diariamente; retenção de 14 cópias.

### Off-host (diário, criptografado)

- O host principal puxa o backup mais recente via SSH, valida o SHA-256 e grava em repositório **Restic** com senha armazenada fora do Git.
- Política de retenção: 14 diários, 8 semanais, 6 mensais.
- Processo documentado em `docs/backup-and-restore.md`.

## Teste de restauração

A restauração é testada de ponta a ponta:

1. `restic restore latest` em diretório temporário;
2. conferência do SHA-256;
3. `PRAGMA integrity_check` no SQLite;
4. inicialização de um contêiner descartável com os dados restaurados e validação de HTTP 200 em `/`.

Veja `docs/backup-and-restore.md` para o procedimento completo.

## Segurança

- Container executado como usuário não-root (`1000:1000`);
- `cap_drop: ALL` e `no-new-privileges`;
- limites de memória (512 MB) e CPU (1);
- painel administrativo desativado (`ADMIN_TOKEN` não configurado);
- nenhuma porta publicada fora de `127.0.0.1`;
- backups fora do repositório Git e criptografados em repouso;
- `.gitignore` cobre segredos, bancos, chaves e backups.

Nunca publique: `.env`, `config.json`, `db.sqlite3*`, `rsa_key.*`, `attachments/`, `sends/`, backups ou o repositório Restic.

## Estrutura do repositório

```text
.
├── compose.yaml                      # serviço Vaultwarden (sanitizado)
├── LICENSE                           # Apache 2.0
├── SECURITY.md                       # política de segurança
├── .gitignore                        # exclusões de segurança
├── README.md                         # este documento
├── docs/
│   ├── architecture.md               # decisões e topologia
│   ├── backup-and-restore.md         # backup e restauração
│   └── operations.md                 # operação diária
├── scripts/
│   ├── backup-vaultwarden.sh         # backup consistente local
│   └── disable-signups-after-first-user.sh  # trava de cadastro
└── systemd/
    ├── vaultwarden-backup.service
    ├── vaultwarden-backup.timer
    ├── vaultwarden-signup-guard.service
    └── vaultwarden-signup-guard.timer
```

## Roadmap

- [ ] organizações e compartilhamento para múltiplos usuários;
- [ ] integração com monitoramento (Zabbix/Uptime Kuma);
- [ ] alerta de backup no Telegram via n8n;
- [ ] rotação automática do repositório Restic off-host.

## Licença

Apache License 2.0 — veja `LICENSE`.
