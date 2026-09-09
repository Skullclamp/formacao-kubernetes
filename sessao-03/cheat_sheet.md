# Cheat Sheet — Sessão 3

> Todos os comandos assumem que está em `formacao-kubernetes/sessao-03`.

## Obter os recursos numa VM nova

```bash
git clone https://github.com/Skullclamp/formacao-kubernetes.git
cd formacao-kubernetes/sessao-03
./comum/prepare-source.sh
```

Se já tiver o repositório:

```bash
cd formacao-kubernetes
git pull
cd sessao-03
./comum/prepare-source.sh
```

## Build manual

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.0.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.0.0 \
  .
```

Nova versão para observar cache:

```bash
docker build \
  -f formando/docker/Dockerfile \
  --build-arg APP_VERSION=1.1.0 \
  --build-arg SOURCE_REF=v3.1.0 \
  -t symfony-demo:1.1.0 \
  .
```

Observar:

```bash
docker image ls symfony-demo
docker history symfony-demo:1.1.0
```

Só depois de compreender o comando manual:

```bash
./formando/scripts/build.sh 1.1.0
```

## Compose manual

```bash
cp formando/compose/.env.prod.example formando/compose/.env.prod

docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  config
```

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d
```

Depois pode usar o wrapper:

```bash
./formando/scripts/compose-prod.sh ps
```

## Health

```bash
curl -fsS http://localhost:8080/health
curl -fsS http://localhost:8080/ready
curl -fsS http://localhost:8080/info
```

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
docker inspect "$CID" --format '{{json .State.Health}}'
```

## Trivy

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.1.0
```

Quality gate didático:

```bash
trivy image \
  --scanners vuln \
  --severity CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  symfony-demo:1.1.0
```

## Tags

```bash
docker tag symfony-demo:1.1.0 symfony-demo:stable

docker image inspect symfony-demo:1.1.0 --format '{{.Id}}'
docker image inspect symfony-demo:stable --format '{{.Id}}'
```

## GHCR — push manual primeiro

```bash
export IMAGE_REPO=ghcr.io/UTILIZADOR_GITHUB/symfony-demo

docker tag \
  symfony-demo:1.0.0 \
  "$IMAGE_REPO:1.0.0"

docker push "$IMAGE_REPO:1.0.0"
```

Digest:

```bash
docker image inspect "$IMAGE_REPO:1.0.0" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
```

Depois da aprendizagem manual:

```bash
./formando/scripts/push.sh 1.0.0
```

## Pull público

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
docker pull ghcr.io/skullclamp/symfony-demo:1.1.0
docker pull ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
```

## Deployment integrado — Lab 07

Nesta fase a automação é intencional:

```bash
./formando/scripts/deploy-prod.sh 1.0.0
./formando/scripts/deploy-prod.sh 1.1.0
```

Falha controlada:

```bash
./formando/scripts/deploy-prod.sh 1.2.0-rc1
```

Diagnóstico:

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
docker inspect "$CID" --format '{{json .State.Health}}'
curl -i http://localhost:8080/health
curl -i http://localhost:8080/healthz
```

Rollback:

```bash
./formando/scripts/rollback.sh 1.1.0
```

## Backup lógico

```bash
./formando/scripts/backup-postgres.sh
```

## Regra da sessão

```text
FAZER manualmente
      ↓
OBSERVAR
      ↓
EXPLICAR
      ↓
AUTOMATIZAR
```
