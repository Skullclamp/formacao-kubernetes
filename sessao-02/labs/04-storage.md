# Lab 4 — Storage Docker

**Duração prevista:** 30 minutos  
**Objetivo:** distinguir filesystem do container, bind mounts e named volumes e provar persistência.

## 1. Filesystem do container

```bash
docker run -it --name fs-demo busybox:stable sh
```

Dentro:

```sh
echo "dados dentro do container" > /dados.txt
cat /dados.txt
exit
```

Remova e tente ler o ficheiro num novo container:

```bash
docker rm fs-demo
docker run --rm busybox:stable cat /dados.txt
```

## 2. Bind mount

```bash
mkdir -p ~/lab-bind
echo "Conteúdo vindo do HOST" > ~/lab-bind/index.html

docker run -d \
  --name bind-web \
  -p 8080:80 \
  -v ~/lab-bind:/usr/share/nginx/html:ro \
  nginx:alpine

curl http://localhost:8080
```

Altere o ficheiro no host e volte a validar.

```bash
echo "Alteração efetuada no HOST" > ~/lab-bind/index.html
curl http://localhost:8080
docker rm -f bind-web
```

## 3. Named volume

```bash
docker volume create dados-lab
docker volume inspect dados-lab
```

Grave dados:

```bash
docker run --rm \
  -v dados-lab:/dados \
  busybox:stable \
  sh -c 'echo "persistente" > /dados/teste.txt'
```

Leia-os noutro container:

```bash
docker run --rm \
  -v dados-lab:/dados \
  busybox:stable \
  cat /dados/teste.txt
```

O container que escreveu já não existe, mas o volume continua.

## Comparação

| Tipo | Gerido principalmente por | Caso típico |
|---|---|---|
| Filesystem do container |  |  |
| Bind mount |  |  |
| Named volume |  |  |

## Limpeza

Depois de concluir:

```bash
docker volume rm dados-lab
rm -rf ~/lab-bind
```

No laboratório Compose, o PostgreSQL utilizará um named volume para preservar os dados após a recriação do container.
