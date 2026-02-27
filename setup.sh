#!/bin/bash

set -e

echo "Refreshing..."

sudo apt update

echo "Basics..."

sudo apt -y install xfce4 xfce4-goodies xorg pulseaudio
sudo apt -y install firefox-esr network-manager wget git ssh

echo "Networking..."

sudo systemctl stop networking
sudo systemctl disable networking

sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager

echo "Libs..."

sudo apt -y install libcairo2-dev libjpeg62-turbo-dev libpng-dev libtool-bin xrdp xorgxrdp libavcodec-dev libavformat-dev libavutil-dev libswscale-dev uuid-dev freerdp2-dev libpango1.0-dev libssh2-1-dev libtelnet-dev libwebsockets-dev libssl-dev libvorbis-dev libwebp-dev build-essential gcc

echo "Tomcat9"

sudo apt install -y openjdk-17-jdk

sudo wget https://maven.xwiki.org/xwiki-keyring.gpg -O /usr/share/keyrings/xwiki-keyring.gpg
sudo wget "https://maven.xwiki.org/stable/xwiki-stable.list" -O /etc/apt/sources.list.d/xwiki-stable.list

sudo apt-get update

sudo apt install -y mariadb-server mariadb-client

sudo apt install xwiki-tomcat9-mariadb xwiki-mariadb-common xwiki-tomcat9-common

echo "You can remove this repo later if you want."

sleep 2

echo "Getting guacamole!"

wget https://apache.org/dyn/closer.lua/guacamole/1.6.0/binary/guacamole-1.6.0.war

sudo systemctl enable tomcat9

tar -xzf guacamole-server-1.6.0.tar.gz
cd guacamole-server-1.6.0/

./configure --with-systemd-dir=/usr/local/lib/systemd/system

echo "Building and installing guacamole!"

make

sudo make install

echo "MariaDB"

sudo mariadb-secure-installation

cat schema/*.sql | mysql -u root -p guacamole_db

wget https://apache.org/dyn/closer.lua/guacamole/1.6.0/binary/guacamole-auth-jdbc-1.6.0.tar.gz

wget https://mariadb.com/downloads/connectors/connectors-data-access/java8-connector

echo "Manually execute these in MariaDB client"

echo "CREATE DATABASE guacamole_db;"
echo "
CREATE USER 'guacamole_user' IDENTIFIED BY 'some_password';
GRANT SELECT,INSERT,UPDATE,DELETE ON guacamole_db.* TO 'guacamole_user';
FLUSH PRIVILEGES;

Native installations of Guacamole under Apache Tomcat or similar are configured by modifying the contents of GUACAMOLE_HOME (Guacamole’s configuration directory), which is located at /etc/guacamole by default and may need to be created first:

    You should have a copy of guacamole-auth-jdbc-1.6.0.tar.gz from earlier when you created and initialized the database.

    Create the GUACAMOLE_HOME/extensions and GUACAMOLE_HOME/lib directories, if they do not already exist.

    Copy mysql/guacamole-auth-jdbc-mysql-1.6.0.jar within GUACAMOLE_HOME/extensions.

    Copy the JDBC driver for your database to GUACAMOLE_HOME/lib. Either of the following MySQL-compatible JDBC drivers are supported for connecting Guacamole with MariaDB or MySQL:

        MariaDB Connector/J

        MySQL Connector/J (the required .jar will be within a .tar.gz archive)

    If you do not have a specific reason to use one driver over the other, it’s recommended that you use the JDBC driver provided by your database vendor.

    Configure Guacamole to use database authentication, as described below.

Add this to guacamole.properties

mysql-database: guacamole_db
mysql-username: guacamole_user
mysql-password: some_password


"

