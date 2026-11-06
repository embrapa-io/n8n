# n8n do Embrapa I/O (n8n.embrapa.io) — guia para agentes de IA

Stack Docker Compose do n8n da plataforma: `n8n`, `db` (PostgreSQL), `qdrant` (banco vetorial dos assistentes),
`memory` (Redis), `pgadmin` e os serviços de linha de comando `backup` e `sanitize` (perfil `cli`).

- **Servidor:** `n8n.embrapa.io`, repositório clonado em `/root/n8n`. Acesso por `ssh embrapa@n8n.embrapa.io`; o Docker
  exige `root` (o Camilo roda os comandos com `sudo`/como root, o agente não tem a senha).
- **Atualização diária:** o `update.sh` roda às 02:25 (Campo Grande) pelo cron: `git pull`, `docker compose pull` e
  `up --force-recreate --remove-orphans`. Todo commit na `main` entra no servidor na madrugada seguinte, sem ação manual.
  Por isso, nada que exija passo manual no servidor pode ir para a `main` antes de o passo estar pronto para rodar.
- **Logs:** Loki `{host="n8n.embrapa.io", container_name="n8n-n8n-1"}`. Workflows e execuções pelo MCP «claude.ai n8n».

## Qdrant: REGRA ABSOLUTA de atualização

**Nunca pule versões menores do Qdrant, nunca use `latest` e nunca edite a versão no compose para um salto de várias
versões.** O Qdrant migra os dados uma versão menor por vez (https://qdrant.tech/documentation/upgrades/), e o `update.sh`
aplicaria o salto sozinho na madrugada.

Procedimento (detalhado no `README.md`, seção «Atualização do Qdrant»):

1. Levantar o último patch de cada versão menor entre a atual (`QDRANT_VERSION` no `docker-compose.yaml`) e o destino, e
   ler as notas de cada release.
2. Ensaiar localmente antes: subir a versão atual num volume Docker com uma coleção igual à `io_gemini_v4` (3072
   dimensões, Cosine, `on_disk_payload`, índices `keyword` em `metadata.source` e `metadata.video_id`), passar por cada
   versão e comparar pontos, índices, buscas, inserção e remoção. Rodar o script real sob pseudo-TTY (o servidor é
   interativo; sem TTY, erros de console não aparecem).
3. O Camilo roda no servidor `./scripts/qdrant-upgrade.sh <versões em ordem>`: backup, uma etapa por versão, conferência
   de todas as coleções, versão gravada no `.env`.
4. Só depois: fixar a versão final no `docker-compose.yaml` (commit e push) e tirar `QDRANT_VERSION` do `.env` do servidor.
5. Conferir no Loki que sumiu `Client version … is incompatible with server version …`.

Armadilhas já pagas (11/2026):

- O volume montado em `/qdrant` encobria o binário da imagem: o servidor rodou o binário 1.14.1 por mais de um ano com
  imagem `latest`. Só `storage/` e `snapshots/` do volume são montados (`subpath`). Não montar o volume inteiro.
- `docker compose` com stdin em TTY e stdout em `/dev/null` dá `failed to get console` no servidor (no Mac, não).
  Usar `--progress plain` sem redirecionar a saída.

## Outras regras

- O WAHA (API não oficial do WhatsApp) foi removido em 11/2026; não reintroduzir.
- Coleções antigas do Qdrant (`io_openai_*`, `io_gemini_v1`–`v3`, `aest_v1`) seguem no servidor; antes de apagar qualquer
  uma, conferir que nenhum workflow a usa.
