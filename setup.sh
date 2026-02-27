#!usr/bin/bash

set -e

echo "Refreshing..."

sudo apt update

echo "Basics..."

sudo apt -y install xfce4 xfce4-goodies xorg pulseaudio
sudo apt -y install firefox-esr network-manager wget git

echo "Networking..."

sudo systemctl stop networking
sudo systemctl disable networking

sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

echo "Libs..."

sudo apt -y install libcairo2-dev libjpeg62-turbo-dev libpng-dev libtool-bin xrdp xrdp-xorg libavcodec-dev libavformat-dev libavutil-dev libswscale-dev uuid-dev freerdp2-dev lib pango1.0-dev libssh2-1-dev libtelnet-dev libwebsockets-dev libssl-dev libvorbis-dev libwebp-dev

echo "Getting guacamole!"

wget https://apache.org/dyn/closer.lua/guacamole/1.6.0/binary/guacamole-1.6.0.war?action=download

tar -xzf guacamole-server-1.6.0.tar.gz
cd guacamole-server-1.6.0/

./configure --with-systemd-dir=/usr/local/lib/systemd/system

echo "Building and installing guacamole!"

make

sudo make install

echo "MariaDB"

sudo apt install -y mariadb-server mariadb-client

echo "Manually execute these in MariaDB client"

echo "CREATE DATABASE guacamole_db;"
echo "Then run the part 2 of this script"
