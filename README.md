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

A versão do Qdrant é fixada no `docker-compose.yaml` (`QDRANT_VERSION`), e não `latest`: o Qdrant [não admite pular
versões menores](https://qdrant.tech/documentation/upgrades/), nem num nó único, porque a migração dos dados é feita uma
versão por vez. Para atualizar, use o script, que faz um _backup_, sobe cada versão intermediária no último _patch_ e confere
a coleção em cada etapa:

```
sudo ./scripts/qdrant-upgrade.sh v1.21.3 v1.22.1   # as versões, em ordem
```

Depois, fixe a última versão no `docker-compose.yaml` e faça o _commit_: o `update.sh` diário recria os contêineres com a
versão do repositório.

## Referências

- https://www.youtube.com/watch?v=g3sXsi_OYqQ&t=1575s
- https://qdrant.tech/documentation/upgrades/
