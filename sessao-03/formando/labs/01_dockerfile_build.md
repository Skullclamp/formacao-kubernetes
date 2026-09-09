# Lab 01 — Dockerfile e Build

**Duração prevista:** 30 minutos

## Objetivo

Construir a primeira imagem da Symfony Demo e relacionar cada instrução do Dockerfile com o conteúdo da imagem.

## 1. Preparar o código

```bash
./comum/prepare-source.sh
```

## 2. Analisar o Dockerfile inicial

```bash
sed -n '1,220p' formando/docker/Dockerfile.inicial
```

Identifique `FROM`, `RUN`, `COPY`, `WORKDIR`, `EXPOSE`, `HEALTHCHECK` e `CMD`.

## 3. Construir

```bash
docker build \
  -f formando/docker/Dockerfile.inicial \
  -t symfony-demo:naive \
  .
```

## 4. Executar

```bash
docker run --rm -d --name s3-naive -p 18080:80 symfony-demo:naive
```

Aguardar o healthcheck:

```bash
docker inspect s3-naive \
  --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}'
```

Validar:

```bash
curl -fsS http://localhost:18080/health
curl -fsS http://localhost:18080/info
curl -fsS http://localhost:18080/en >/dev/null
```

## 5. Observar a imagem

```bash
docker image ls symfony-demo:naive
docker history symfony-demo:naive
```

## 6. Limpeza

```bash
docker stop s3-naive
```

### Questão

Que elementos utilizados para construir a aplicação não precisam necessariamente de permanecer na imagem final de runtime?
