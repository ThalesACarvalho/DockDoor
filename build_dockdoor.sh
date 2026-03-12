#!/bin/bash
set -eo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$PROJECT_DIR/DockDoor.xcodeproj"
SCHEME="DockDoor"
CONFIGURATION="Release"
BUILD_DIR="$PROJECT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
APP_NAME="DockDoor.app"
DMG_NAME="DockDoor-Installer.dmg"
PRODUCTS_DIR="$DERIVED_DATA/Build/Products/$CONFIGURATION"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${CYAN}[BUILD]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

log "============================================"
log "  DockDoor — Build & Installer Script"
log "============================================"
echo ""

# -----------------------------------------------------------
# 1. Pre-flight checks
# -----------------------------------------------------------
log "Verificando pré-requisitos..."

command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild não encontrado. Instale o Xcode."
command -v hdiutil >/dev/null 2>&1    || fail "hdiutil não encontrado."

XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1 || echo "desconhecida")
ok "Xcode encontrado: $XCODE_VERSION"

if [ ! -d "$PROJECT" ]; then
    fail "Projeto não encontrado em $PROJECT"
fi
ok "Projeto encontrado."

# -----------------------------------------------------------
# 2. Clean previous build
# -----------------------------------------------------------
log "Limpando builds anteriores..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
ok "Diretório de build limpo."

# -----------------------------------------------------------
# 3. Resolve Swift Package dependencies
# -----------------------------------------------------------
log "Resolvendo dependências Swift Package Manager..."
xcodebuild -resolvePackageDependencies \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA" \
    -clonedSourcePackagesDirPath "$BUILD_DIR/SourcePackages" \
    > "$BUILD_DIR/resolve.log" 2>&1 || {
        fail "Falha ao resolver dependências. Veja: $BUILD_DIR/resolve.log"
    }

ok "Dependências resolvidas."

# -----------------------------------------------------------
# 4. Build Release
# -----------------------------------------------------------
log "Compilando DockDoor em modo Release..."
log "(isso pode levar alguns minutos na primeira vez)"
echo ""

xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -clonedSourcePackagesDirPath "$BUILD_DIR/SourcePackages" \
    -destination 'platform=macOS' \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    COMPILER_INDEX_STORE_ENABLE=NO \
    > "$BUILD_DIR/build.log" 2>&1 || {
        echo ""
        echo -e "${RED}Build falhou. Últimas linhas do log:${NC}"
        tail -30 "$BUILD_DIR/build.log"
        echo ""
        fail "Veja log completo em: $BUILD_DIR/build.log"
    }

echo ""

if [ ! -d "$PRODUCTS_DIR/$APP_NAME" ]; then
    fail "Build falhou — $APP_NAME não encontrado em $PRODUCTS_DIR"
fi

ok "Build concluído com sucesso!"

# -----------------------------------------------------------
# 5. Ad-hoc code sign (for local use)
# -----------------------------------------------------------
log "Assinando app localmente (ad-hoc)..."

codesign --force --deep --sign - "$PRODUCTS_DIR/$APP_NAME" 2>/dev/null || {
    warn "Assinatura ad-hoc falhou, mas o app ainda pode funcionar localmente."
}

ok "App assinado."

# -----------------------------------------------------------
# 6. App info
# -----------------------------------------------------------
APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PRODUCTS_DIR/$APP_NAME/Contents/Info.plist" 2>/dev/null || echo "desconhecida")
APP_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PRODUCTS_DIR/$APP_NAME/Contents/Info.plist" 2>/dev/null || echo "desconhecida")
APP_SIZE=$(du -sh "$PRODUCTS_DIR/$APP_NAME" | cut -f1)

log "Versão: $APP_VERSION (build $APP_BUILD)"
log "Tamanho: $APP_SIZE"

# -----------------------------------------------------------
# 7. Create DMG installer
# -----------------------------------------------------------
log "Criando DMG instalador..."

DMG_TEMP="$BUILD_DIR/dmg_staging"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"

cp -R "$PRODUCTS_DIR/$APP_NAME" "$DMG_TEMP/"
ln -s /Applications "$DMG_TEMP/Applications"

hdiutil create \
    -volname "DockDoor $APP_VERSION" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH" \
    2>&1 | grep -v "^$" || true

rm -rf "$DMG_TEMP"

if [ ! -f "$DMG_PATH" ]; then
    fail "Falha ao criar DMG."
fi

DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)
ok "DMG criado: $DMG_SIZE"

# -----------------------------------------------------------
# 8. Summary
# -----------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Build concluído com sucesso!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  App:          ${CYAN}$PRODUCTS_DIR/$APP_NAME${NC}"
echo -e "  Instalador:   ${CYAN}$DMG_PATH${NC}"
echo -e "  Versão:       $APP_VERSION (build $APP_BUILD)"
echo ""
echo -e "  ${YELLOW}Para instalar:${NC}"
echo -e "    1. Abra ${CYAN}$DMG_NAME${NC}"
echo -e "    2. Arraste DockDoor para a pasta Applications"
echo -e "    3. Na primeira execução, clique com botão direito > Abrir"
echo -e "       (necessário pois o app não é notarizado pela Apple)"
echo ""
echo -e "  ${YELLOW}Permissões necessárias ao abrir:${NC}"
echo -e "    - Acessibilidade (System Settings > Privacy > Accessibility)"
echo -e "    - Gravação de Tela (System Settings > Privacy > Screen Recording)"
echo ""

open "$BUILD_DIR"
