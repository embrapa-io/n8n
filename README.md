# N8N for Embrapa I/O

Configuração de deploy do [N8N](https://github.com/n8n-io/n8n) (_workflow automation_) no ecossistema do Embrapa I/O.

Baseado na [configuração de _deploy_ do N8B usando Docker](https://docs.n8n.io/hosting/installation/server-setups/docker-compose/).

## Ollama

No MacOS não é possível expor a GPU para o Docker. Assim, é necessário instalar o Ollama diretamente no SO.

```
brew install ollama
brew services start ollama
ollama pull gemma3:4b
```

## Deploy

> **Atenção!** No MacOS faça: `docker pull devlikeapro/waha:arm && docker tag devlikeapro/waha:arm devlikeapro/waha:latest`.

Criação dos volumes:

```
docker volume create n8n_db && \
docker volume create n8n_data && \
docker volume create n8n_vector && \
docker volume create n8n_pgadmin && \
docker volume create n8n_waha
```

Configuração das variáveis de ambiente:

```
cp .env.example .env
```

Subir a _stack_ de containers:

```
docker compose up --force-recreate --build --remove-orphans --wait
```

## Referências

- https://www.youtube.com/watch?v=g3sXsi_OYqQ&t=1575s
- https://comunidadezdg.com.br/waha-n8n/
- https://waha.devlike.pro/docs/overview/quick-start/
