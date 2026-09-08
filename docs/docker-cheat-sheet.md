# Docker Cheat Sheet

Guia rápido para os laborató¹¹¹s das Sessõ¹¹¹s 2 e 3 — Docker Engine em Ubuntu, aplicaçª¹ PHP/Symfony e Docker Compose.

> **Convençµµs:** substitua os valores entre `<...>` pelos valores do seu ambiente.  
> Exemplos: `<imagem>`, `<container>`, `<utilizador>`, `<registry-privado>`.

---

## 1. Ajuda e informaçª¹

```bash
# Ajuda geral
docker --help

# Ajuda de um comando
docker <comando> --help

# Verso e informao do motor Docker
docker version
docker info

# Espaço ocupado por imagens, containers, volumes e cache
docker system df
```

---

## 2. Imagens

```bash
# Procurar uma imagem no Docker Hub
docker search nginx

# Obter uma imagem
docker pull nginx:alpine

# Listar imagens locais
docker image ls
# Forma abreviada
docker images

# Consultar detalhes de uma imagem
docker image inspect nginx:alpine

# Consultar histrico/layers de uma imagem
docker image history nginx:alpine

# Criar uma tag local
docker tag <imagem-origem>:<tag> <imagem-destino>:<tag>

# Remover uma imagem
docker image rm <imagem>:<tag>
# Forma abreviada
docker rmi <imagem>:<tag>

# Remover imagens no utilizadas
docker image prune
```

### Tags recomendadas

```text
symfony-demo:1.0.0          # verso imutvel: recomendada para releases
symfony-demo:1.0            # verso de convenincia: opcional
symfony-demo:latest         # tag mutvel: evitar em produo
registry.local/symfony-demo:1.0.0
<utilizador>/symfony-demo:1.0.0
```

---

## 3. Containers

```bash
# Executar um container em primeiro plano
docker run --name web nginx:alpine

# Executar em segundo plano (detached)
docker run -d --name web nginx:alpine

# Publicar a porta 80 do container na porta 8080 do host
docker run -d --name web -p 8080:80 nginx:alpine

# Definir variveis de ambiente
docker run -d --name app -e APP_ENV=prod <imagem>:<tag>

# Carregar variveis de um ficheiro
docker run --env-file .env.prod <imagem>:<tag>

# Listar containers em execuo
docker container ls
# Forma abreviada
docker ps

# Listar todos os containers, incluindo os parados
docker container ls -a
docker ps -a

# Consultar logs
docker logs <container>

# Seguir logs em tempo real
docker logs -f <container>

# Consultar as ltimas 100 linhas
docker logs --tail 100 <container>

# Executar uma shell no container
docker exec -it <container> sh
# Caso exista Bash
docker exec -it <container> bash

# Executar um comando no container
docker exec <container> php -v
docker exec <container> php bin/console about

# Consultar detalhes do container
docker inspect <container>

# Obter o endereo IP do container
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container>

# Consultar estado de healthcheck
docker inspect -f '{{.State.Health.Status}}' <container>

# Monitorizar CPU, memria, rede e I/O
docker stats
docker stats <container>

# Parar, iniciar e reiniciar
docker stop <container>
docker start <container>
docker restart <container>

# Remover um container parado
docker rm <container>

# Forar paragem e remoo
docker rm -f <container>

# Remover containers parados
docker container prune
```

---

## 4. Portas e acesso aplicaao

```bash
# Mapear porta do host para porta do container
docker run -d -p 8080:80 --name symfony-app <imagem>:<tag>

# Ver mapeamentos de portas
docker port symfony-app

# Testar localmente a aplicaao
curl -i http://localhost:8080

# Verificar processos e portas no Ubuntu
ss -lntp
```

A sintaxe `-p 8080:80` significa: **porta 8080 do host** encaminhada para a **porta 80 do container**.

---

## 5. Redes Docker

```bash
# Listar redes
docker network ls

# Criar uma rede bridge definida pelo utilizador
docker network create app-network

# Consultar configurao e membros da rede
docker network inspect app-network

# Executar containers na mesma rede
docker run -d --name db --network app-network mysql:8.0
docker run -d --name app --network app-network <imagem>:<tag>

# Ligar um container j existente a uma rede
docker network connect app-network <container>

# Desligar um container de uma rede
docker network disconnect app-network <container>

# Remover uma rede vazia
docker network rm app-network

# Remover redes no utilizadas
docker network prune
```

Numa rede criada pelo utilizador, os containers podem comunicar usando o **nome do container ou do servio** como nome DNS. Por exemplo, a aplicaao pode usar `db` como host da base de dados.

---

## 6. Volumes e bind mounts

### Volumes nomeados

```bash
# Criar e listar volumes
docker volume create db_data
docker volume ls

# Consultar detalhes do volume
docker volume inspect db_data

# Montar um volume num container
docker run -d \
  --name db \
  -v db_data:/var/lib/mysql \
  mysql:8.0

# Remover um volume no utilizado
docker volume rm db_data

# Remover volumes no utilizados
docker volume prune
```

### Bind mounts

```bash
# Montar um diretrio do host no container
docker run --rm -it \
  --mount type=bind,source="$(pwd)",target=/var/www/html \
  php:8.2-cli sh

# Sintaxe curta equivalente
docker run --rm -it -v "$(pwd)":/var/www/html php:8.2-cli sh
```

| Tipo | Utilizao tpica | Caracterstica principal |
|---|---|---|
| Volume nomeado | Dados persistentes, por exemplo MySQL | Gerido pelo Docker; adequado a dados da aplicaao |
| Bind mount | Cdigo-fonte durante desenvolvimento | Mapeia diretamente um caminho do host |
| Filesystem do container | Ficheiros temporrios | Efemero; perde-se ao remover o container |

---

## 7. Dockerfile: instrues essenciais

```dockerfile
# Imagem base com tag explcita
FROM php:8.2-apache

# Argumento disponvel durante o build
ARG APP_ENV=prod

# Varivel disponvel no container em execuo
ENV APP_ENV=${APP_ENV}

# Diretrio de trabalho
WORKDIR /var/www/html

# Copiar manifestos de dependncias primeiro para aproveitar a cache
COPY composer.json composer.lock ./

# Instalar dependncias
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader

# Copiar cdigo aps dependncias
COPY . .

# Expor porta documentada pela imagem
EXPOSE 80

# Executar sem privilgios de root, quando compatvel com a aplicaao
USER www-data

# Verificao de sade do container
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS http://localhost/ || exit 1

# Comando predefinido
CMD ["apache2-foreground"]
```

### Build e execuo

```bash
# Construir imagem usando o diretrio atual como build context
docker build -t symfony-demo:1.0.0 .

# Passar argumento de build
docker build --build-arg APP_ENV=prod -t symfony-demo:1.0.0 .

# Construir um target especfico num Dockerfile multi-stage
docker build --target runtime -t symfony-demo:1.0.0 .

# Executar a imagem construda
docker run -d -p 8080:80 --name symfony-app symfony-demo:1.0.0
```

### ARG versus ENV

| Elemento | Disponvel em | Uso tpico |
|---|---|---|
| `ARG` | Durante o build | Escolher comportamento de construo, verso ou target |
| `ENV` | Build e execuo do container | Configurao no sensvel da aplicaao |

No coloque palavras-passe, tokens ou chaves privadas em `ARG`, `ENV`, Dockerfile ou layers da imagem.

### CMD versus ENTRYPOINT

| Instruo | Finalidade |
|---|---|
| `CMD` | Define o comando ou argumentos predefinidos, que podem ser substitudos no `docker run` |
| `ENTRYPOINT` | Define o executvel principal do container; normalmente recebe argumentos definidos por `CMD` ou no `docker run` |

---

## 8. `.dockerignore`

O ficheiro `.dockerignore` exclui ficheiros do build context, reduzindo o volume enviado ao Docker e evitando a cpia acidental de informao desnecessria ou sensvel.

```text
.git/
.env
.env.*
!.env.example
vendor/
node_modules/
var/cache/
var/log/
tests/
README.md
Dockerfile*
compose*.yaml
```

Valide a lista conforme a estratgia de build: se o `vendor/` for criado dentro da imagem, deve ficar excludo do contexto; se for necessrio copiar dependncias j preparadas, ajuste a regra.

---

## 9. Multi-stage build para Symfony

```dockerfile
# Dependncias PHP
FROM composer:2 AS vendor
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader

# Runtime da aplicaao
FROM php:8.2-apache AS runtime
WORKDIR /var/www/html

RUN a2enmod rewrite \
    && docker-php-ext-install pdo pdo_mysql

COPY --from=vendor /app/vendor ./vendor
COPY . .

RUN chown -R www-data:www-data var \
    && chmod -R ug+rwX var

USER www-data
EXPOSE 80
CMD ["apache2-foreground"]
```

Princpio: a fase `vendor` contm ferramentas de construo; a fase `runtime` contm apenas o necessrio para executar a aplicaao.

---

## 10. Docker Compose

### Ciclo de vida

```bash
# Validar e mostrar a configurao final
docker compose config

# Criar/iniciar servios em segundo plano
docker compose up -d

# Criar/reconstruir imagens e iniciar servios
docker compose up -d --build

# Consultar servios e estado
docker compose ps

# Consultar logs de todos os servios
docker compose logs

# Seguir logs de um servio
docker compose logs -f app

# Executar comando num servio j em execuo
docker compose exec app php bin/console about

# Executar migraes Symfony
docker compose exec app php bin/console doctrine:migrations:migrate --no-interaction

# Reiniciar um servio
docker compose restart app

# Parar e remover containers e redes criados pelo projeto
docker compose down

# Parar e remover tambm volumes do projeto: ateno, remove dados persistentes
docker compose down -v

# Usar ficheiro de produo
docker compose -f compose.prod.yaml up -d
```

### Exemplo: Symfony + MySQL

```yaml
services:
  app:
    image: registry.local/symfony-demo:1.0.0
    ports:
      - "8080:80"
    environment:
      APP_ENV: prod
      DATABASE_URL: "mysql://symfony:${DB_PASSWORD}@db:3306/symfony?serverVersion=8.0"
    env_file:
      - .env.prod
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - app_var:/var/www/html/var
    restart: unless-stopped

  db:
    image: mysql:8.0
    environment:
      MYSQL_DATABASE: symfony
      MYSQL_USER: symfony
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

volumes:
  app_var:
  db_data:
```

Para contexto pedaggico, as credenciais podem ser passadas com variveis de ambiente. Num cenrio real, devem ser fornecidas externamente e nunca includas na imagem ou num repositrio de cdigo.

---

## 11. Registries e publicao

```bash
# Autenticar no Docker Hub
docker login

# Etiquetar para Docker Hub
docker tag symfony-demo:1.0.0 <utilizador>/symfony-demo:1.0.0

# Publicar no Docker Hub
docker push <utilizador>/symfony-demo:1.0.0

# Obter do Docker Hub
docker pull <utilizador>/symfony-demo:1.0.0

# Autenticar num registry privado
docker login <registry-privado>

# Etiquetar e publicar no registry privado
docker tag symfony-demo:1.0.0 <registry-privado>/symfony-demo:1.0.0
docker push <registry-privado>/symfony-demo:1.0.0

# Obter do registry privado
docker pull <registry-privado>/symfony-demo:1.0.0

# Terminar sesso
docker logout
docker logout <registry-privado>
```

Promova a **mesma imagem identificada por uma tag imutvel** entre DEV, TEST e PROD; no reconstrua uma imagem diferente apenas porque muda o ambiente.

---

## 12. Atualizao e rollback com Compose

```bash
# 1. Alterar a tag da imagem no compose.prod.yaml
#    Exemplo: registry.local/symfony-demo:1.0.0 -> :1.1.0

# 2. Obter a imagem e recriar servios
docker compose -f compose.prod.yaml pull
docker compose -f compose.prod.yaml up -d --force-recreate

# 3. Validar aplicaao e logs
curl -f http://localhost:8080
docker compose -f compose.prod.yaml ps
docker compose -f compose.prod.yaml logs --tail 100 app

# 4. Rollback: repor a tag anterior no compose.prod.yaml e recriar
docker compose -f compose.prod.yaml up -d --force-recreate app
```

Em Docker Compose num host nico, o rollback manual. Em Kubernetes, os Deployments fornecem mecanismos prprios para atualizaes progressivas e reverso.

---

## 13. Diagnstico rpido

| Situao | Comandos teis |
|---|---|
| Container no inicia | `docker ps -a`, `docker logs <container>`, `docker inspect <container>` |
| Aplicao no responde | `docker port <container>`, `curl -i http://localhost:<porta>`, `docker exec -it <container> sh` |
| Servio Compose falha | `docker compose ps`, `docker compose logs <servio>`, `docker compose config` |
| App no comunica com base de dados | `docker network inspect <rede>`, `docker compose exec app sh`, confirmar host `db` e `DATABASE_URL` |
| Dados desapareceram | `docker volume ls`, `docker volume inspect <volume>`, confirmar montagem no servio da base de dados |
| Healthcheck falha | `docker inspect -f '{{.State.Health.Status}}' <container>`, `docker inspect <container>`, logs do servio |
| Falha no pull/push | `docker login`, confirmar nome/tag, permisses e conectividade com o registry |

---

## 14. Limpeza controlada

```bash
# Remover recursos parados/no utilizados
# Ateno: reveja o que ser removido antes de confirmar.
docker container prune
docker image prune
docker network prune
docker volume prune

# Limpeza mais abrangente: pode remover imagens e recursos necessrios
docker system prune

# Inclui imagens no utilizadas e volumes no utilizados: usar com cuidado
docker system prune -a --volumes
```

---

## 15. Checklist pr-produo

- [ ] A imagem usa uma base com verso explcita; no usa `latest`.
- [ ] Existe uma tag de release imutvel, por exemplo `1.0.0`.
- [ ] O `.dockerignore` exclui ficheiros desnecessrios e dados sensveis.
- [ ] As dependncias so instaladas antes da cpia do cdigo para aproveitar a cache.
- [ ] O Dockerfile usa multi-stage build quando aplicvel.
- [ ] A imagem contm apenas os componentes necessrios ao runtime.
- [ ] A aplicaao no executada como `root`, quando tecnicamente vivel.
- [ ] No existem segredos no Dockerfile, nas variveis `ENV`, na imagem nem no repositrio.
- [ ] A configurao fornecida externamente ao container.
- [ ] A aplicaao produz logs teis para `stdout`/`stderr`.
- [ ] Existe um healthcheck adequado ao servio.
- [ ] Dados persistentes usam volumes ou armazenamento externo.
- [ ] A imagem foi validada e analisada quanto a vulnerabilidades.
- [ ] Existe um procedimento testado de atualizao e rollback.
- [ ] Existem procedimentos para cpia de segurana e recuperao de dados persistentes.
