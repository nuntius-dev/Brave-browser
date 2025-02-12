#!/usr/bin/env bash
set -ex

# Instalar dependencias
apt-get update
apt install -y apt-transport-https curl

# Descargar y agregar la clave del repositorio de Brave
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

# Agregar el repositorio de Brave
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list

# Instalar Brave Browser
apt update && apt install -y brave-browser

# Crear entrada en el escritorio
cat > /usr/share/applications/brave-browser.desktop <<EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Brave Web Browser
Comment=Accede a Internet.
Exec=/usr/bin/brave-browser %U
Icon=brave-browser
Path=
Terminal=false
StartupNotify=true
EOL

# Copiar acceso directo al escritorio del usuario
cp /usr/share/applications/brave-browser.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/brave-browser.desktop
chmod +x $HOME/Desktop/brave-browser.desktop

# Limpiar paquetes innecesarios
apt-get autoclean && rm -rf /var/lib/apt/lists/* /var/tmp/*

echo "Brave Browser instalado y acceso directo creado en el escritorio."
