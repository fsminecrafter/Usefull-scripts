#!/usr/bin/bash

set -e 

cat schema/*.sql | mysql -u root -p guacamole_db

