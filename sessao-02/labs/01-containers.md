# Lab 1 — Imagens, Containers e Ciclo de Vida

**Duração prevista:** 30 minutos  
**Objetivo:** operar imagens e containers e compreender a publicação de portas.

## 1. Validar o ambiente

```bash
docker version
docker info
docker images
```

Responda:

1. Qual é a versão do Docker Client?
2. Qual é a versão do Docker Server?
3. Quantas imagens existem localmente?
4. Qual é a diferença entre uma imagem e um container?

## 2. Obter uma imagem

```bash
docker pull nginx:alpine
docker images
```

Identifique repository, tag, image ID e tamanho.

## 3. Criar um container

```bash
docker run -d \
  --name web-demo \
  -p 8080:80 \
  nginx:alpine
```

Valide:

```bash
docker ps
curl http://localhost:8080
```

Explique `-p 8080:80`:

```text
porta do __________________ : porta do __________________
```

## 4. Ciclo de vida

```bash
docker stop web-demo
docker ps
docker ps -a

docker start web-demo
curl http://localhost:8080

docker restart web-demo

docker stop web-demo
docker rm web-demo
docker ps -a
```

### Questões

1. A imagem `nginx:alpine` desapareceu quando removeu o container?
2. É possível criar vários containers a partir da mesma imagem?
3. Qual é a diferença entre `docker stop` e `docker rm`?
4. O que espera que aconteça se dois containers tentarem publicar a mesma porta do host?

## Desafio

Crie dois containers Nginx em simultâneo:

```text
web-a → host:8081 → container:80
web-b → host:8082 → container:80
```

Valide ambos com `curl` e remova-os no final.
