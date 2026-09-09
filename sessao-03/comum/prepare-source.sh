#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${ROOT_DIR}/app"
OVERLAY_DIR="${ROOT_DIR}/comum/overlay"

rm -rf "${APP_DIR}"

git clone --depth 1 --branch v3.1.0 \
  https://github.com/symfony/demo.git \
  "${APP_DIR}"

install -D -m 0644 \
  "${OVERLAY_DIR}/src/Controller/LabController.php" \
  "${APP_DIR}/src/Controller/LabController.php"

install -D -m 0644 \
  "${OVERLAY_DIR}/config/routes/lab.yaml" \
  "${APP_DIR}/config/routes/lab.yaml"

rm -rf "${APP_DIR}/.git"

echo "Source preparado em: ${APP_DIR}"
