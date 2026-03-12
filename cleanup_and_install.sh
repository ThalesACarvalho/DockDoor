#!/bin/bash
set -eo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

BUNDLE_ID="com.ethanbills.DockDoor"
NEW_APP="/Users/thalesaugustocarvalho/Documents/Repos/DockDoor/build/DerivedData/Build/Products/Release/DockDoor.app"
INSTALL_DIR="/Applications"

log()  { echo -e "${CYAN}[SETUP]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

echo ""
log "============================================"
log "  DockDoor — Limpeza e Reinstalação"
log "============================================"
echo ""

# -----------------------------------------------------------
# 1. Encerrar DockDoor
# -----------------------------------------------------------
log "Encerrando DockDoor..."
pkill -f "DockDoor.app/Contents/MacOS/DockDoor" 2>/dev/null && ok "DockDoor encerrado." || ok "DockDoor não estava rodando."
sleep 1

# -----------------------------------------------------------
# 2. Remover app antigo de /Applications
# -----------------------------------------------------------
log "Removendo versão anterior de /Applications..."
if [ -d "$INSTALL_DIR/DockDoor.app" ]; then
    rm -rf "$INSTALL_DIR/DockDoor.app"
    ok "Removido: $INSTALL_DIR/DockDoor.app"
else
    ok "Nenhuma versão anterior encontrada."
fi

# -----------------------------------------------------------
# 3. Reset TCC (permissões do sistema)
# -----------------------------------------------------------
log "Resetando permissões TCC para $BUNDLE_ID..."

tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null && ok "Reset: Accessibility" || warn "Não foi possível resetar Accessibility"
tccutil reset ScreenCapture "$BUNDLE_ID" 2>/dev/null && ok "Reset: ScreenCapture" || warn "Não foi possível resetar ScreenCapture"
tccutil reset AppleEvents "$BUNDLE_ID" 2>/dev/null && ok "Reset: AppleEvents" || warn "Não foi possível resetar AppleEvents"
tccutil reset Calendar "$BUNDLE_ID" 2>/dev/null && ok "Reset: Calendar" || warn "Não foi possível resetar Calendar"

# -----------------------------------------------------------
# 4. Limpar caches de launch services
# -----------------------------------------------------------
log "Reconstruindo banco de dados Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -kill -r -domain local -domain system -domain user 2>/dev/null && \
    ok "Launch Services reconstruído." || warn "Não foi possível reconstruir Launch Services (não crítico)."

# -----------------------------------------------------------
# 5. Instalar nova versão
# -----------------------------------------------------------
log "Instalando nova build em /Applications..."
if [ ! -d "$NEW_APP" ]; then
    fail "Build não encontrada em: $NEW_APP"
fi

cp -R "$NEW_APP" "$INSTALL_DIR/DockDoor.app"
ok "Instalado: $INSTALL_DIR/DockDoor.app"

# -----------------------------------------------------------
# 6. Corrigir permissões do .app
# -----------------------------------------------------------
log "Ajustando permissões de arquivo..."
chmod -R 755 "$INSTALL_DIR/DockDoor.app"
xattr -cr "$INSTALL_DIR/DockDoor.app" 2>/dev/null
ok "Permissões ajustadas e quarentena removida."

# -----------------------------------------------------------
# 7. Registrar no Launch Services
# -----------------------------------------------------------
log "Registrando app no Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    "$INSTALL_DIR/DockDoor.app" 2>/dev/null && \
    ok "App registrado." || warn "Registro manual não necessário."

# -----------------------------------------------------------
# 8. Resumo
# -----------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Limpeza e instalação concluídas!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  ${YELLOW}Próximos passos:${NC}"
echo ""
echo -e "  1. O DockDoor será aberto agora."
echo -e "     Se aparecer alerta de 'app não verificado':"
echo -e "     ${CYAN}Clique com botão direito > Abrir${NC}"
echo ""
echo -e "  2. Conceda as permissões quando solicitado:"
echo -e "     ${CYAN}System Settings > Privacy & Security > Accessibility${NC}"
echo -e "     ${CYAN}System Settings > Privacy & Security > Screen Recording${NC}"
echo ""
echo -e "  3. Após conceder ambas, reinicie o DockDoor."
echo ""

# -----------------------------------------------------------
# 9. Abrir o app
# -----------------------------------------------------------
log "Abrindo DockDoor..."
sleep 2
open "$INSTALL_DIR/DockDoor.app"
ok "DockDoor aberto!"
