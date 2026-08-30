# Política de segurança

Este repositório publica apenas documentação e exemplos sanitizados. Não abra uma issue pública para relatar uma vulnerabilidade ou possível exposição de credencial.

## Relatar uma vulnerabilidade

Use o recurso **Private vulnerability reporting** do GitHub quando ele estiver habilitado no repositório. Se esse recurso ainda não estiver disponível, contate a equipe responsável por um canal privado já estabelecido.

Não inclua dados pessoais, senhas, tokens, endereços internos, arquivos de configuração de produção ou evidências que permitam acesso ao ambiente.

## Conteúdo proibido

Contribuições não podem incluir:

- credenciais e tokens
- chaves privadas, incluindo chaves SSH
- arquivos `.env`
- cookies e sessões
- bancos de dados, dumps e backups
- logs de produção
- endereços internos ou identificadores únicos
- configurações operacionais sem sanitização
- dados de usuários, clientes ou estações

## Validação antes do commit

Revise cada arquivo individualmente. Execute uma varredura de segredos e confirme que exemplos usam placeholders reconhecíveis. Não use comandos de inclusão ampla, como `git add .`, em diretórios operacionais.

Se um segredo entrar no histórico, remova-o do histórico completo e rotacione a credencial antes de qualquer publicação.
