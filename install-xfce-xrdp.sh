#!/bin/bash
# =============================================================================
# XFCE4 + XRDP Setup Script for Raspbian Bookworm
# Installs: XFCE4 desktop, built-in apps, Xorg, PulseAudio, XRDP
#
# Usage:
#   chmod +x install-xfce-xrdp.sh
#   sudo ./install-xfce-xrdp.sh
#
# After install, connect via any RDP client to: <your-pi-ip>:3389
# Log in with your normal Pi username and password.
# =============================================================================

set -e

# =============================================================================
# HELPERS
# =============================================================================
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${GREEN}========== $1 ==========${NC}"; }

[[ $EUID -ne 0 ]] && error "Please run as root: sudo ./install-xfce-xrdp.sh"

# Keep track of the real user who called sudo (for .xsession setup)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~${REAL_USER}")

# =============================================================================
# STEP 1 — Update system
# =============================================================================
section "Step 1: Updating System"
apt-get update -y
apt-get upgrade -y
info "System updated."

# =============================================================================
# STEP 2 — Install Xorg display server
# =============================================================================
section "Step 2: Installing Xorg"
apt-get install -y \
    xorg \
    xserver-xorg \
    xserver-xorg-core \
    x11-xserver-utils \
    xinit \
    dbus-x11

info "Xorg installed."

# =============================================================================
# STEP 3 — Install XFCE4 desktop + built-in apps
# =============================================================================
section "Step 3: Installing XFCE4 Desktop and Applications"
apt-get install -y \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    xfce4-taskmanager \
    xfce4-power-manager \
    xfce4-screensaver \
    xfce4-notifyd \
    xfce4-whiskermenu-plugin \
    xfce4-clipman-plugin \
    xfce4-weather-plugin \
    xfce4-systemload-plugin \
    xfce4-screenshooter \
    thunar \
    thunar-volman \
    thunar-archive-plugin \
    mousepad \
    ristretto \
    parole \
    gigolo \
    catfish \
    atril \
    engrampa \
    galculator \
    network-manager-gnome \
    nm-tray \
    geany \
    file-roller \
    fonts-dejavu \
    fonts-liberation \
    gnome-icon-theme \
    adwaita-icon-theme

info "XFCE4 and applications installed."

# =============================================================================
# STEP 4 — Install PulseAudio + XFCE4 audio plugin
# =============================================================================
section "Step 4: Installing PulseAudio"
apt-get install -y \
    pulseaudio \
    pulseaudio-utils \
    pavucontrol \
    xfce4-pulseaudio-plugin \
    alsa-utils \
    alsa-base \
    libpulse0

# Add user to audio group
usermod -aG audio "${REAL_USER}" 2>/dev/null || true
info "PulseAudio installed. User '${REAL_USER}' added to audio group."

# =============================================================================
# STEP 5 — Install XRDP
# =============================================================================
section "Step 5: Installing XRDP"
apt-get install -y \
    xrdp \
    xorgxrdp

# Add xrdp user to ssl-cert group (needed to read TLS certs)
usermod -aG ssl-cert xrdp 2>/dev/null || true

info "XRDP installed."

# =============================================================================
# STEP 6 — Configure XRDP to launch XFCE4
# =============================================================================
section "Step 6: Configuring XRDP Session"

# Write .xsession for the real user so XRDP launches XFCE4
cat > "${REAL_HOME}/.xsession" <<'EOF'
#!/bin/sh
# Start PulseAudio for this session
if command -v pulseaudio > /dev/null 2>&1; then
    pulseaudio --start --log-target=syslog 2>/dev/null || true
fi

# Launch XFCE4
exec startxfce4
EOF
chmod +x "${REAL_HOME}/.xsession"
chown "${REAL_USER}:${REAL_USER}" "${REAL_HOME}/.xsession"

# Also write a system-wide Xwrapper config to allow anybody to start X
cat > /etc/X11/Xwrapper.config <<'EOF'
allowed_users=anybody
needs_root_rights=no
EOF

# Tell XRDP which session type to use
sed -i 's/^#\?.*param=-bs.*$//' /etc/xrdp/xrdp.ini 2>/dev/null || true

# Ensure the startwm.sh uses .xsession if present
STARTWM=/etc/xrdp/startwm.sh
if ! grep -q "\.xsession" "${STARTWM}" 2>/dev/null; then
    sed -i '1a\
# Use .xsession if it exists\
if [ -r "$HOME/.xsession" ]; then\
    exec /bin/sh "$HOME/.xsession"\
fi' "${STARTWM}"
fi

info ".xsession configured for user '${REAL_USER}'."

# =============================================================================
# STEP 7 — Configure PulseAudio for XRDP audio redirection (optional)
# =============================================================================
section "Step 7: Configuring PulseAudio for RDP Audio Redirection"

# Install the XRDP PulseAudio module if available
if apt-cache show pulseaudio-module-xrdp > /dev/null 2>&1; then
    apt-get install -y pulseaudio-module-xrdp
    info "pulseaudio-module-xrdp installed — audio will work over RDP."
else
    warn "pulseaudio-module-xrdp not found in repos. Audio over RDP may not work."
    warn "You can try: sudo apt-get install pulseaudio-module-xrdp"
fi

# =============================================================================
# STEP 8 — Enable and start services
# =============================================================================
section "Step 8: Enabling and Starting Services"

systemctl enable xrdp
systemctl restart xrdp

info "XRDP service enabled and started."

# =============================================================================
# STEP 9 — Open firewall port 3389 (if ufw is active)
# =============================================================================
section "Step 9: Firewall"
if command -v ufw > /dev/null 2>&1 && ufw status | grep -q "Status: active"; then
    ufw allow 3389/tcp
    info "UFW: port 3389 (RDP) opened."
else
    info "UFW not active — no firewall changes needed."
fi

# =============================================================================
# STEP 10 — Verify
# =============================================================================
section "Step 10: Verifying Services"
if systemctl is-active --quiet xrdp; then
    info "xrdp is running ✓"
else
    warn "xrdp is NOT running — check: journalctl -u xrdp -n 30"
fi

# =============================================================================
# DONE
# =============================================================================
PI_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  XFCE4 + XRDP Installation Complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "  RDP Address:  ${YELLOW}${PI_IP}:3389${NC}"
echo ""
echo "  Connect using any RDP client:"
echo "    Windows  → Remote Desktop Connection (mstsc)"
echo "    macOS    → Microsoft Remote Desktop (App Store)"
echo "    Linux    → Remmina or FreeRDP"
echo ""
echo "  Login with your Pi username and password."
echo "  User: ${REAL_USER}"
echo ""
echo -e "${YELLOW}  NOTE: A reboot is recommended before connecting.${NC}"
echo -e "  Run: ${GREEN}sudo reboot${NC}"
echo ""
echo "  If audio over RDP doesn't work, ensure your RDP client"
echo "  has 'Play sound on remote computer' enabled."
echo ""
