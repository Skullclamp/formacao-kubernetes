# Cheat Sheet — Sessão 3

## Preparar source

```bash
./comum/prepare-source.sh
```

## Build

```bash
./formando/scripts/build.sh 1.0.0
./formando/scripts/build.sh 1.1.0

docker image ls symfony-demo
docker history symfony-demo:1.1.0
```

## Health

```bash
docker inspect symfony-demo:1.1.0 \
  --format '{{json .Config.Healthcheck}}'
```

## Trivy

Scan informativo:

```bash
trivy image \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  symfony-demo:1.1.0
```

Exemplo de quality gate apenas para CRITICAL:

```bash
trivy image \
  --scanners vuln \
  --severity CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  symfony-demo:1.1.0
```

## Tags e digest

```bash
docker image inspect symfony-demo:1.1.0 \
  --format '{{.Id}}'

docker image inspect "$IMAGE_REPO:1.1.0" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
```

## GHCR

### Pull público

```bash
docker pull ghcr.io/skullclamp/symfony-demo:1.0.0
docker pull ghcr.io/skullclamp/symfony-demo:1.1.0
docker pull ghcr.io/skullclamp/symfony-demo:1.2.0-rc1
```

### Push para namespace pessoal

```bash
export CR_PAT='TOKEN'
echo "$CR_PAT" | docker login ghcr.io \
  -u UTILIZADOR_GITHUB --password-stdin

export IMAGE_REPO=ghcr.io/UTILIZADOR_GITHUB/symfony-demo
./formando/scripts/push.sh 1.0.0
```

Nunca partilhar o token.

## Compose produção

```bash
cp formando/compose/.env.prod.example formando/compose/.env.prod
./formando/scripts/compose-prod.sh config
./formando/scripts/compose-prod.sh up -d
./formando/scripts/compose-prod.sh ps
./formando/scripts/compose-prod.sh logs -f app
```

## Deployment / rollback

```bash
./formando/scripts/deploy-prod.sh 1.0.0
./formando/scripts/deploy-prod.sh 1.1.0
./formando/scripts/deploy-prod.sh 1.2.0-rc1
./formando/scripts/rollback.sh 1.1.0
```

## Backup lógico

```bash
./formando/scripts/backup-postgres.sh
```

## Endpoints

```bash
curl -fsS http://localhost:8080/health
curl -fsS http://localhost:8080/ready
curl -fsS http://localhost:8080/info
```
