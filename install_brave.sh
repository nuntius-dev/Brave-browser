#!/usr/bin/env bash
set -ex

ARCH=$(arch | sed 's/aarch64/arm64/g; s/x86_64/amd64/g')
CHROME_ARGS="--password-store=basic --no-sandbox --ignore-gpu-blocklist --user-data-dir --no-first-run --check-for-update-interval=31449600"

# Install dependencies and Brave browser
apt-get update
apt install -y apt-transport-https curl

# Download and add Brave repository
curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
apt update && apt install -y brave-browser

# Set up the Brave desktop icon
sed -i 's/-stable//g' /usr/share/applications/brave-browser.desktop
cp /usr/share/applications/brave-browser.desktop $HOME/Desktop/
chown 1000:1000 $HOME/Desktop/brave-browser.desktop
chmod +x $HOME/Desktop/brave-browser.desktop

# Create custom Brave browser launcher
mv /usr/bin/brave-browser /usr/bin/brave-browser-orig
cat >/usr/bin/brave-browser <<EOL
#!/usr/bin/env bash
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"None"/' ~/.config/BraveSoftware/Brave-Browser/Default/Preferences
if [ -f /opt/VirtualGL/bin/vglrun ] && [ -n "\${KASM_EGL_CARD}" ] && [ -n "\${KASM_RENDERD}" ] && [ -O "\${KASM_RENDERD}" ] && [ -O "\${KASM_EGL_CARD}" ] ; then
    echo "Starting Brave with GPU Acceleration on EGL device \${KASM_EGL_CARD}"
    vglrun -d "\${KASM_EGL_CARD}" /opt/brave.com/brave/brave-browser ${CHROME_ARGS} "\$@"
else
    echo "Starting Brave"
    /opt/brave.com/brave/brave-browser ${CHROME_ARGS} "\$@"
fi
EOL
chmod +x /usr/bin/brave-browser
cp /usr/bin/brave-browser /usr/bin/brave

# Update x-www-browser to use Brave
sed -i 's@exec -a "$0" "$HERE/brave-browser" "$@">@exec -a "$0" "$HERE/brave" "$CHROME_ARGS" "$@"@' /usr/bin/x-www-browser

# Set up Brave policies
mkdir -p /etc/opt/chrome/policies/ /etc/brave/policies/managed
ln -s /etc/opt/chrome/policies /etc/brave/policies
cat > /etc/brave/policies/managed/default_managed_policy.json <<EOL
{"CommandLineFlagSecurityWarningsEnabled": false, "DefaultBrowserSettingEnabled": false}
EOL
cat > /etc/brave/policies/managed/disable_tor.json <<EOL
{"TorDisabled": true}
EOL

# Cleanup
[ -z ${SKIP_CLEAN+x} ] && apt-get autoclean && rm -rf /var/lib/apt/lists/* /var/tmp/*
chown -R 1000:0 $HOME
find /usr/share/ -name "icon-theme.cache" -exec rm -f {} \;
