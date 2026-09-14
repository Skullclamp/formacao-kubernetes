# Sessão 2 — Docker I

## Operação, Networking, Storage e Docker Compose

**Duração:** 4 horas  
**Nível:** intermédio

## Objetivo

No final da sessão deverá conseguir operar uma aplicação já containerizada, ligá-la a outros serviços, garantir persistência de dados e executar troubleshooting básico num host Docker.

## Documentação da sessão

- [Plano revisto da Sessão 2](plano_sessao_2.md)
- [Manual do formando](manual_formando.md)

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

## Antes de começar — garantir a branch `main`

Não assumir que a shell abriu dentro do repositório nem eliminar uma diretoria não-Git com o mesmo nome.

```bash
clear

REPO_DIR="$HOME/formacao-kubernetes"
REPO_URL="https://github.com/Skullclamp/formacao-kubernetes.git"

if [ -d "$REPO_DIR/.git" ]; then
  git -C "$REPO_DIR" switch main
  git -C "$REPO_DIR" pull --ff-only origin main
elif [ -e "$REPO_DIR" ]; then
  BACKUP_DIR="${REPO_DIR}.bak-$(date +%Y%m%d-%H%M%S)"
  mv "$REPO_DIR" "$BACKUP_DIR"
  echo "Diretoria anterior preservada em: $BACKUP_DIR"
  git clone --branch main --single-branch "$REPO_URL" "$REPO_DIR"
else
  git clone --branch main --single-branch "$REPO_URL" "$REPO_DIR"
fi

git -C "$REPO_DIR" branch --show-current
git -C "$REPO_DIR" status --short

cd "$REPO_DIR/sessao-02"
pwd
```

Esperado:

```text
branch ativa: main
.../formacao-kubernetes/sessao-02
```

Confirme o ambiente Docker:

```bash
docker version
docker info
docker compose version
```

> Nesta sessão não construímos a imagem Symfony. Dockerfile, build, layers, cache, multi-stage, hardening e publicação no registry ficam para a Sessão 3.
