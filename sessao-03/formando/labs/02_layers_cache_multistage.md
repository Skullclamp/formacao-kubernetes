# Lab 02 — Layers, Cache e Multi-stage

**Duração prevista:** 30 minutos

## Objetivo

Compreender a invalidation da cache e construir uma imagem multi-stage com separação entre build e runtime.

## 1. Construir a versão 1.0.0

```bash
time ./formando/scripts/build.sh 1.0.0
```

## 2. Observar layers

```bash
docker history symfony-demo:1.0.0
```

Analise onde são instaladas dependências e onde entra o código da aplicação.

## 3. Construir nova versão

Sem alterar dependências:

```bash
time ./formando/scripts/build.sh 1.1.0
```

Observe as linhas `CACHED` do build.

## 4. Comparar

```bash
docker image ls symfony-demo
```

### Ideia-chave

Os ficheiros `composer.json` e `composer.lock` entram antes do restante código para permitir reutilizar a layer de dependências quando apenas o código muda.

A metadata de versão é colocada depois das layers pesadas para não invalidar desnecessariamente o build.

## 5. Validar imagem final

```bash
docker run --rm -d --name s3-ms -p 18081:80 symfony-demo:1.1.0
sleep 5
curl -fsS http://localhost:18081/info
docker stop s3-ms
```
