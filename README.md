### %GENESIS_PROJECT_NAME%
# %GENESIS_PROJECT_UNIX% / %GENESIS_APP_UNIX%

Instancia no cluster o automatizador de fluxograma [N8N](https://n8n.io), bem como containers do [PGVector](https://github.com/pgvector/pgvector) e do [WAHA - WhatsApp API](https://waha.devlike.pro).

Baseado na [configuração de _deploy_ do N8B usando Docker](https://docs.n8n.io/hosting/installation/server-setups/docker-compose/).

## Deploy

> **Atenção!** No MacOS faça: `docker pull devlikeapro/waha:arm && docker tag devlikeapro/waha:arm devlikeapro/waha:latest`.

Criação dos volumes:

```
docker volume create %GENESIS_PROJECT_UNIX%_%GENESIS_APP_UNIX%_development_db && \
docker volume create %GENESIS_PROJECT_UNIX%_%GENESIS_APP_UNIX%_development_data && \
docker volume create %GENESIS_PROJECT_UNIX%_%GENESIS_APP_UNIX%_development_vector && \
docker volume create %GENESIS_PROJECT_UNIX%_%GENESIS_APP_UNIX%_development_pgadmin && \
docker volume create %GENESIS_PROJECT_UNIX%_%GENESIS_APP_UNIX%_development_waha && \
docker volume create --driver local --opt type=none --opt device=$(pwd)/backup --opt o=bind %GENESIS_PROJECT_UNIX%_%GENESIS_APP_UNIX%_development_backup
```

Configuração das variáveis de ambiente:

```
cp .env.example .env
cp .env.io.example .env.io
```

Subir a _stack_ de containers:

```
env $(cat .env.io) docker compose up --force-recreate --build --remove-orphans --wait
```

## Referências

- https://www.youtube.com/watch?v=g3sXsi_OYqQ&t=1575s
- https://comunidadezdg.com.br/waha-n8n/
- https://waha.devlike.pro/docs/overview/quick-start/
