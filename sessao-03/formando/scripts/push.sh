#!/usr/bin/env bash

# Falha cedo perante erros, variáveis não definidas ou pipelines incompletos.
set -euo pipefail

# A versão é recebida no primeiro argumento do script.
VERSION="${1:-}"

# Obriga o operador a indicar explicitamente a versão a publicar.
if [[ -z "$VERSION" ]]; then
  echo "Uso: $0 VERSION" >&2
  exit 2
fi

# IMAGE_REPO deve existir no ambiente, por exemplo:
# export IMAGE_REPO=ghcr.io/utilizador/symfony-demo
# A expansão :? termina o script com erro se a variável não estiver definida.
: "${IMAGE_REPO:?Defina IMAGE_REPO, por exemplo ghcr.io/UTILIZADOR/symfony-demo}"

# Constrói as referências local e remota da mesma versão.
LOCAL_IMAGE="symfony-demo:${VERSION}"
REMOTE_IMAGE="${IMAGE_REPO}:${VERSION}"

# Confirma que a imagem local existe antes de tentar publicar.
docker image inspect "$LOCAL_IMAGE" >/dev/null

# Cria uma nova referência para o registry. docker tag não reconstrói a imagem.
docker tag "$LOCAL_IMAGE" "$REMOTE_IMAGE"

# Envia para o registry as layers que ainda não estejam presentes no destino.
docker push "$REMOTE_IMAGE"

# Depois do push, mostra os RepoDigests conhecidos localmente.
# --format seleciona apenas os valores relevantes em vez do JSON completo.
echo "RepoDigests:"
docker image inspect "$REMOTE_IMAGE" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}'
