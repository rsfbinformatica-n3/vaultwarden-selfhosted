# Arquitetura

## Objetivo

Executar um cofre de senhas compatível com Bitwarden em infraestrutura própria, com:

- persistência local;
- HTTPS confiável;
- acesso restrito à tailnet;
- backup consistente e restauração testada;
- bloqueio de cadastro público;
- consumo de recursos compatível com o host.

## Topologia

```text
Clientes Bitwarden
        │
      HTTPS
        │
Tailscale Serve (:8443)
        │
        ▼
vaultwarden container (127.0.0.1:8222)
        │
        ▼
./data (SQLite + anexos + chaves RSA)
        │
        ├── backup local diário (tar.zst + SHA-256)
        └── cópia off-host (Restic criptografado)
```

## Decisões

### Vaultwarden em vez do Bitwarden oficial

- Implementação alternativa da API do Bitwarden, escrita em Rust, ideal para hospedagem própria e consumo reduzido de memória.
- Implantação oficial é pesada (múltiplos serviços); Vaultwarden roda em um único contêiner pequeno.
- Compatível com os clientes oficiais Bitwarden (apps, extensões, Web Vault).

### SQLite

- Implantação de um usuário, sem concorrência alta: SQLite é suficiente e simplifica o backup.
- O backup usa o mecanismo nativo (`/vaultwarden backup`), que produz uma cópia consistente do banco mesmo com o contêiner em execução.

### HTTPS via Tailscale Serve

- O Tailscale emite certificados confiáveis automaticamente para o nome da tailnet (`.ts.net`).
- Os clientes Bitwarden exigem HTTPS; o certificado público do Tailscale elimina a necessidade de certificado próprio.
- Nenhuma porta fica aberta à Internet; o serviço é alcançável apenas dentro da tailnet.

### Bloqueio de cadastro

- `SIGNUPS_ALLOWED` fica em `true` apenas para criar a primeira conta.
- O timer `vaultwarden-signup-guard` detecta a primeira conta, reconfigura para `false`, recria o contêiner, valida o bloqueio e desativa o próprio timer.
- Convites e dicas de senha permanecem desativados.

### Container sem privilégios

- Usuário `1000:1000`, `cap_drop: ALL`, `no-new-privileges`, limites de memória e CPU.
- Painel administrativo desativado (nenhum `ADMIN_TOKEN` configurado).

## Exclusões de segurança

Nunca são publicados ou versionados:

- `.env` e variáveis com segredos;
- `config.json` com valores sensíveis;
- `db.sqlite3`, `db.sqlite3-wal`, `db.sqlite3-shm`;
- `rsa_key.pem`, `rsa_key.der`, `rsa_key.pub.der`;
- `attachments/` e `sends/`;
- backups (`*.tar.zst`), repositório Restic e arquivos `.sha256`;
- endereços internos da tailnet e hostnames operacionais.
