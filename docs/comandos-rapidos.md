# Comandos rápidos — Docker

Folha de consulta para os laboratórios. Utilize-a como referência, não como substituto da compreensão dos comandos.

> Para uma referência mais completa, incluindo conteúdos das Sessões 2 e 3, consulte também o [`Docker Cheat Sheet`](docker-cheat-sheet.md).

## Ambiente

```bash
docker version
docker info
docker compose version
```

## Imagens

```bash
docker images
docker pull nginx:alpine
docker rmi <imagem>
```

## Containers

```bash
docker run -d --name web -p 8080:80 nginx:alpine
docker ps
docker ps -a
docker stop web
docker start web
docker restart web
docker rm web
docker rm -f web
```

## Diagnóstico

```bash
docker logs <container>
docker logs -f <container>
docker exec -it <container> /bin/sh
docker inspect <container>
docker port <container>
docker stats --no-stream <container>
```

## Networking

```bash
docker network ls
docker network create app-network
docker network inspect app-network
docker network connect <rede> <container>
docker network rm <rede>
```

## Volumes

```bash
docker volume ls
docker volume create dados-lab
docker volume inspect dados-lab
docker volume rm dados-lab
```

## Docker Compose

```bash
docker compose config
docker compose up -d
docker compose ps
docker compose logs
docker compose logs -f app
docker compose exec app /bin/sh
docker compose stop
docker compose start
docker compose restart
docker compose down
```

### Atenção

```bash
docker compose down -v
```

remove também os volumes declarados pelo projeto. Utilize apenas quando a remoção dos dados for intencional.
