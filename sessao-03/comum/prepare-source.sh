#!/usr/bin/env bash

# Modo seguro do Bash:
# -e termina se um comando falhar;
# -u falha ao usar variáveis não definidas;
# pipefail propaga erros ocorridos dentro de pipelines.
set -euo pipefail

# Determina a raiz da Sessão 3 e define:
# - APP_DIR: diretoria onde ficará a Symfony Demo;
# - OVERLAY_DIR: ficheiros pedagógicos que serão aplicados sobre o projeto original.
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/app"
OVERLAY_DIR="${ROOT_DIR}/comum/overlay"

# Remove uma cópia anterior da aplicação para garantir uma preparação reproduzível.
# Atenção: este comando elimina completamente a diretoria app/ existente.
rm -rf "${APP_DIR}"

# Obtém apenas a versão v3.1.0 da Symfony Demo:
# --depth 1 reduz o histórico transferido;
# --branch fixa a versão usada na formação;
# APP_DIR define a diretoria de destino.
git clone --depth 1 --branch v3.1.0 \
  https://github.com/symfony/demo.git \
  "${APP_DIR}"

# Instala o controlador pedagógico dentro da aplicação:
# -D cria diretórios intermédios quando necessário;
# -m 0644 define permissões de leitura/escrita adequadas a um ficheiro de código.
install -D -m 0644 \
  "${OVERLAY_DIR}/src/Controller/LabController.php" \
  "${APP_DIR}/src/Controller/LabController.php"

# Instala as rotas /info, /health e /ready usadas no laboratório.
install -D -m 0644 \
  "${OVERLAY_DIR}/config/routes/lab.yaml" \
  "${APP_DIR}/config/routes/lab.yaml"

# Remove os metadados Git do projeto Symfony clonado.
# O laboratório trabalha com o source como contexto de build, não como sub-repositório Git.
rm -rf "${APP_DIR}/.git"

# Confirma ao formando a localização do source preparado.
echo "Source preparado em: ${APP_DIR}"
