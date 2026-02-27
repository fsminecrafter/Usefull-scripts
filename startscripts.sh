#!/bin/bash
set -e

HOST="8.8.8.8"

while ! ping -c 1 -W 1 "$HOST" >/dev/null 2>&1; do
	echo "Waiting for network"
	sleep 1
done

cd /home/fsminecrafter/

python3 IPmailer.py &
echo IPmailer has started
python3 uptimelogger.py &
echo UptimeLogger has started
cd /home/fsminecrafter/CodeIt
python3 luanch.py &
echo CodeIt has started

echo All scripts are started!

wait
