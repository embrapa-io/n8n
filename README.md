# N8N for Embrapa I/O

Instancia o automatizador de fluxograma [N8N](https://n8n.io), bem como o banco vetorial [Qdrant](https://qdrant.tech/).

Baseado na [configuração de _deploy_ do N8N usando Docker](https://docs.n8n.io/hosting/installation/server-setups/docker-compose/).

## Deploy

Crie a _network_ e os _volumes_ locais:

```
docker volume create io_n8n_db && \
docker volume create io_n8n_data && \
docker volume create io_n8n_qdrant && \
docker volume create io_n8n_pgadmin && \
docker volume create --driver local --opt type=none --opt device=$(pwd)/backup --opt o=bind io_n8n_backup
```

O Qdrant monta só os subdiretórios `storage` e `snapshots` do volume (`subpath`), que precisam existir antes da primeira
subida:

```
docker run --rm -v io_n8n_qdrant:/v alpine mkdir -p /v/storage /v/snapshots
```

Configure das variáveis de ambiente:

```
cp .env.example .env
```

Suba a _stack_ de containers:

```
docker compose up --force-recreate --build --remove-orphans --wait
```

## Atualização do Qdrant

**Nunca troque a versão do Qdrant editando o `docker-compose.yaml` direto para uma versão distante, nem volte a usar
`latest`.** O Qdrant [não admite pular versões menores](https://qdrant.tech/documentation/upgrades/), nem num nó único: a
migração dos dados é feita uma versão por vez, e cada versão intermediária precisa subir no seu último _patch_. Com `latest`
e o `pull` diário do `update.sh`, um salto de várias versões acabaria acontecendo sozinho.

A versão em uso é a de `QDRANT_VERSION` no `docker-compose.yaml` (`image: qdrant/qdrant:${QDRANT_VERSION:-vX.Y.Z}`).

### Passo a passo

1. **Descubra as versões do caminho.** Veja a versão atual no compose e, nas
   [releases do Qdrant](https://github.com/qdrant/qdrant/releases), o último _patch_ de cada versão menor até o destino.
   Exemplo: de `v1.20.0` para `v1.22.x` são duas etapas, `v1.21.<último>` e `v1.22.<último>`. Leia as notas de cada
   versão em busca de mudanças incompatíveis (a `v1.20.0`, por exemplo, passou a exigir autenticação no gRPC interno).
2. **Rode o script no servidor**, como `root`, na pasta deste repositório, já com o `git pull` feito:

   ```
   ./scripts/qdrant-upgrade.sh v1.21.3 v1.22.1   # as versões, em ordem, uma versão menor por vez
   ```

   O script lista as coleções e os pontos, pede confirmação, faz o _backup_ completo (serviço `backup`, com _snapshot_ do
   Qdrant em `backup/`) e sobe cada versão, conferindo em cada etapa a versão respondida e os pontos de **todas** as
   coleções. Qualquer divergência interrompe na última versão boa. Saltos de versão são recusados. Cada etapa concluída é
   gravada em `QDRANT_VERSION` no `.env`, para o `update.sh` da madrugada não trocar de versão no meio do caminho.
3. **Fixe a versão final no repositório**: troque o padrão de `QDRANT_VERSION` no `docker-compose.yaml`, faça o _commit_ e
   o _push_.
4. **No servidor**, depois do `git pull`, tire a linha do `.env`, para a versão voltar a vir do compose:

   ```
   sed -i '/^QDRANT_VERSION=/d' .env
   ```

5. **Confira**: no log do n8n não pode aparecer `Client version … is incompatible with server version …` (o cliente do
   n8n deve ficar a no máximo uma versão menor do servidor). Uma execução do workflow «RAG - Docs - Gemini» exercita
   leitura e escrita no Qdrant.

### Armadilhas conhecidas

- **Volume em `/qdrant`.** Até 11/2026 o volume era montado em `/qdrant`, o diretório do programa na imagem; o Docker
  copiou para ele o binário da primeira instalação, e toda imagem nova continuava rodando o binário antigo (1.14.1).
  Hoje só `storage/` e `snapshots/` do volume são montados (`subpath`). Não volte a montar o volume inteiro.
- **`failed to get console`.** No servidor, `docker compose` com o terminal interativo na entrada e a saída redirecionada
  (`>/dev/null`) falha ao desenhar o progresso. O script usa `--progress plain` sem redirecionar; mantenha assim.

## Referências

- https://www.youtube.com/watch?v=g3sXsi_OYqQ&t=1575s
- https://qdrant.tech/documentation/upgrades/
