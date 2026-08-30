# Manifesto de pré-publicação — Vaultwarden Self-Hosted

## Escopo

- Repositório de documentação da implantação do cofre de senhas Vaultwarden.
- Conteúdo integralmente reconstruído e sanitizado em staging; nenhum arquivo de produção foi copiado.

## Inventário previsto

| Classe | Incluído |
|---|---|
| README, docs, scripts, systemd, compose sanitizado | Sim |
| `.gitignore`, `LICENSE`, `SECURITY.md`, `MANIFEST.md` | Sim |
| `.env`, `config.json`, bancos, dumps, chaves, backups, Restic | **Não** |
| Hostnames internos da tailnet, IPs operacionais | **Não** |
| Segredos, tokens, senhas | **Não** |

## Auditoria executada

| Verificação | Resultado |
|---|---|
| Scanner próprio (nomes, extensões, conteúdo sensível, binários, symlinks) | 16 arquivos, 0 achados |
| `detect-secrets` (uvx) | 0 arquivos, 0 hits |
| `markdownlint-cli2` | aprovado (0 issues) |
| `bash -n` (scripts) | aprovado |
| `systemd-analyze verify` (units) | aprovado; caminhos `/opt/...` são de implantação, não presentes no staging |
| `docker compose config` (compose sanitizado) | aprovado |
| links internos | aprovado |

## Decisões

- Visibilidade: **pública**.
- Licença: **Apache License 2.0**.
- Branch: `main`.
- Nome do repositório: `vaultwarden-selfhosted`.

## Estado do Git

- Diretório ainda **não inicializado** neste momento.
- Após aprovação, será inicializado localmente e o índice será auditado exatamente antes do commit/push.
