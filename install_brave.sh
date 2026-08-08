#!/data/data/com.termux/files/usr/bin/bash
#######################################################
#  🌐 NUNTIUS MODULE - Brave Browser Auto-Installer
#  Incluye: Repositorio oficial, Wrapper GPU, Políticas
#######################################################

# ============== CONFIGURACIÓN ==============
CHROME_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --check-for-update-interval=31449600"
LOG_DIR="${PREFIX:-/data/data/com.termux/files/usr}/tmp"
mkdir -p "$LOG_DIR"

# ============== COLORES ==============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# ============== SPINNER & UI ==============
spinner() {
    local pid=$1
    local message=$2
    local logfile=$3
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    local start_time=$(date +%s)

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        local elapsed=$(($(date +%s) - start_time))
        local mins=$((elapsed / 60))
        local secs=$((elapsed % 60))
        local time_str=$(printf "%02d:%02d" $mins $secs)

        local current_action=""
        if [ -n "$logfile" ] && [ -f "$logfile" ]; then
            current_action=$(tail -n 1 "$logfile" 2>/dev/null | tr -cd '[:print:]' | cut -c 1-35)
        fi

        printf "\r\033[K  ${YELLOW}⏳${NC} ${message} [${CYAN}${time_str}${NC}] ${CYAN}${spin:$i:1}${NC} ${GRAY}${current_action}${NC}"
        sleep 0.3
    done
    wait $pid
    local exit_code=$?
    
    local elapsed=$(($(date +%s) - start_time))
    local mins=$((elapsed / 60))
    local secs=$((elapsed % 60))
    local time_str=$(printf "%02d:%02d" $mins $secs)

    printf "\r\033[K" 
    if [ $exit_code -eq 0 ]; then
        printf "  ${GREEN}✓${NC} ${message} [${CYAN}${time_str}${NC}]\n"
    else
        printf "  ${RED}✗${NC} ${message} (falló) [${CYAN}${time_str}${NC}]\n"
        if [ -n "$logfile" ] && [ -f "$logfile" ]; then
            echo -e "\n${RED}[!] Últimos registros del error:${NC}"
            tail -n 5 "$logfile" 2>/dev/null
        fi
        exit 1
    fi
}

# ============== PASOS DE INSTALACIÓN ==============

install_brave() {
    echo -e "${CYAN}[+] Instalando y configurando Brave Browser...${NC}"

    # 1. Dependencias del repositorio
    (
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y --no-install-recommends curl ca-certificates gnupg
    ) > "$LOG_DIR/n_brave_deps.log" 2>&1 &
    spinner $! "Instalando dependencias base..." "$LOG_DIR/n_brave_deps.log"

    # 2. Agregar Repositorio Oficial de Brave
    (
        curl -fsSL --retry 3 -o /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" > /etc/apt/sources.list.d/brave-browser-release.list
        apt-get update -y
        apt-get install -y --no-install-recommends brave-browser
    ) > "$LOG_DIR/n_brave_repo.log" 2>&1 &
    spinner $! "Añadiendo repositorio y descargando Brave..." "$LOG_DIR/n_brave_repo.log"

    # 3. Configurar Escritorio y Accesos Directos
    (
        sed -i 's/-stable//g' /usr/share/applications/brave-browser.desktop 2>/dev/null || true
        mkdir -p "$HOME/Desktop"
        if [ -f /usr/share/applications/brave-browser.desktop ]; then
            cp /usr/share/applications/brave-browser.desktop "$HOME/Desktop/"
            chown 1000:1000 "$HOME/Desktop/brave-browser.desktop"
            chmod +x "$HOME/Desktop/brave-browser.desktop"
        fi
    ) > "$LOG_DIR/n_brave_desk.log" 2>&1 &
    spinner $! "Configurando accesos directos..." "$LOG_DIR/n_brave_desk.log"

    # 4. Crear Lanzador Inteligente con Wrapper de GPU y Corrector de Cierres
    (
        if [ -f /usr/bin/brave-browser ] && [ ! -f /usr/bin/brave-browser-orig ]; then
            mv /usr/bin/brave-browser /usr/bin/brave-browser-orig
        fi

        cat >/usr/bin/brave-browser <<EOL
#!/usr/bin/env bash
mkdir -p ~/.config/BraveSoftware/Brave-Browser/Default
if [ -f ~/.config/BraveSoftware/Brave-Browser/Default/Preferences ]; then
    sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences 2>/dev/null || true
    sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences 2>/dev/null || true
fi

if [ -f /opt/VirtualGL/bin/vglrun ] && [ -n "\${KASM_EGL_CARD}" ] && [ -n "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Brave with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /opt/brave.com/brave/brave-browser ${CHROME_ARGS} "\$@"
else
    echo "Starting Brave"
    /opt/brave.com/brave/brave-browser ${CHROME_ARGS} "\$@"
fi
EOL
        chmod +x /usr/bin/brave-browser
        cp -f /usr/bin/brave-browser /usr/bin/brave

        # Actualizar x-www-browser por seguridad
        if [ -f /usr/bin/x-www-browser ]; then
            sed -i 's@exec -a "$0" "$HERE/brave-browser" "$@">@exec -a "$0" "$HERE/brave" "$CHROME_ARGS" "$@"@' /usr/bin/x-www-browser 2>/dev/null || true
        fi
    ) > "$LOG_DIR/n_brave_wrapper.log" 2>&1 &
    spinner $! "Generando wrapper y optimizaciones..." "$LOG_DIR/n_brave_wrapper.log"

    # 5. Políticas y Configuración Administrada
    (
        mkdir -p /etc/opt/chrome/policies/managed
        [ -e /etc/brave/policies ] && rm -rf /etc/brave/policies
        mkdir -p /etc/brave
        ln -sf /etc/opt/chrome/policies /etc/brave/policies

        cat > /etc/opt/chrome/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL
        cat > /etc/opt/chrome/policies/managed/disable_tor.json <<EOL
{"TorDisabled": true}
EOL
    ) > "$LOG_DIR/n_brave_pol.log" 2>&1 &
    spinner $! "Aplicando políticas predeterminadas..." "$LOG_DIR/n_brave_pol.log"

    # 6. Limpieza final de paquetes residuales
    (
        [ -z "${SKIP_CLEAN+x}" ] && apt-get autoclean -y && rm -rf /var/lib/apt/lists/* /var/tmp/*
        chown -R 1000:0 "$HOME" 2>/dev/null || true
        find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \; 2>/dev/null || true
    ) > "$LOG_DIR/n_brave_clean.log" 2>&1 &
    spinner $! "Limpiando cachés del sistema..." "$LOG_DIR/n_brave_clean.log"

    echo -e "\n${GREEN}  ╔════════════════════════════════════════════════╗"
    echo -e "  ║      ✅ BRAVE BROWSER INSTALADO CON ÉXITO ✅   ║"
    echo -e "  ╚════════════════════════════════════════════════╝${NC}\n"
}

# Ejecución de la función principal
install_brave
