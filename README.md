# N8N for Embrapa I/O

Instancia o automatizador de fluxograma [N8N](https://n8n.io), bem como containers do [Qdrant](https://qdrant.tech/) e do [WAHA - WhatsApp API](https://waha.devlike.pro).

Baseado na [configuração de _deploy_ do N8N usando Docker](https://docs.n8n.io/hosting/installation/server-setups/docker-compose/).

## Deploy

> **Atenção!** No MacOS faça: `docker pull devlikeapro/waha:arm && docker tag devlikeapro/waha:arm devlikeapro/waha:latest`.

Crie a _network_ e os _volumes_ locais:

```
docker volume create io_n8n_db && \
docker volume create io_n8n_data && \
docker volume create io_n8n_qdrant && \
docker volume create io_n8n_pgadmin && \
docker volume create io_n8n_waha && \
docker volume create --driver local --opt type=none --opt device=$(pwd)/backup --opt o=bind io_n8n_backup
```

Configure das variáveis de ambiente:

```
cp .env.example .env
```

Suba a _stack_ de containers:

```
docker compose up --force-recreate --build --remove-orphans --wait
```

## Community Nodes

É necessário [instalar dois _community nodes_](https://docs.n8n.io/integrations/community-nodes/installation/gui-install/#install-a-community-node) para utilizar os _workflows_ como **MCP Servers** e com a **WAHA WhatsApp API**, respectivamente:

- `@devlikeapro/n8n-nodes-waha`

## Referências

- https://www.youtube.com/watch?v=g3sXsi_OYqQ&t=1575s
- https://comunidadezdg.com.br/waha-n8n/
- https://waha.devlike.pro/docs/overview/quick-start/
