#!/bin/bash
# =============================================================================
# Apache Guacamole - Setup Script for Raspbian Bookworm
# Based on the native install guide (guacamole-server built from source,
# Tomcat 9, MariaDB authentication)
#
# Usage:
#   chmod +x install-guacamole.sh
#   sudo ./install-guacamole.sh
#
# After install, access Guacamole at: http://<your-pi-ip>:8080/guacamole
# Default credentials: guacadmin / guacadmin  <-- CHANGE THESE IMMEDIATELY
# =============================================================================

set -e  # Exit on any error

# =============================================================================
# CONFIGURATION — Edit these before running
# =============================================================================
GUAC_VERSION="1.5.5"                   # Guacamole version to install
MYSQL_ROOT_PASS="ChangeMe123!"         # MariaDB root password
GUAC_DB_NAME="guacamole_db"           # Database name
GUAC_DB_USER="guacamole_user"         # Database user
GUAC_DB_PASS="GuacPass456!"           # Database user password
MYSQL_CONNECTOR_VERSION="8.0.33"      # MySQL Connector/J version

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC}  $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
section() { echo -e "\n${GREEN}========== $1 ==========${NC}"; }

# Must be run as root
[[ $EUID -ne 0 ]] && error "Please run this script as root: sudo ./install-guacamole.sh"

# =============================================================================
# STEP 1 — System update
# =============================================================================
section "Step 1: Updating System"
apt-get update -y
apt-get upgrade -y
info "System updated."

# =============================================================================
# STEP 2 — Install build dependencies
# =============================================================================
section "Step 2: Installing Build Dependencies"
apt-get install -y \
    build-essential \
    libcairo2-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libtool-bin \
    libossp-uuid-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    freerdp2-dev \
    libpango1.0-dev \
    libssh2-1-dev \
    libvncserver-dev \
    libtelnet-dev \
    libssl-dev \
    libvorbis-dev \
    libwebp-dev \
    libpulse-dev \
    libwebsockets-dev \
    ghostscript \
    wget \
    curl \
    tar \
    make \
    gcc \
    autoconf \
    automake \
    libtool

info "Build dependencies installed."

# =============================================================================
# STEP 3 — Install Java & Tomcat 9
# =============================================================================
section "Step 3: Installing Java and Tomcat 9"
apt-get install -y default-jdk tomcat9 tomcat9-admin tomcat9-common tomcat9-user
systemctl enable tomcat9
systemctl start tomcat9
info "Tomcat 9 installed and started."

# =============================================================================
# STEP 4 — Build guacamole-server from source
# =============================================================================
section "Step 4: Building guacamole-server v${GUAC_VERSION} from Source"
cd /usr/local/src

info "Downloading guacamole-server source..."
wget -q "https://downloads.apache.org/guacamole/${GUAC_VERSION}/source/guacamole-server-${GUAC_VERSION}.tar.gz" \
    || error "Failed to download guacamole-server. Check version number or your internet connection."

tar -xzf "guacamole-server-${GUAC_VERSION}.tar.gz"
cd "guacamole-server-${GUAC_VERSION}"

info "Configuring build..."
autoreconf -fi
./configure --with-init-dir=/etc/init.d 2>&1 | tail -20

info "Compiling (this may take 10–20 minutes on a Pi)..."
make -j$(nproc)
make install
ldconfig

info "Enabling and starting guacd service..."
systemctl daemon-reload
systemctl enable guacd
systemctl start guacd

info "guacamole-server built and guacd started."

# =============================================================================
# STEP 5 — Deploy guacamole-client (.war file)
# =============================================================================
section "Step 5: Deploying Guacamole Web Application"
mkdir -p /etc/guacamole/extensions /etc/guacamole/lib

info "Downloading guacamole.war..."
wget -q "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war" \
    -O /var/lib/tomcat9/webapps/guacamole.war \
    || error "Failed to download guacamole.war."

# Link Guacamole config dir into Tomcat's home
ln -sf /etc/guacamole /usr/share/tomcat9/.guacamole

info "Guacamole .war deployed."

# =============================================================================
# STEP 6 — Install & configure MariaDB
# =============================================================================
section "Step 6: Installing and Configuring MariaDB"
apt-get install -y mariadb-server mariadb-client
systemctl enable mariadb
systemctl start mariadb

info "Securing MariaDB and creating Guacamole database..."
mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASS}';
CREATE DATABASE IF NOT EXISTS ${GUAC_DB_NAME} CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER IF NOT EXISTS '${GUAC_DB_USER}'@'localhost' IDENTIFIED BY '${GUAC_DB_PASS}';
GRANT SELECT, INSERT, UPDATE, DELETE ON ${GUAC_DB_NAME}.* TO '${GUAC_DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

info "MariaDB configured."

# =============================================================================
# STEP 7 — Download and install JDBC auth extension
# =============================================================================
section "Step 7: Installing JDBC Authentication Extension"
cd /usr/local/src

info "Downloading guacamole-auth-jdbc..."
wget -q "https://downloads.apache.org/guacamole/${GUAC_VERSION}/binary/guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz" \
    || error "Failed to download guacamole-auth-jdbc."

tar -xzf "guacamole-auth-jdbc-${GUAC_VERSION}.tar.gz"
cp "guacamole-auth-jdbc-${GUAC_VERSION}/mysql/guacamole-auth-jdbc-mysql-${GUAC_VERSION}.jar" \
    /etc/guacamole/extensions/

info "Populating database schema..."
cat "guacamole-auth-jdbc-${GUAC_VERSION}/mysql/schema/"*.sql \
    | mysql -u root -p"${MYSQL_ROOT_PASS}" "${GUAC_DB_NAME}"

info "JDBC extension installed and database schema loaded."

# =============================================================================
# STEP 8 — Download and install MySQL Connector/J
# =============================================================================
section "Step 8: Installing MySQL Connector/J"
cd /usr/local/src

info "Downloading MySQL Connector/J ${MYSQL_CONNECTOR_VERSION}..."
wget -q "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz" \
    || error "Failed to download MySQL Connector/J."

tar -xzf "mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.tar.gz"
cp "mysql-connector-j-${MYSQL_CONNECTOR_VERSION}/mysql-connector-j-${MYSQL_CONNECTOR_VERSION}.jar" \
    /etc/guacamole/lib/

info "MySQL Connector/J installed."

# =============================================================================
# STEP 9 — Write guacamole.properties
# =============================================================================
section "Step 9: Writing Guacamole Configuration"
cat > /etc/guacamole/guacamole.properties <<EOF
# Guacamole proxy settings
guacd-hostname: localhost
guacd-port:     4822

# MariaDB / MySQL authentication
mysql-hostname:  localhost
mysql-port:      3306
mysql-database:  ${GUAC_DB_NAME}
mysql-username:  ${GUAC_DB_USER}
mysql-password:  ${GUAC_DB_PASS}
EOF

# Set GUACAMOLE_HOME so Tomcat can find the config
echo "GUACAMOLE_HOME=/etc/guacamole" >> /etc/default/tomcat9

info "Configuration written to /etc/guacamole/guacamole.properties"

# =============================================================================
# STEP 10 — Restart services
# =============================================================================
section "Step 10: Restarting Services"
systemctl restart guacd
systemctl restart tomcat9

# Give Tomcat time to deploy the .war
info "Waiting 15 seconds for Tomcat to deploy the application..."
sleep 15

# =============================================================================
# STEP 11 — Verify services are running
# =============================================================================
section "Step 11: Verifying Services"

check_service() {
    if systemctl is-active --quiet "$1"; then
        info "$1 is running ✓"
    else
        warn "$1 is NOT running — check: journalctl -u $1"
    fi
}

check_service guacd
check_service tomcat9
check_service mariadb

# =============================================================================
# DONE
# =============================================================================
PI_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Apache Guacamole Installation Complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "  Access URL:  ${YELLOW}http://${PI_IP}:8080/guacamole${NC}"
echo ""
echo -e "  Default login:   guacadmin"
echo -e "  Default password: guacadmin"
echo ""
echo -e "${RED}  !! IMPORTANT: Change the default guacadmin password immediately !!${NC}"
echo ""
echo "  If the page doesn't load right away, wait 30 seconds and try again."
echo "  Logs: journalctl -u tomcat9 -f"
echo ""
echo "  Next steps:"
echo "    1. Log in and change the guacadmin password"
echo "    2. Create a new admin user, then delete guacadmin"
echo "    3. Add your remote desktop connections (RDP, VNC, SSH)"
echo "    4. (Optional) Set up Nginx as a reverse proxy with SSL"
echo ""
