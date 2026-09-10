#!/usr/bin/env bash
set -Eeuo pipefail

# Executa o laboratório técnico da Sessão 3 e guarda a evidência de cada ponto
# num TXT separado. O teste visual no browser e a autenticação GHCR continuam
# a exigir ação externa e nunca são registados secrets reais nos logs.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"
RUN_DIR="${ROOT_DIR}/resultados/lab-${TIMESTAMP}"
SUMMARY="${RUN_DIR}/00_resumo.txt"
ALL_LOG="${RUN_DIR}/99_transcricao_completa.txt"
ENV_FILE="${ROOT_DIR}/formando/compose/.env.prod"
ENV_EXAMPLE="${ROOT_DIR}/formando/compose/.env.prod.example"
BASE_FILE="${ROOT_DIR}/formando/compose/compose.yaml"
PROD_FILE="${ROOT_DIR}/formando/compose/compose.prod.yaml"
PUBLISH_GHCR=0
SKIP_TRIVY=0

usage() {
  cat <<'USAGE'
Uso:
  ./formando/scripts/executar-lab-completo.sh [opções]

Opções:
  --publicar-ghcr  publica 1.0.0, 1.1.0 e 1.2.0-rc1 no IMAGE_REPO;
                   requer docker login prévio e IMAGE_REPO definido.
  --sem-trivy      não executa o scan Trivy.
  -h, --help       mostra esta ajuda.

Pré-requisitos:
  - VM já preparada com Docker Engine, Compose, Buildx, Git, curl e Trivy;
  - utilizador com acesso a Docker sem sudo;
  - executar a partir do repositório da formação ou de qualquer diretoria.

Saída:
  sessao-03/resultados/lab-AAAAmmdd-HHMMSS/
    00_resumo.txt
    NN_nome-do-ponto.txt
    backup.sql
    99_transcricao_completa.txt

Notas:
  - cada ponto grava stdout e stderr no respetivo TXT;
  - a falha da versão 1.2.0-rc1 é esperada e não interrompe o guião;
  - o browser é validado externamente pelo formando; o script grava os URLs.
USAGE
}

while (($#)); do
  case "$1" in
    --publicar-ghcr) PUBLISH_GHCR=1 ;;
    --sem-trivy) SKIP_TRIVY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

mkdir -p "$RUN_DIR"
: > "$SUMMARY"
: > "$ALL_LOG"

printf 'Laboratório Integrado — Sessão 3\nInício: %s\nOutputs: %s\n\n' \
  "$(date -Is)" "$RUN_DIR" | tee -a "$SUMMARY" "$ALL_LOG"

record_status() {
  printf '%-5s | %-10s | rc=%-3s | %s\n' "$1" "$3" "$4" "$2" >> "$SUMMARY"
}

run_step() {
  local id="$1" slug="$2" title="$3" log rc
  shift 3
  log="${RUN_DIR}/${id}_${slug}.txt"

  set +e
  {
    echo "================================================================"
    echo "PONTO ${id} — ${title}"
    echo "Início: $(date -Is)"
    printf 'Comando:'; printf ' %q' "$@"; echo
    echo "----------------------------------------------------------------"
    "$@"
    rc=$?
    echo "----------------------------------------------------------------"
    echo "Fim: $(date -Is)"
    echo "Exit code: ${rc}"
    exit "$rc"
  } 2>&1 | tee "$log" -a "$ALL_LOG"
  rc=${PIPESTATUS[0]}
  set -e

  if ((rc == 0)); then
    record_status "$id" "$title" "OK" "$rc"
  else
    record_status "$id" "$title" "ERRO" "$rc"
    echo "ERRO no ponto ${id}. Consulte: ${log}" >&2
    exit "$rc"
  fi
}

run_expected_failure() {
  local id="$1" slug="$2" title="$3" log rc
  shift 3
  log="${RUN_DIR}/${id}_${slug}.txt"

  set +e
  {
    echo "================================================================"
    echo "PONTO ${id} — ${title}"
    echo "NOTA: é esperada uma falha neste ponto."
    echo "Início: $(date -Is)"
    printf 'Comando:'; printf ' %q' "$@"; echo
    echo "----------------------------------------------------------------"
    "$@"
    rc=$?
    echo "----------------------------------------------------------------"
    echo "Fim: $(date -Is)"
    echo "Exit code observado: ${rc}"
    exit "$rc"
  } 2>&1 | tee "$log" -a "$ALL_LOG"
  rc=${PIPESTATUS[0]}
  set -e

  if ((rc != 0)); then
    record_status "$id" "$title" "ESPERADO" "$rc"
  else
    record_status "$id" "$title" "INESPERADO" "$rc"
    echo "ERRO: o ponto ${id} deveria falhar, mas terminou com sucesso." >&2
    exit 1
  fi
}

run_note() {
  local id="$1" slug="$2" title="$3" text="$4"
  {
    echo "================================================================"
    echo "PONTO ${id} — ${title}"
    echo "Data: $(date -Is)"
    echo "----------------------------------------------------------------"
    printf '%s\n' "$text"
  } | tee "${RUN_DIR}/${id}_${slug}.txt" -a "$ALL_LOG"
  record_status "$id" "$title" "NOTA" "0"
}

run_step "01" "prechecks" "Validar ferramentas e acesso ao Docker" bash -c '
  set -e
  for cmd in docker git curl sed awk grep; do command -v "$cmd"; done
  docker version
  docker compose version
  docker buildx version
  docker info >/dev/null
  echo "OK: Docker acessível sem sudo"
'

if ((SKIP_TRIVY == 0)); then
  run_step "02" "trivy" "Validar Trivy" trivy --version
else
  run_note "02" "trivy" "Validar Trivy" "Ignorado por opção --sem-trivy."
fi

run_step "03" "preparar-source" "Preparar Symfony Demo e endpoints pedagógicos" \
  "${ROOT_DIR}/comum/prepare-source.sh"

run_step "04" "validar-source" "Validar source preparado" bash -c \
  "test -f '${ROOT_DIR}/app/composer.json' && test -f '${ROOT_DIR}/formando/docker/Dockerfile' && echo 'OK: source preparado'"

run_step "05" "build-naive" "Construir imagem inicial symfony-demo:naive" \
  docker build -f "${ROOT_DIR}/formando/docker/Dockerfile.inicial" -t symfony-demo:naive "$ROOT_DIR"

run_step "06" "assets-naive" "Validar assets da imagem inicial" \
  docker run --rm symfony-demo:naive sh -lc \
  'test -f /var/www/html/public/assets/manifest.json && find /var/www/html/public/assets -maxdepth 2 -type f | head -20'

docker rm -f symfony-naive >/dev/null 2>&1 || true
run_step "07" "run-naive" "Executar imagem inicial na porta 8081" \
  docker run -d --name symfony-naive -p 8081:80 symfony-demo:naive

run_step "08" "health-naive" "Validar /health da imagem inicial" bash -c \
  'sleep 3; curl -i http://localhost:8081/health; docker ps --filter name=symfony-naive --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

VM_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
run_note "09" "browser-naive" "Teste no browser da imagem inicial" \
  "Abrir no PC do formando: http://${VM_IP:-IP_DA_VM}:8081/ e http://${VM_IP:-IP_DA_VM}:8081/health . A validação visual é externa ao script."

run_step "10" "stop-naive" "Parar e remover container inicial" bash -c \
  'docker stop symfony-naive && docker rm symfony-naive'

run_step "11" "build-100" "Construir imagem otimizada 1.0.0" \
  "${ROOT_DIR}/formando/scripts/build.sh" 1.0.0
run_step "12" "build-110" "Construir imagem otimizada 1.1.0" \
  "${ROOT_DIR}/formando/scripts/build.sh" 1.1.0
run_step "13" "build-120" "Construir 1.2.0-rc1 com HEALTHCHECK /healthz" \
  "${ROOT_DIR}/formando/scripts/build.sh" 1.2.0-rc1 /healthz

run_step "14" "assets-versoes" "Validar assets nas três versões" bash -c '
  set -e
  for v in 1.0.0 1.1.0 1.2.0-rc1; do
    echo "=== $v ==="
    docker run --rm "symfony-demo:$v" sh -lc \
      "test -f /var/www/html/public/assets/manifest.json && echo OK: assets compilados"
  done
'

run_step "15" "metadata" "Validar labels e HEALTH_PATH" bash -c '
  set -e
  for v in 1.0.0 1.1.0 1.2.0-rc1; do
    echo "=== $v ==="
    docker image inspect "symfony-demo:$v" --format \
      "Version={{index .Config.Labels \"org.opencontainers.image.version\"}} Source={{index .Config.Labels \"org.opencontainers.image.source\"}}"
    docker image inspect "symfony-demo:$v" --format "{{range .Config.Env}}{{println .}}{{end}}" | grep "^HEALTH_PATH="
  done
'

run_step "16" "hardening" "Observar utilizador, tamanhos e layers" bash -c '
  docker image ls symfony-demo
  echo
  docker image inspect symfony-demo:1.1.0 --format "User={{json .Config.User}}"
  docker history symfony-demo:1.1.0
'

run_step "17" "secret-inseguro" "Demonstrar secret persistido via ARG/ENV" bash -c \
  "docker build -f '${ROOT_DIR}/formando/exemplos/secrets/Dockerfile.bad' --build-arg API_TOKEN=segredo-falso-lab -t secret-demo:bad '${ROOT_DIR}/formando/exemplos/secrets' && docker image inspect secret-demo:bad --format '{{json .Config.Env}}'"

run_step "18" "secret-buildkit" "Demonstrar BuildKit secret efémero" bash -c \
  "export API_TOKEN='segredo-falso-buildkit'; docker build -f '${ROOT_DIR}/formando/exemplos/secrets/Dockerfile.secret' --secret id=API_TOKEN,env=API_TOKEN -t secret-demo:buildkit '${ROOT_DIR}/formando/exemplos/secrets'; unset API_TOKEN; docker image inspect secret-demo:buildkit --format '{{json .Config.Env}}'; docker run --rm secret-demo:buildkit"

run_step "19" "secret-compose" "Demonstrar Compose secret em /run/secrets" bash -c \
  "export DEMO_SECRET='segredo-falso-compose'; docker compose -f '${ROOT_DIR}/formando/exemplos/secrets/compose.secret-demo.yaml' run --rm demo; unset DEMO_SECRET"

if [[ -f "$ENV_FILE" ]]; then
  cp "$ENV_FILE" "${RUN_DIR}/env.prod.antes-do-lab.txt"
fi
run_step "20" "env-prod" "Preparar .env.prod no estado inicial 1.0.0" bash -c \
  "cp '${ENV_EXAMPLE}' '${ENV_FILE}'; grep -E '^(IMAGE_REPO|APP_VERSION|APP_PORT|APP_ENV)=' '${ENV_FILE}'"

COMPOSE=(docker compose --env-file "$ENV_FILE" -f "$BASE_FILE" -f "$PROD_FILE")
run_step "21" "compose-config" "Validar configuração Compose" "${COMPOSE[@]}" config

if ((SKIP_TRIVY == 0)); then
  run_step "22" "trivy-scan" "Scan HIGH/CRITICAL da imagem 1.1.0" \
    trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed symfony-demo:1.1.0
else
  run_note "22" "trivy-scan" "Scan Trivy" "Ignorado por opção --sem-trivy."
fi

run_step "23" "registry-pull" "Consumir imagem pública 1.0.0 do GHCR" \
  docker pull ghcr.io/skullclamp/symfony-demo:1.0.0

if ((PUBLISH_GHCR)); then
  : "${IMAGE_REPO:?Defina IMAGE_REPO antes de usar --publicar-ghcr}"
  run_step "24a" "push-100" "Publicar 1.0.0" "${ROOT_DIR}/formando/scripts/push.sh" 1.0.0
  run_step "24b" "push-110" "Publicar 1.1.0" "${ROOT_DIR}/formando/scripts/push.sh" 1.1.0
  run_step "24c" "push-120" "Publicar 1.2.0-rc1" "${ROOT_DIR}/formando/scripts/push.sh" 1.2.0-rc1
else
  run_note "24" "registry-push" "Publicação no GHCR" \
    "Ignorada por segurança. Para executar: docker login ghcr.io, export IMAGE_REPO=... e usar --publicar-ghcr."
fi

run_step "25" "manual-pull" "Primeiro deployment — pull db/app" "${COMPOSE[@]}" pull db app
run_step "26" "manual-db" "Primeiro deployment — iniciar PostgreSQL" "${COMPOSE[@]}" up -d db

run_step "27" "db-health" "Aguardar PostgreSQL healthy" bash -c \
  "CID=\$('${ROOT_DIR}/formando/scripts/compose-prod.sh' ps -q db); for i in \$(seq 1 20); do s=\$(docker inspect \"\$CID\" --format '{{.State.Health.Status}}'); echo health=\$s; [[ \"\$s\" == healthy ]] && exit 0; sleep 3; done; exit 1"

run_step "28" "schema" "Inicializar schema apenas se a base estiver vazia" bash -c "
  set -e
  SCHEMA=\$(docker compose --env-file '${ENV_FILE}' -f '${BASE_FILE}' -f '${PROD_FILE}' exec -T db \
    psql -U symfony -d symfony -tAc \"SELECT 1 FROM pg_tables WHERE schemaname='public' AND tablename='symfony_demo_post';\")
  if [[ \"\$SCHEMA\" == 1 ]]; then
    echo 'Schema já existe; nenhuma alteração.'
  else
    echo 'Base vazia; a criar schema apenas para o laboratório.'
    docker compose --env-file '${ENV_FILE}' -f '${BASE_FILE}' -f '${PROD_FILE}' run --rm app \
      php bin/console doctrine:schema:create --no-interaction
  fi
"

run_step "29" "manual-app" "Primeiro deployment — iniciar app 1.0.0" "${COMPOSE[@]}" up -d app
run_step "30" "validar-100" "Validar 1.0.0: health, ready, info e HEALTHCHECK" \
  "${ROOT_DIR}/formando/scripts/validate.sh"

run_step "31" "assets-ghcr" "Validar assets no container recebido do GHCR" bash -c \
  "CID=\$('${ROOT_DIR}/formando/scripts/compose-prod.sh' ps -q app); docker exec \"\$CID\" sh -lc 'test -f /var/www/html/public/assets/manifest.json && echo OK: assets presentes no runtime'; docker inspect \"\$CID\" --format 'Image={{.Config.Image}} Status={{.State.Health.Status}}'"

run_note "32" "browser-compose" "Teste da stack no browser do PC" \
  "Abrir no PC: http://${VM_IP:-IP_DA_VM}:8080/ , /info , /health e /ready. A confirmação visual é externa ao script."

MARKER="antes-update-${TIMESTAMP}"
run_step "33" "persistencia" "Criar e consultar marcador persistente" bash -c "
  set -e
  '${ROOT_DIR}/formando/scripts/compose-prod.sh' exec -T db psql -U symfony -d symfony \
    -c \"CREATE TABLE IF NOT EXISTS lab_marker(id serial primary key, note text);\"
  '${ROOT_DIR}/formando/scripts/compose-prod.sh' exec -T db psql -U symfony -d symfony \
    -c \"INSERT INTO lab_marker(note) VALUES ('${MARKER}');\"
  '${ROOT_DIR}/formando/scripts/compose-prod.sh' exec -T db psql -U symfony -d symfony \
    -c \"SELECT * FROM lab_marker WHERE note='${MARKER}';\"
"

run_step "34" "backup" "Criar backup lógico PostgreSQL" bash -c \
  "'${ROOT_DIR}/formando/scripts/compose-prod.sh' exec -T db pg_dump -U symfony -d symfony > '${RUN_DIR}/backup.sql'; test -s '${RUN_DIR}/backup.sql'; ls -lh '${RUN_DIR}/backup.sql'"

run_step "35" "redeploy-100" "Automatizar deployment de 1.0.0" \
  "${ROOT_DIR}/formando/scripts/deploy-prod.sh" 1.0.0
run_step "36" "update-110" "Update para 1.1.0" \
  "${ROOT_DIR}/formando/scripts/deploy-prod.sh" 1.1.0

run_step "37" "validar-update" "Validar 1.1.0 e dados preservados" bash -c "
  set -e
  curl -fsS http://localhost:8080/info; echo
  '${ROOT_DIR}/formando/scripts/compose-prod.sh' exec -T db psql -U symfony -d symfony \
    -c \"SELECT * FROM lab_marker WHERE note='${MARKER}';\"
"

run_expected_failure "38" "falha-120" "Deploy 1.2.0-rc1 — falha controlada" \
  "${ROOT_DIR}/formando/scripts/deploy-prod.sh" 1.2.0-rc1

run_step "39" "diagnostico" "Diagnosticar /health=200, /healthz=404 e unhealthy" bash -c "
  set -e
  '${ROOT_DIR}/formando/scripts/compose-prod.sh' ps
  CID=\$('${ROOT_DIR}/formando/scripts/compose-prod.sh' ps -q app)
  docker inspect \"\$CID\" --format '{{json .State.Health}}'
  HEALTH=\$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/health)
  HEALTHZ=\$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/healthz)
  STATUS=\$(docker inspect \"\$CID\" --format '{{.State.Health.Status}}')
  echo \"/health=\$HEALTH\"
  echo \"/healthz=\$HEALTHZ\"
  echo \"Docker health=\$STATUS\"
  [[ \"\$HEALTH\" == 200 && \"\$HEALTHZ\" == 404 && \"\$STATUS\" == unhealthy ]]
"

run_step "40" "rollback" "Rollback para 1.1.0" \
  "${ROOT_DIR}/formando/scripts/rollback.sh" 1.1.0

run_step "41" "validar-rollback" "Validar rollback e persistência" bash -c "
  set -e
  '${ROOT_DIR}/formando/scripts/validate.sh'
  curl -fsS http://localhost:8080/info; echo
  '${ROOT_DIR}/formando/scripts/compose-prod.sh' exec -T db psql -U symfony -d symfony \
    -c \"SELECT * FROM lab_marker WHERE note='${MARKER}';\"
"

run_step "42" "estado-final" "Registar estado final da stack" bash -c "
  '${ROOT_DIR}/formando/scripts/compose-prod.sh' ps
  echo
  docker image ls symfony-demo
  echo
  grep -E '^(IMAGE_REPO|APP_VERSION|APP_PORT|APP_ENV)=' '${ENV_FILE}'
"

printf '\nFim: %s\nResultado: laboratório concluído.\n' "$(date -Is)" | tee -a "$SUMMARY" "$ALL_LOG"
echo
echo "Laboratório concluído."
echo "Outputs por ponto: $RUN_DIR"
echo "Resumo: $SUMMARY"
echo "Transcrição completa: $ALL_LOG"
echo "Backup PostgreSQL: ${RUN_DIR}/backup.sql"
