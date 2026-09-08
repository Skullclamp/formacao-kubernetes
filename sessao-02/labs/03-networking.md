# Lab 3 — Networking Docker

**Duração prevista:** 30 minutos  
**Objetivo:** criar uma rede Docker e validar comunicação por nome entre containers.

## 1. Inventário

```bash
docker network ls
```

Identifique `bridge`, `host` e `none`.

## 2. Criar uma rede

```bash
docker network create app-network
docker network inspect app-network
```

## 3. Serviço web

```bash
docker run -d \
  --name web-net \
  --network app-network \
  nginx:alpine
```

## 4. DNS por nome

```bash
docker run --rm \
  --network app-network \
  busybox:stable \
  wget -qO- http://web-net
```

O cliente utilizou o IP diretamente? Que nome utilizou?

## 5. Isolamento entre redes

```bash
docker network create outra-network

docker run --rm \
  --network outra-network \
  busybox:stable \
  wget -qO- http://web-net
```

Explique por que razão o pedido falha.

Ligue `web-net` à segunda rede:

```bash
docker network connect outra-network web-net
```

Repita o pedido e inspecione a rede.

## Limpeza

```bash
docker rm -f web-net
docker network rm app-network outra-network
```

## Ponte para Kubernetes

```text
Docker: nome do container/serviço → resolução interna
Kubernetes: nome do Service → DNS interno do cluster
```

São mecanismos diferentes, mas evitam depender diretamente de IPs efémeros.
