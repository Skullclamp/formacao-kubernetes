# Sessão 2 — Docker I

## Operação, Networking, Storage e Docker Compose

**Duração:** 4 horas  
**Nível:** intermédio

## Objetivo

No final da sessão deverá conseguir operar uma aplicação já containerizada, ligá-la a outros serviços, garantir persistência de dados e executar troubleshooting básico num host Docker.

## Percurso

```text
Containers
    ↓
Logs / Exec / Inspect / Stats
    ↓
Networking
    ↓
Storage
    ↓
Docker Compose
    ↓
Symfony Demo + PostgreSQL
    ↓
Troubleshooting
```

## Laboratórios

1. [Containers e ciclo de vida](labs/01-containers.md)
2. [Diagnóstico e inspeção](labs/02-diagnostico.md)
3. [Networking Docker](labs/03-networking.md)
4. [Storage Docker](labs/04-storage.md)
5. [Symfony Demo + PostgreSQL com Compose](labs/05-compose.md)
6. [Troubleshooting integrado](labs/06-troubleshooting.md)

## Ficheiros de apoio

- [`compose/compose.yaml`](compose/compose.yaml)
- [`compose/.env.example`](compose/.env.example)
- [`desafios/troubleshooting.md`](desafios/troubleshooting.md)
- [`checklist.md`](checklist.md)

## Antes de começar

```bash
cd formacao-kubernetes
git pull
cd sessao-02
```

Confirme:

```bash
docker version
docker info
docker compose version
```

> Nesta sessão não construímos a imagem Symfony. Dockerfile, build, layers, cache, multi-stage, hardening e publicação no registry ficam para a Sessão 3.
