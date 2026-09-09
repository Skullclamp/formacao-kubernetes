# Lab 04 — Healthcheck e Operação

**Duração prevista:** 20 minutos

## Objetivo

Distinguir saúde básica, readiness e controlos operacionais do container.

## 1. Preparar Compose

```bash
cp formando/compose/.env.prod.example formando/compose/.env.prod
./formando/scripts/compose-prod.sh config
```

## 2. Arrancar versão válida

```bash
./formando/scripts/deploy-prod.sh 1.0.0
```

## 3. Comparar endpoints

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i http://localhost:8080/info
```

`/health` testa a aplicação. `/ready` testa também a disponibilidade da base de dados.

## 4. Observar Docker health

```bash
CID=$(./formando/scripts/compose-prod.sh ps -q app)
docker inspect "$CID" \
  --format '{{json .State.Health}}'
```

## 5. Controlos de runtime

```bash
docker inspect "$CID" \
  --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}}'

docker stats --no-stream "$CID"
```

### Questão

É possível o processo HTTP responder e, mesmo assim, o Docker considerar o container `unhealthy`? Justifique.
