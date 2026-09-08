# Lab 5 — Symfony Demo + PostgreSQL com Docker Compose

**Duração prevista:** 40 minutos  
**Objetivo:** interpretar e operar uma aplicação multi-container com Docker Compose.

## Arquitetura

```text
Utilizador :8080
      ↓
Symfony Demo
PHP 8.4 + Apache
      ↓
 app-network
      ↓
PostgreSQL 16
      ↓
   db-data
```

## 1. Preparar ficheiros

```bash
cd sessao-02/compose
cp .env.example .env
```

Edite `.env` e substitua `<registry>/formacao/symfony-demo:1.0` pela imagem indicada pelo formador.

> Não utilize `docker build` nesta sessão.

## 2. Interpretar antes de executar

Identifique no `compose.yaml`:

1. serviços;
2. imagens;
3. porta publicada;
4. rede;
5. volume;
6. hostname utilizado pela aplicação para chegar à BD;
7. variáveis PostgreSQL.

Explique por que `DATABASE_URL` utiliza `@db:5432` em vez de `localhost:5432`.

## 3. Validar configuração

```bash
docker compose config
```

Não prossiga enquanto existirem erros.

## 4. Iniciar

```bash
docker compose up -d
docker compose ps
docker compose logs db
docker compose logs app
```

## 5. Inicialização da BD

O formador indicará se a imagem já contém o estado inicial necessário.

Quando for necessário criar o esquema numa BD vazia:

```bash
docker compose exec app \
  php bin/console doctrine:schema:create \
  --no-interaction
```

Se a imagem de laboratório disponibilizar as fixtures necessárias:

```bash
docker compose exec app \
  php bin/console doctrine:fixtures:load \
  --no-interaction
```

Não repita a carga de fixtures durante o teste de persistência.

## 6. Validar a aplicação

```bash
curl http://localhost:8080/health
curl http://localhost:8080/ready
curl http://localhost:8080/info
```

Registe aplicação, versão, ambiente, hostname e estado dos endpoints.

## 7. Inspecionar recursos

```bash
docker compose ps
docker network ls
docker volume ls
```

Inspecione a rede e o volume do projeto.

## 8. Provar persistência

Crie ou altere um dado através da aplicação e registe-o.

Depois:

```bash
docker compose down
docker volume ls
docker compose up -d
curl http://localhost:8080/ready
```

Confirme que o dado continua disponível.

### Atenção

Durante esta prova não execute:

```bash
docker compose down -v
```

A opção `-v` remove os volumes declarados pelo projeto.
