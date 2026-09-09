# Lab 06 — Registry e Promoção

**Duração prevista:** 25 minutos

## Objetivo

Publicar ou consumir uma imagem versionada, executando primeiro `docker tag` e `docker push` manualmente, e compreender o princípio **build once / promote the same artifact**.

## Ponto de partida

Executar a partir de:

```text
formacao-kubernetes/sessao-03
```

Confirme:

```bash
docker image inspect symfony-demo:1.0.0 >/dev/null && echo 'OK: imagem local disponível'
```

## Modo A — cada formando tem um namespace GHCR

Definir o destino:

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

## 1. Criar a tag manualmente

```bash
docker tag \
  symfony-demo:1.0.0 \
  "$IMAGE_REPO:1.0.0"
```

Confirmar:

```bash
docker image ls "$IMAGE_REPO"
```

Explique o que mudou: o conteúdo foi reconstruído ou apenas ganhou uma nova referência?

## 2. Publicar manualmente

```bash
docker push "$IMAGE_REPO:1.0.0"
```

Observe as layers enviadas e as que eventualmente já existiam no registry.

## 3. Consultar o digest

```bash
docker image inspect \
  "$IMAGE_REPO:1.0.0" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
```

Registe o digest observado.

## 4. Da execução manual à automação

Já executou:

```text
tag local
   ↓
docker tag
   ↓
docker push
   ↓
RepoDigest
```

Abra agora o script:

```bash
sed -n '1,240p' formando/scripts/push.sh
```

Identifique onde o script:

- valida a versão;
- utiliza `IMAGE_REPO`;
- cria a tag remota;
- faz push;
- apresenta os RepoDigests.

Só depois execute:

```bash
./formando/scripts/push.sh 1.0.0
```

Pergunta:

> Que passos manuais acabou o script de automatizar?

## Modo B — consumir as imagens públicas da formação

Se não tiver namespace GHCR com permissões de escrita:

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
uma imagem
   ↓
um digest
   ├── DEV
   ├── TEST
   └── PROD
```

O princípio é promover o mesmo artefacto, não reconstruir a aplicação separadamente em cada ambiente.

### Síntese

```text
docker build
   ↓
imagem local
   ↓
docker tag
   ↓
referência no registry
   ↓
docker push
   ↓
digest
   ↓
promoção do mesmo artefacto
```
