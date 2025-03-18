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

```
docker volume create n8n_db
docker volume create n8n_data

cp .env.example .env

docker-compose up --force-recreate --build --remove-orphans --wait
```

## Configuração

Usuários e senhas padrões:

- System Administrator: sysadmin@thingsboard.org / sysadmin
- Tenant Administrator: tenant@thingsboard.org / tenant
- Customer User: customer@thingsboard.org / customer

## Update

Alterar abaixo o valor '3.6.4' pela versão atual (que será substituída pela nova versão):

```
docker-compose stop && docker-compose pull && docker-compose up -d db
echo '3.6.4' > $(pwd)/data/.upgradeversion
docker run -it --rm \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/thingsboard \
  -e SPRING_DATASOURCE_USERNAME=thingsboard \
  -e SPRING_DATASOURCE_PASSWORD=secret \
  thingsboard/tb-postgres upgrade-tb.sh
docker compose rm thingsboard
docker-compose up --force-recreate --build --remove-orphans --wait
```
