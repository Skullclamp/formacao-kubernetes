# Lab 06 — Registry e Promoção

**Duração prevista:** 25 minutos

**Objetivo:** publicar ou consumir uma imagem versionada e compreender o princípio build once/promote.

## Modo A — cada formando tem um namespace GHCR

```bash
export IMAGE_REPO=ghcr.io/UTILIZADOR_GITHUB/symfony-demo
```

Autenticar com token próprio:

```bash
export CR_PAT='TOKEN_PESSOAL'
echo "$CR_PAT" | docker login ghcr.io \
  -u UTILIZADOR_GITHUB \
  --password-stdin
```

Nunca enviar o token ao formador nem colocá-lo no repositório.

Publicar:

```bash
./formando/scripts/push.sh 1.0.0
```

## Modo B — consumir as imagens públicas da formação

```bash
export IMAGE_REPO=ghcr.io/skullclamp/symfony-demo
docker pull "$IMAGE_REPO:1.0.0"
docker pull "$IMAGE_REPO:1.1.0"
```

A imagem `1.2.0-rc1` é utilizada posteriormente no exercício de falha controlada.

> Pull das imagens públicas não exige `docker login`. Push para um namespace pessoal exige autenticação e permissões de escrita.

## Promoção

```text
um build
   ↓
uma imagem/digest
   ├── DEV
   ├── TEST
   └── PROD
```

Não reconstruir a aplicação separadamente em cada ambiente.

## Validação

Depois do push ou pull:

```bash
docker image inspect \
  "$IMAGE_REPO:1.0.0" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
```
