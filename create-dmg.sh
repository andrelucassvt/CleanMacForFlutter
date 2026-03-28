#!/bin/bash
set -euo pipefail

# ============================================================
# create-dmg.sh — Gera um .dmg personalizado com drag-to-Applications
# Para: Clean Mac For Flutter v1.0.1
# ============================================================

APP_NAME="CleanMacForFlutters"
DISPLAY_NAME="Clean Mac For Flutter"
VERSION="1.0.1"
DMG_NAME="${APP_NAME}-${VERSION}"
DMG_FINAL="${DMG_NAME}.dmg"
DMG_TEMP="${DMG_NAME}-temp.dmg"
VOLUME_NAME="${DISPLAY_NAME} ${VERSION}"
BUILD_DIR="build/Release"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
STAGING_DIR="build/dmg-staging"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Criando DMG para ${DISPLAY_NAME} v${VERSION} ===${NC}"

# ── 1. Build do app em Release ──────────────────────────────
echo -e "${YELLOW}[1/5] Compilando em Release...${NC}"
xcodebuild -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath build/DerivedData \
    BUILD_DIR="$(pwd)/build" \
    clean build \
    -quiet

if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}Erro: ${APP_PATH} não encontrado após o build.${NC}"
    exit 1
fi

echo -e "${GREEN}  ✔ Build concluído${NC}"

# ── 2. Preparar diretório de staging ────────────────────────
echo -e "${YELLOW}[2/5] Preparando staging...${NC}"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

echo -e "${GREEN}  ✔ Staging pronto${NC}"

# ── 3. Criar DMG temporário (read-write) ────────────────────
echo -e "${YELLOW}[3/5] Criando DMG temporário...${NC}"
rm -f "${DMG_TEMP}" "${DMG_FINAL}"

# Calcula tamanho necessário (app + margem)
APP_SIZE_KB=$(du -sk "${STAGING_DIR}" | awk '{print $1}')
DMG_SIZE_KB=$((APP_SIZE_KB + 20480))  # +20MB de margem

hdiutil create \
    -srcfolder "${STAGING_DIR}" \
    -volname "${VOLUME_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${DMG_SIZE_KB}k" \
    "${DMG_TEMP}"

echo -e "${GREEN}  ✔ DMG temporário criado${NC}"

# ── 4. Personalizar aparência do DMG ────────────────────────
echo -e "${YELLOW}[4/5] Personalizando layout do DMG...${NC}"

MOUNT_DIR="/Volumes/${VOLUME_NAME}"

# Monta o DMG
hdiutil attach "${DMG_TEMP}" -readwrite -noverify -noautoopen

# Aguarda montagem
sleep 2

# Cria o background
BACKGROUND_DIR="${MOUNT_DIR}/.background"
mkdir -p "${BACKGROUND_DIR}"

# Gera imagem de background com instruções visuais
# Usa sips/CoreGraphics via Python para criar o background
python3 << 'PYEOF'
import subprocess
import os

mount_dir = os.environ.get("MOUNT_DIR", "/Volumes/Clean Mac For Flutter 1.0.1")
bg_path = os.path.join(mount_dir, ".background", "background.png")

# Cria um background usando o comando tiffutil/sips ou gera via CoreImage
# Usa Pillow se disponível, senão cria um HTML e converte
try:
    from PIL import Image, ImageDraw, ImageFont

    width, height = 660, 400
    img = Image.new('RGB', (width, height), color=(30, 30, 32))
    draw = ImageDraw.Draw(img)

    # Seta indicando drag
    arrow_y = height // 2
    draw.text((width // 2 - 60, arrow_y - 10), "⟹", fill=(200, 200, 200))
    draw.text((width // 2 - 100, height - 60), "Arraste para Aplicativos", fill=(180, 180, 180))

    img.save(bg_path)
    print("Background criado com Pillow")
except ImportError:
    # Fallback: cria background via sips (converte um TIFF simples)
    # Gera um PNG simples com dados raw
    import struct, zlib

    width, height = 660, 400

    def create_png(w, h, r, g, b):
        def chunk(chunk_type, data):
            c = chunk_type + data
            return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

        header = b'\x89PNG\r\n\x1a\n'
        ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))

        raw_data = b''
        for y in range(h):
            raw_data += b'\x00'  # filter byte
            for x in range(w):
                raw_data += struct.pack('BBB', r, g, b)

        idat = chunk(b'IDAT', zlib.compress(raw_data))
        iend = chunk(b'IEND', b'')
        return header + ihdr + idat + iend

    png_data = create_png(width, height, 30, 30, 32)
    with open(bg_path, 'wb') as f:
        f.write(png_data)
    print("Background criado (fallback)")
PYEOF

# Configura o layout do Finder via AppleScript
osascript << APPLESCRIPT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open

        -- Configurações da janela
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 760, 520}

        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 14
        set background picture of viewOptions to file ".background:background.png"

        -- Posiciona o app à esquerda e Applications à direita
        set position of item "${APP_NAME}.app" of container window to {160, 180}
        set position of item "Applications" of container window to {500, 180}

        close
        open

        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

# Sincroniza e desmonta
sync
hdiutil detach "${MOUNT_DIR}" -quiet

echo -e "${GREEN}  ✔ Layout personalizado${NC}"

# ── 5. Converter para DMG comprimido (read-only) ────────────
echo -e "${YELLOW}[5/5] Comprimindo DMG final...${NC}"

hdiutil convert "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_FINAL}"

rm -f "${DMG_TEMP}"
rm -rf "${STAGING_DIR}"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✔ DMG criado com sucesso!${NC}"
echo -e "${GREEN}  📦 ${DMG_FINAL}${NC}"
echo -e "${GREEN}  📏 $(du -h "${DMG_FINAL}" | awk '{print $1}')${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
