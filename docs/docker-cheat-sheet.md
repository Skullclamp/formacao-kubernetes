# Docker Cheat Sheet

Guia rápido para os laboratórios das **Sessões 2 e 3** da formação *Orquestração de Containers com Kubernetes*.

- **Sessão 2 — OPERAR Docker:** imagens existentes, containers, diagnóstico, networking, storage e Docker Compose.
- **Sessão 3 — CONSTRUIR e PREPARAR para produção:** Dockerfile, build, cache, multi-stage, hardening, healthcheck, scan, tags, registry, deployment, atualização e rollback.

## Stack de referência da formação

- Symfony Demo Application `v3.1.0`;
- Symfony 8.1;
- PHP 8.4 + Apache;
- PostgreSQL 16;
- Docker Engine e Docker Compose em Ubuntu.

> **Convenção:** substitua os valores entre `<...>` pelos valores do seu ambiente, por exemplo `<imagem>`, `<container>`, `<registry>` ou `<utilizador>`.

> **Importante:** este documento é uma folha de consulta. Nos laboratórios, siga sempre o guião da sessão e recolha evidências antes de alterar configuração.

---

# Parte I — Sessão 2: operar Docker

## 1. Ajuda e informação

```bash
# Ajuda geral
docker --help

# Ajuda de um comando
docker <comando> --help

# Versão do cliente/servidor e informação do Engine
docker version
docker info

# Versão do Docker Compose
docker compose version

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

# Consultar detalhes
docker image inspect nginx:alpine

# Consultar histórico/layers
docker image history nginx:alpine

# Remover uma imagem
docker image rm nginx:alpine
# Forma abreviada
docker rmi nginx:alpine

# Remover imagens não utilizadas
docker image prune
```

### Imagem da aplicação na Sessão 2

Nesta sessão a imagem Symfony é **fornecida já construída**:

```bash
docker pull <registry>/formacao/symfony-demo:1.0
```

Não é necessário utilizar `docker build` na Sessão 2.

---

## 3. Containers e ciclo de vida

```bash
# Executar em primeiro plano
docker run --name web nginx:alpine

# Executar em segundo plano
docker run -d --name web nginx:alpine

# Publicar a porta 80 do container na porta 8080 do host
docker run -d --name web -p 8080:80 nginx:alpine

# Definir uma variável de ambiente
docker run -d --name app -e APP_ENV=dev <imagem>:<tag>

# Carregar variáveis de um ficheiro
docker run --env-file .env <imagem>:<tag>

# Containers em execução
docker container ls
docker ps

# Todos os containers, incluindo parados
docker container ls -a
docker ps -a

# Parar, iniciar e reiniciar
docker stop <container>
docker start <container>
docker restart <container>

# Remover um container parado
docker rm <container>

# Forçar remoção
docker rm -f <container>

# Remover containers parados
docker container prune
```

### Regra mental

```text
Imagem
  ↓ docker run
Container
  ↓ docker stop
Container parado
  ↓ docker rm
Container removido
```

Remover um container **não remove automaticamente a imagem** usada para o criar.

---

## 4. Portas e acesso à aplicação

```bash
# Host 8080 → container 80
docker run -d -p 8080:80 --name web nginx:alpine

# Ver mapeamentos de portas
docker port web

# Testar localmente
curl -i http://localhost:8080

# Ver portas em escuta no Ubuntu
ss -lntp
```

A sintaxe:

```text
-p 8080:80
```

significa:

```text
porta do HOST : porta do CONTAINER
     8080      :        80
```

---

## 5. Diagnóstico e inspeção

```bash
# Logs
docker logs <container>
docker logs -f <container>
docker logs --tail 100 <container>

# Executar uma shell no container
docker exec -it <container> /bin/sh

# Se a imagem tiver Bash
docker exec -it <container> /bin/bash

# Executar um comando
docker exec <container> php -v

# Inspecionar configuração completa
docker inspect <container>

# Estado
docker inspect --format '{{.State.Status}}' <container>

# Endereço IP por rede
docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container>

# Portas publicadas
docker port <container>

# CPU, memória, rede e I/O
docker stats
docker stats --no-stream <container>
```

### Método de troubleshooting

```text
Sintoma
   ↓
O container existe?
   ↓
Está em execução?
   ↓
Logs
   ↓
Configuração / inspect
   ↓
Rede
   ↓
Mounts / variáveis / portas
   ↓
Hipótese
   ↓
Correção
   ↓
Validação
```

> `docker exec` é muito útil para diagnóstico, mas não deve ser usado como mecanismo normal para alterar manualmente uma aplicação em produção.

---

## 6. Networking Docker

```bash
# Listar redes
docker network ls

# Criar uma user-defined bridge
docker network create app-network

# Inspecionar
docker network inspect app-network

# PostgreSQL 16 na rede do laboratório
docker run -d \
  --name db \
  --network app-network \
  -e POSTGRES_DB=symfony \
  -e POSTGRES_USER=symfony \
  -e POSTGRES_PASSWORD=lab-symfony \
  postgres:16

# Ligar um container existente a uma rede
docker network connect app-network <container>

# Desligar
docker network disconnect app-network <container>

# Remover rede vazia
docker network rm app-network

# Remover redes não utilizadas
docker network prune
```

Numa **bridge criada pelo utilizador**, os containers na mesma rede podem comunicar por nome. Na formação, a aplicação utiliza:

```text
db
```

como hostname da base de dados, em vez de depender de um IP fixo.

### Ponte conceptual para Kubernetes

```text
Docker: nome do container/serviço numa user-defined bridge
Kubernetes: nome do Service através do DNS interno do cluster
```

Os mecanismos são diferentes, mas o objetivo operacional é semelhante: comunicar por nome em vez de depender de IPs efémeros.

---

## 7. Volumes e bind mounts

### Volumes nomeados

```bash
# Criar e listar volumes
docker volume create db-data
docker volume ls

# Inspecionar
docker volume inspect db-data

# PostgreSQL 16 com persistência
docker run -d \
  --name db \
  -e POSTGRES_DB=symfony \
  -e POSTGRES_USER=symfony \
  -e POSTGRES_PASSWORD=lab-symfony \
  -v db-data:/var/lib/postgresql/data \
  postgres:16

# Remover um volume que não esteja em uso
docker volume rm db-data

# Remover volumes não utilizados
docker volume prune
```

### Bind mounts

```bash
mkdir -p ~/lab-bind

docker run --rm \
  -v ~/lab-bind:/dados \
  busybox:stable \
  sh -c 'echo "dados no host" > /dados/teste.txt'
```

| Tipo | Utilização típica | Característica principal |
|---|---|---|
| Filesystem do container | Ficheiros temporários | Efémero; perde-se quando o container é removido |
| Bind mount | Código/configuração em desenvolvimento | Mapeia diretamente um caminho do host |
| Named volume | Dados persistentes, por exemplo PostgreSQL | Gerido pelo Docker e reutilizável por novos containers |

### Princípio essencial

```text
ciclo de vida do container ≠ ciclo de vida dos dados
```

Para provar persistência, remova e recrie o container. Um simples `restart` não demonstra independência entre container e dados.

> Persistência não é backup. Um volume pode sobreviver ao container e, mesmo assim, os dados podem ser apagados ou corrompidos.

---

## 8. Docker Compose — Sessão 2

### Comandos principais

```bash
# Validar e visualizar configuração final
docker compose config

# Iniciar serviços em background
docker compose up -d

# Estado
docker compose ps

# Logs
docker compose logs
docker compose logs -f app
docker compose logs -f db

# Executar comando num serviço já iniciado
docker compose exec app /bin/sh

# Parar sem remover
docker compose stop

# Voltar a iniciar
docker compose start

# Reiniciar
docker compose restart

# Remover containers e redes do projeto
docker compose down

# ATENÇÃO: remove também os volumes declarados
docker compose down -v
```

### Diferença importante

```text
docker compose stop
→ pára containers
→ não os remove


docker compose down
→ remove containers e redes do projeto
→ mantém named volumes por defeito


docker compose down -v
→ remove containers e redes
→ remove também volumes
→ pode eliminar dados persistentes
```

### Exemplo alinhado com o laboratório Symfony + PostgreSQL

```yaml
services:
  app:
    image: ${SYMFONY_IMAGE}
    ports:
      - "${APP_PORT:-8080}:80"
    environment:
      APP_ENV: ${APP_ENV:-dev}
      DATABASE_URL: ${DATABASE_URL}
    depends_on:
      db:
        condition: service_healthy
    networks:
      - app-network

  db:
    image: postgres:16
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"
        ]
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 5s
    networks:
      - app-network

networks:
  app-network:

volumes:
  db-data:
```

Exemplo de `DATABASE_URL` do laboratório:

```text
postgresql://symfony:lab-symfony@db:5432/symfony?serverVersion=16&charset=utf8
```

> As credenciais deste exemplo são apenas para o laboratório. Num ambiente real, segredos devem ser fornecidos por mecanismos adequados e não incluídos na imagem ou no repositório.

### `depends_on` e readiness

Sem condição/healthcheck, `depends_on` controla essencialmente a ordem de arranque e **não significa, por si só, que a aplicação dependente esteja pronta**.

No Compose do laboratório, PostgreSQL possui um healthcheck com `pg_isready`, permitindo que a aplicação espere pelo estado saudável da BD no arranque.

---

## 9. Endpoints da aplicação pedagógica

```bash
curl -i http://localhost:8080/info
curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
```

Interpretação:

```text
/info
→ versão, ambiente e identificação da instância

/health
→ a aplicação/processo responde

/ready
→ a aplicação está pronta para servir pedidos que dependem dos serviços necessários,
  incluindo a base de dados
```

Uma aplicação pode estar **viva** mas temporariamente **não pronta**.

---

# Parte II — Sessão 3: construir e preparar para produção

## 10. Dockerfile — instruções essenciais

```dockerfile
FROM php:8.4-apache

ARG <ARGUMENTO_DE_BUILD>
ENV <VARIAVEL_RUNTIME>=<valor>

WORKDIR /var/www/html

COPY <origem> <destino>
RUN <comando-de-build>

EXPOSE 80
CMD ["apache2-foreground"]
```

| Instrução | Finalidade |
|---|---|
| `FROM` | Define a imagem base |
| `ARG` | Valor disponível durante o build |
| `ENV` | Variável disponível na imagem/container |
| `WORKDIR` | Diretório de trabalho |
| `COPY` | Copia ficheiros para a imagem |
| `RUN` | Executa um passo durante o build |
| `EXPOSE` | Documenta uma porta da imagem; não a publica no host |
| `CMD` | Comando/argumentos predefinidos |
| `ENTRYPOINT` | Executável principal do container |

### ARG versus ENV

| Elemento | Disponível em | Uso típico |
|---|---|---|
| `ARG` | Durante o build | Versão, target ou comportamento de construção |
| `ENV` | Imagem e runtime | Configuração não sensível |

> Não coloque palavras-passe, tokens ou chaves privadas em `ARG`, `ENV`, Dockerfile ou layers da imagem.

---

## 11. Build context e `.dockerignore`

Exemplo:

```text
.git/
.env
.env.*
!.env.example
node_modules/
var/cache/
var/log/
```

O `.dockerignore` reduz o build context e evita enviar ficheiros desnecessários ou sensíveis para o builder.

A lista exata deve ser coerente com a estratégia de build. Não exclua um ficheiro que o Dockerfile necessita mais tarde.

### Build

```bash
# Build normal
docker build -t symfony-demo:1.0.0 .

# Sem reutilizar cache
docker build --no-cache -t symfony-demo:1.0.0 .

# Mostrar output mais detalhado
docker build --progress=plain -t symfony-demo:1.0.0 .
```

### Cache

Regra prática:

```text
camadas que mudam pouco
        ↓
mais cedo no Dockerfile

camadas que mudam frequentemente
        ↓
mais tarde no Dockerfile
```

Alterar uma camada invalida a cache dessa camada e das seguintes.

---

## 12. Multi-stage build

Estrutura conceptual:

```dockerfile
# Fase de build/dependências
FROM composer:2 AS vendor
WORKDIR /app
COPY . .
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader

# Fase de runtime
FROM php:8.4-apache AS runtime
WORKDIR /var/www/html

# Instalar/configurar apenas o que o runtime necessita
# - extensões PHP necessárias, incluindo PostgreSQL
# - configuração Apache com DocumentRoot em /var/www/html/public
# - permissões adequadas para var/

COPY --from=vendor /app /var/www/html

CMD ["apache2-foreground"]
```

> Este bloco mostra o **padrão** de multi-stage. Utilize o Dockerfile testado fornecido na Sessão 3 para o laboratório real. A Symfony Demo v3.1.0 exige PHP 8.4, e a imagem final tem de incluir as extensões PHP necessárias ao projeto e ao PostgreSQL.

Princípio:

```text
Build stage
→ ferramentas de construção

Runtime stage
→ apenas o necessário para executar
```

---

## 13. Hardening da imagem

Checklist de princípios:

```text
[ ] imagem base com versão explícita
[ ] apenas dependências necessárias
[ ] sem segredos na imagem
[ ] configuração externalizada
[ ] permissões mínimas necessárias
[ ] filesystem e diretórios graváveis controlados
[ ] processo sem privilégios excessivos, quando tecnicamente viável
[ ] imagem analisada quanto a vulnerabilidades
```

### Nota importante sobre `php:8.4-apache`

Não adicione simplesmente:

```dockerfile
USER www-data
```

sem testar a arquitetura. O Apache pode necessitar de privilégios no arranque e para bind à porta 80. Se quiser executar totalmente sem root, configure explicitamente uma solução compatível, por exemplo porta não privilegiada e permissões adequadas, e teste o resultado.

---

## 14. HEALTHCHECK

Exemplo **apenas se `curl` existir na imagem runtime**:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -fsS http://127.0.0.1/health || exit 1
```

Se `curl` não estiver instalado, utilize uma ferramenta que exista realmente na imagem ou instale deliberadamente a ferramenta escolhida.

### Docker HEALTHCHECK versus Kubernetes probes

```text
Docker HEALTHCHECK
≠
Kubernetes startup/readiness/liveness probes
```

Os conceitos são relacionados, mas Kubernetes **não transforma automaticamente** o `HEALTHCHECK` da imagem em probes Kubernetes.

---

## 15. Scan de vulnerabilidades

Quando Trivy estiver disponível no laboratório:

```bash
trivy image symfony-demo:1.0.0
```

Um scan é uma fonte de evidência para gestão de risco; não substitui atualização, hardening, revisão de dependências ou política de segurança.

---

## 16. Tags, versões e digest

```bash
# Criar uma tag
docker tag symfony-demo:1.0.0 <registry>/formacao/symfony-demo:1.0.0

# Ver RepoDigests após pull/push, quando disponíveis
docker image inspect <imagem>:<tag> --format '{{json .RepoDigests}}'
```

### Semântica importante

```text
latest
→ tag mutável
→ evitar como referência de release

1.0.0
→ tag versionada
→ deve ser tratada como imutável por política
→ tecnicamente pode ser sobrescrita se o registry o permitir

digest sha256:...
→ identidade imutável do conteúdo da imagem
```

Para DEV → TEST → PROD, promova a **mesma imagem**, idealmente verificando o mesmo digest. Não reconstrua uma imagem diferente apenas porque muda o ambiente.

---

## 17. Registry

```bash
# Docker Hub
docker login

docker tag symfony-demo:1.0.0 <utilizador>/symfony-demo:1.0.0
docker push <utilizador>/symfony-demo:1.0.0
docker pull <utilizador>/symfony-demo:1.0.0

# Registry privado
docker login <registry>

docker tag symfony-demo:1.0.0 <registry>/formacao/symfony-demo:1.0.0
docker push <registry>/formacao/symfony-demo:1.0.0
docker pull <registry>/formacao/symfony-demo:1.0.0

# Terminar sessão
docker logout
docker logout <registry>
```

---

## 18. Compose de produção num único host

Na Sessão 3, o objetivo é um **deployment controlado num único host Docker**. Isto não equivale a alta disponibilidade nem a um orquestrador de cluster.

Padrão de imagem:

```yaml
services:
  app:
    image: ${SYMFONY_IMAGE}:${APP_VERSION}
```

Exemplo de variáveis:

```text
SYMFONY_IMAGE=<registry>/formacao/symfony-demo
APP_VERSION=1.0.0
APP_ENV=prod
```

### Validar e iniciar

```bash
docker compose --env-file .env.prod -f compose.prod.yaml config

docker compose --env-file .env.prod -f compose.prod.yaml pull

docker compose --env-file .env.prod -f compose.prod.yaml up -d

docker compose --env-file .env.prod -f compose.prod.yaml ps
```

### Migrações

Se a aplicação e o laboratório utilizarem Doctrine Migrations e o procedimento tiver sido previamente validado:

```bash
docker compose --env-file .env.prod -f compose.prod.yaml run --rm app \
  php bin/console doctrine:migrations:migrate --no-interaction
```

Migrações devem ser tratadas como passo controlado de deployment. Avalie compatibilidade, idempotência e concorrência antes de automatizar.

---

## 19. Validação do deployment

```bash
curl -f http://localhost:8080/info
curl -f http://localhost:8080/health
curl -f http://localhost:8080/ready

docker compose --env-file .env.prod -f compose.prod.yaml ps
docker compose --env-file .env.prod -f compose.prod.yaml logs --tail 100 app
```

Valide sempre:

```text
versão esperada
+ health
+ readiness
+ logs
+ dependências
```

---

## 20. Atualização e rollback

### Atualizar

Exemplo:

```text
APP_VERSION=1.0.0
        ↓
APP_VERSION=1.1.0
```

Depois:

```bash
docker compose --env-file .env.prod -f compose.prod.yaml pull app

docker compose --env-file .env.prod -f compose.prod.yaml up -d --force-recreate app
```

Valide novamente `/info`, `/health`, `/ready` e logs.

### Rollback

Repor explicitamente a versão anterior:

```text
APP_VERSION=1.0.0
```

Depois:

```bash
docker compose --env-file .env.prod -f compose.prod.yaml pull app

docker compose --env-file .env.prod -f compose.prod.yaml up -d --force-recreate app
```

> Um `--force-recreate` sem repor a versão anterior **não é rollback**; apenas recria o serviço com a configuração/imagem atualmente selecionada.

---

## 21. Diagnóstico rápido

| Situação | Evidências/comandos úteis |
|---|---|
| Container não inicia | `docker ps -a`, `docker logs <container>`, `docker inspect <container>` |
| Aplicação não responde | `docker port <container>`, `curl -i http://localhost:<porta>`, `docker exec -it <container> /bin/sh` |
| Serviço Compose falha | `docker compose ps`, `docker compose logs <serviço>`, `docker compose config` |
| App não comunica com PostgreSQL | `docker network inspect <rede>`, confirmar hostname `db` e `DATABASE_URL`, consultar logs |
| Dados parecem ter desaparecido | `docker volume ls`, `docker volume inspect <volume>`, confirmar mount da BD |
| `/health` funciona mas `/ready` falha | verificar dependências, especialmente ligação à BD |
| Healthcheck Docker falha | `docker inspect <container>`, consultar `.State.Health` e logs do serviço |
| Falha no pull/push | `docker login`, confirmar registry, nome, tag, permissões e conectividade |

---

## 22. Limpeza controlada

```bash
# Recursos parados/não utilizados
docker container prune
docker image prune
docker network prune
docker volume prune

# Limpeza mais abrangente
docker system prune

# Muito destrutivo: inclui imagens não utilizadas e volumes não utilizados
docker system prune -a --volumes
```

> Antes de utilizar comandos `prune`, confirme o que pode ser removido. Em especial, `docker volume prune` pode eliminar dados persistentes que já não estejam ligados a containers.

---

## 23. Checklist pré-produção da Sessão 3

- [ ] A imagem usa uma base com versão explícita.
- [ ] Não dependemos de `latest` para identificar uma release.
- [ ] Tags versionadas são tratadas como imutáveis por política.
- [ ] O digest da imagem pode ser verificado quando necessário.
- [ ] O `.dockerignore` exclui dados desnecessários ou sensíveis.
- [ ] A ordem das layers aproveita a cache de build.
- [ ] É utilizado multi-stage quando acrescenta valor.
- [ ] A imagem runtime contém apenas o necessário para execução.
- [ ] PHP e extensões são compatíveis com Symfony Demo v3.1.0 e PostgreSQL 16.
- [ ] Apache serve a aplicação a partir de `/var/www/html/public`.
- [ ] `var/` possui permissões adequadas.
- [ ] Não existem segredos no Dockerfile, layers, imagem ou repositório.
- [ ] A configuração varia externamente entre DEV, TEST e PROD.
- [ ] O hardening foi testado; não se adicionou `USER` de forma cega.
- [ ] `/health` e `/ready` têm responsabilidades distintas.
- [ ] Qualquer `HEALTHCHECK` usa uma ferramenta que existe realmente na imagem.
- [ ] A imagem foi analisada quanto a vulnerabilidades.
- [ ] O registry e o fluxo de promoção foram testados.
- [ ] A mesma imagem é promovida entre ambientes, sem rebuild desnecessário.
- [ ] O deployment valida versão, health, readiness e logs.
- [ ] Existe um procedimento explícito de atualização.
- [ ] Existe um procedimento explícito e testado de rollback.
- [ ] Dados persistentes utilizam armazenamento adequado.
- [ ] Persistência não é confundida com backup.

---

## Resumo da progressão

```text
Sessão 2
OPERAR
imagem existente
  ↓
containers
  ↓
networking
  ↓
storage
  ↓
Compose
  ↓
troubleshooting

Sessão 3
CONSTRUIR / PREPARAR
código
  ↓
Dockerfile
  ↓
build / cache / multi-stage
  ↓
hardening
  ↓
healthcheck / scan
  ↓
versionamento
  ↓
registry
  ↓
deployment
  ↓
update / rollback
```
