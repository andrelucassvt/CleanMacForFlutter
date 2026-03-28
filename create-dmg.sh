#!/bin/bash
set -euo pipefail

# ============================================================
# ./create-dmg.sh — Gera um .dmg personalizado com drag-to-Applications
# Para: Clean Mac For Flutter v1.0.1
# Requer: brew install create-dmg
# ============================================================

APP_NAME="CleanMacForFlutters"
DISPLAY_NAME="Clean Mac For Flutter"
VERSION="1.0.1"
DMG_FINAL="${APP_NAME}-${VERSION}.dmg"

# Caminho do .app — aceita o .app diretamente ou uma pasta que o contém
INPUT="${1:-${APP_NAME}.app}"
if [[ "${INPUT}" == *.app ]]; then
    APP_PATH="${INPUT}"
else
    APP_PATH="${INPUT}/${APP_NAME}.app"
fi

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Criando DMG para ${DISPLAY_NAME} v${VERSION} ===${NC}"

# ── 1. Verificar dependências ───────────────────────────────
if ! command -v create-dmg &> /dev/null; then
    echo -e "${RED}Erro: create-dmg não encontrado.${NC}"
    echo -e "${YELLOW}Instale com: brew install create-dmg${NC}"
    exit 1
fi

# ── 2. Verificar app exportado do Archive ──────────────────
echo -e "${YELLOW}[1/2] Verificando app exportado...${NC}"

if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}Erro: ${APP_PATH} não encontrado.${NC}"
    echo -e "${YELLOW}Uso: ./create-dmg.sh \"pasta-do-export\"${NC}"
    echo -e "${YELLOW}Exemplo: ./create-dmg.sh \"CleanMacForFlutters 2026-03-27 21-30-35\"${NC}"
    exit 1
fi

echo -e "${GREEN}  ✔ App encontrado: ${APP_PATH}${NC}"

# ── 3. Criar DMG com drag-to-Applications ──────────────────
echo -e "${YELLOW}[2/2] Criando DMG...${NC}"

rm -f "${DMG_FINAL}"

create-dmg \
    --volname "${DISPLAY_NAME} ${VERSION}" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 128 \
    --icon "${APP_NAME}.app" 160 180 \
    --hide-extension "${APP_NAME}.app" \
    --app-drop-link 500 180 \
    "${DMG_FINAL}" \
    "${APP_PATH}"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✔ DMG criado com sucesso!${NC}"
echo -e "${GREEN}  📦 ${DMG_FINAL}${NC}"
echo -e "${GREEN}  📏 $(du -h "${DMG_FINAL}" | awk '{print $1}')${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
