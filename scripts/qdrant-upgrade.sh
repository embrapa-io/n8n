#!/usr/bin/env bash
# Atualiza o Qdrant do n8n.embrapa.io uma versão menor por vez, como o Qdrant exige
# (https://qdrant.tech/documentation/upgrades/: nem num nó único se pode pular versões).
#
# Para cada versão informada, em ordem: recria só o contêiner do Qdrant com ela, espera
# subir e confere a versão e a contagem de pontos de TODAS as coleções contra o estado
# anterior. Qualquer divergência interrompe o script, na última versão boa.
#
# Antes de tudo faz o backup da stack (serviço "backup", com snapshot do Qdrant) e pede
# confirmação. A versão de cada etapa concluída é gravada em QDRANT_VERSION no .env, para
# o update.sh diário não pular para a versão padrão do compose no meio do caminho.
#
#   cd ~/n8n   # a pasta deste repositório no servidor
#   sudo ./scripts/qdrant-upgrade.sh v1.14.1 v1.15.5 v1.16.3 v1.17.1 v1.18.3 v1.19.2 v1.20.0
#   sudo ./scripts/qdrant-upgrade.sh --yes v1.21.2      # sem perguntar
#
# A primeira versão pode ser igual à que está rodando: serve para validar uma mudança no
# compose (como a montagem do volume) sem trocar de versão.
#
# A chave da API do Qdrant é lida do .env e passada ao curl pela entrada padrão: não
# aparece na tela, no histórico nem na lista de processos.

set -euo pipefail

YES=0
VERSIONS=()
for arg in "$@"; do
  case "$arg" in
    --yes) YES=1 ;;
    v[0-9]*) VERSIONS+=("$arg") ;;
    *) echo "Argumento inválido: «$arg». Uso: $0 [--yes] vX.Y.Z [vX.Y.Z ...]" >&2; exit 2 ;;
  esac
done

[ "${#VERSIONS[@]}" -gt 0 ] || { echo "Uso: $0 [--yes] vX.Y.Z [vX.Y.Z ...]" >&2; exit 2; }

for v in "${VERSIONS[@]}"; do
  printf '%s' "$v" | grep -Eq '^v1\.[0-9]+\.[0-9]+$' || { echo "Versão inválida: «$v» (esperado v1.MINOR.PATCH)" >&2; exit 2; }
done

minor() { echo "$1" | sed -E 's/^v?1\.([0-9]+)\..*/\1/'; }

# Ordem e passo: cada versão sobe no máximo uma versão menor em relação à anterior.
prev=""
for v in "${VERSIONS[@]}"; do
  if [ -n "$prev" ]; then
    d=$(( $(minor "$v") - $(minor "$prev") ))
    if [ "$d" -lt 0 ] || [ "$d" -gt 1 ]; then
      echo "Sequência inválida: de $prev para $v. Suba uma versão menor por vez." >&2
      exit 2
    fi
  fi
  prev="$v"
done

cd "$(dirname "$0")/.."
[ -f docker-compose.yaml ] || { echo "docker-compose.yaml não encontrado em $(pwd)" >&2; exit 1; }
[ -f .env ] || { echo ".env não encontrado em $(pwd)" >&2; exit 1; }

envval() { grep -E "^$1=" .env | tail -n 1 | cut -d= -f2- | tr -d "\"'"; }

KEY="$(envval QDRANT_API_KEY)"
PORT="$(envval PORT_QDRANT)"
VOLUME="$(envval VOLUME_QDRANT)"
[ -n "$KEY" ] || { echo "QDRANT_API_KEY vazia ou ausente no .env" >&2; exit 1; }
[ -n "$PORT" ] || { echo "PORT_QDRANT vazia ou ausente no .env" >&2; exit 1; }
[ -n "$VOLUME" ] || { echo "VOLUME_QDRANT vazia ou ausente no .env" >&2; exit 1; }

docker compose ps --status running --services 2>/dev/null | grep -qx qdrant || { echo "O serviço qdrant não está rodando" >&2; exit 1; }

# O compose monta os subdiretórios storage/ e snapshots/ do volume: eles precisam existir.
for d in storage snapshots; do
  docker run --rm -v "$VOLUME":/v:ro alpine test -d "/v/$d" || { echo "O volume $VOLUME não tem o diretório $d/" >&2; exit 1; }
done

q() { # $1 = caminho da API
  printf 'api-key: %s\n' "$KEY" | curl -fsS --max-time 20 -H @- "http://127.0.0.1:$PORT$1"
}

version() { q / | sed -E 's/.*"version":"([^"]+)".*/\1/'; }

# Estado: "coleção pontos" por linha, em ordem.
state() {
  local cols c n
  cols="$(q /collections | grep -oE '"name":"[^"]+"' | cut -d'"' -f4 | sort)"
  for c in $cols; do
    n="$(q "/collections/$c" | grep -oE '"points_count":[0-9]+' | cut -d: -f2)"
    echo "$c ${n:-?}"
  done
}

wait_up() {
  local i
  for i in $(seq 1 90); do
    version >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

CURRENT="$(version)"
BEFORE="$(state)"

echo "Qdrant em execução: $CURRENT"
echo "Coleções e pontos:"
echo "$BEFORE" | sed 's/^/  /'
echo "Etapas: ${VERSIONS[*]}"

first_minor="$(minor "${VERSIONS[0]}")"
cur_minor="$(minor "v$CURRENT")"
d=$(( first_minor - cur_minor ))
if [ "$d" -lt 0 ] || [ "$d" -gt 1 ]; then
  echo "A primeira etapa (${VERSIONS[0]}) não pode sair de $CURRENT: suba uma versão menor por vez." >&2
  exit 2
fi

if [ "$YES" -ne 1 ]; then
  read -r -p "Fazer o backup e seguir com as etapas? [s/N] " answer
  case "$answer" in s|S|sim|SIM) ;; *) echo "Nada mudou."; exit 0 ;; esac
fi

echo "Backup da stack (pg_dump, n8n e snapshot do Qdrant)..."
docker compose --profile cli run --rm backup >/dev/null
echo "Backup concluído: $(ls -t backup/*.tar.gz 2>/dev/null | head -n 1)"

setenv() { # grava QDRANT_VERSION no .env (reescreve no mesmo arquivo, mantendo dono e permissões)
  local tmp
  tmp="$(mktemp)"
  grep -vE '^QDRANT_VERSION=' .env > "$tmp" || true
  printf 'QDRANT_VERSION=%s\n' "$1" >> "$tmp"
  cat "$tmp" > .env
  rm -f "$tmp"
}

for v in "${VERSIONS[@]}"; do
  echo "== $v"
  QDRANT_VERSION="$v" docker compose up -d --no-deps --force-recreate --wait qdrant >/dev/null
  wait_up || { echo "O Qdrant $v não respondeu. Veja: docker compose logs --tail 100 qdrant" >&2; exit 1; }

  got="$(version)"
  if [ "v$got" != "$v" ]; then
    echo "O contêiner subiu, mas o Qdrant responde $got em vez de $v." >&2
    exit 1
  fi

  after="$(state)"
  if [ "$after" != "$BEFORE" ]; then
    echo "As coleções mudaram em $v:" >&2
    diff <(echo "$BEFORE") <(echo "$after") >&2 || true
    exit 1
  fi

  setenv "$v"
  echo "   ok: versão $got, coleções iguais"
done

echo "Concluído: Qdrant em ${VERSIONS[${#VERSIONS[@]}-1]} (gravado em QDRANT_VERSION no .env)."
echo "Fixe essa versão no docker-compose.yaml do repositório e remova QDRANT_VERSION do .env depois do git pull."
