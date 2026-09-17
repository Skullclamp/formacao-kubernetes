#!/usr/bin/env bash
set -euo pipefail

# Instalação do Helm em Ubuntu/Debian para o laboratório das Sessões 7 e 8.
# Usa o repositório APT atualmente documentado pelo projeto Helm e valida
# a fingerprint da chave antes de a adicionar ao sistema.

HELM_APT_KEY_ID="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"
KEY_TMP="${TMPDIR:-/tmp}/helm.gpg"

ok()   { printf 'OK   %s\n' "$1"; }
err()  { printf 'ERRO %s\n' "$1" >&2; exit 1; }

if command -v helm >/dev/null 2>&1; then
  ok "Helm já está instalado: $(helm version --short 2>/dev/null || echo versão não identificada)"
else
  command -v apt-get >/dev/null 2>&1 \
    || err 'Este instalador destina-se a Ubuntu/Debian com apt-get.'

  printf 'A instalar pré-requisitos...\n'
  sudo apt-get update
  sudo apt-get install -y curl gpg apt-transport-https ca-certificates

  printf 'A obter e validar a chave do repositório Helm...\n'
  curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey -o "$KEY_TMP"

  fingerprint=$(gpg --show-keys --with-colons "$KEY_TMP" \
    | awk -F: '$1 == "fpr" {print $10}' \
    | head -n 1)

  if [ "$fingerprint" != "$HELM_APT_KEY_ID" ]; then
    rm -f "$KEY_TMP"
    err "Fingerprint inesperada para a chave APT do Helm: $fingerprint"
  fi

  gpg --dearmor < "$KEY_TMP" \
    | sudo tee /usr/share/keyrings/helm.gpg >/dev/null
  rm -f "$KEY_TMP"

  echo 'deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main' \
    | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null

  sudo apt-get update
  sudo apt-get install -y helm
fi

printf '\nVersão instalada:\n'
helm version --short

# O laboratório usa esta flag na transição Kustomize -> Helm.
if helm upgrade --help 2>/dev/null | grep -- '--take-ownership' >/dev/null; then
  ok 'Helm suporta --take-ownership'
else
  err 'A versão instalada do Helm não suporta --take-ownership. Atualizar Helm antes do laboratório.'
fi

printf '\nInstalação/validação do Helm concluída com sucesso.\n'
