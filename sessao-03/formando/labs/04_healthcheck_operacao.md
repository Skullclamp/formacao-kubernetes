# Lab 04 — Healthcheck e Operação

**Duração prevista:** 20 minutos

## Objetivo

Distinguir saúde básica, readiness e controlos operacionais do container, executando primeiro a configuração Compose manualmente.

## Ponto de partida

Executar a partir de:

```text
formacao-kubernetes/sessao-03
```

Confirme:

```bash
test -f formando/compose/compose.yaml && echo 'OK: pronto'
```

## 1. Preparar configuração

```bash
cp formando/compose/.env.prod.example formando/compose/.env.prod
```

## 2. Ver a configuração Compose efetiva

Antes de utilizar qualquer wrapper, execute manualmente:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  config
```

Identifique:

- imagem da aplicação;
- `APP_VERSION`;
- limits de CPU e memória;
- restart policy;
- logging;
- volume PostgreSQL.

## 3. Arrancar manualmente a stack

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  up -d
```

Consultar o estado:

```bash
docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  ps
```

## 4. Comparar endpoints

```bash
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i http://localhost:8080/info
```

`/health` testa a saúde básica da aplicação. `/ready` acrescenta a disponibilidade da base de dados.

## 5. Observar Docker HEALTHCHECK

Obter o container da aplicação:

```bash
CID=$(docker compose \
  --env-file formando/compose/.env.prod \
  -f formando/compose/compose.yaml \
  -f formando/compose/compose.prod.yaml \
  ps -q app)
```

Consultar:

```bash
docker inspect "$CID" \
  --format '{{json .State.Health}}'
```

Relacione o estado `healthy` ou `unhealthy` com o comando `HEALTHCHECK` do Dockerfile.

## 6. Controlos de runtime

```bash
docker inspect "$CID" \
  --format 'Memory={{.HostConfig.Memory}} NanoCpus={{.HostConfig.NanoCpus}} Restart={{.HostConfig.RestartPolicy.Name}}'

docker stats --no-stream "$CID"
```

## 7. Da execução manual ao wrapper

Já utilizou repetidamente:

```text
--env-file ...
-f compose.yaml
-f compose.prod.yaml
```

Abra agora:

```bash
sed -n '1,220p' formando/scripts/compose-prod.sh
```

Depois compare:

```bash
./formando/scripts/compose-prod.sh config
./formando/scripts/compose-prod.sh ps
```

Explique que argumentos o wrapper evita repetir.

### Questões

1. É possível o processo HTTP responder e, mesmo assim, o Docker considerar o container `unhealthy`? Justifique.
2. Porque `healthy` não deve ser confundido com readiness da dependência de dados?
3. O que acrescenta `compose.prod.yaml` ao ficheiro base?
