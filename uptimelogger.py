#!/usr/bin/env python3
import os
import time
import datetime

CONFIG_FILE = "uptimelogger.conf"
LOG_FILE = "UptimeLog.log"

def load_config():
	config = {
		"EraseAfter": 10,
		"EraseAmountLimit": 250,
		"EraseAmount": 10
		}
	if os.path.exists(CONFIG_FILE):
		with open(CONFIG_FILE) as f:
			for line  in f:
				line = line.strip()
				if not line or line.startswith("#"):
					continue
				key, val = line.split("=")
				config[key.strip()] = int(val.strip())
	return config

def get_uptime_seconds():
	if os.path.exists("/proc/uptime"):
		with open("/proc/uptime") as f:
			return float(f.read().split()[0])
	try:
		import psutil
		return time.time() - psutil.boot_time()
	except ImportError:
		raise RuntimeError("Psutil required on this system!")

def format_uptime(seconds):
	days=int(seconds // 86400)
	seconds %= 86400
	hours = int(seconds // 3600)
	seconds %= 3600
	minutes = int(seconds // 60)
	seconds = int(seconds % 60)

	return f"{days}d {hours}h {minutes}m {seconds}s"

def log_boot_marker():
	now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
	with open(LOG_FILE, "a") as f:
		f.write(f"\n=== BOOT @ {now} ===\n")

def cleanup_logs(config):
	if not os.path.exists(LOG_FILE):
		return
	with open(LOG_FILE, "r") as f:
		lines = f.readlines()

	cutoff = datetime.datetime.now() - datetime.timedelta(days=config["EraseAfter"])
	new_lines = []

	for line in lines:
		try:
			timestamp = line[:19]
			dt = datetime.datetime.strptime(timestamp, "%Y-%m-%d %H:%M:%S")
			if dt >= cutoff:
				new_lines.append(line)
		except:
			new_lines.append(line)
	lines = new_lines

	if len(lines) > config["EraseAmountLimit"]:
		lines = lines[config["EraseAmount"]:]

	with open(LOG_FILE, "w") as f:
		f.writelines(lines)

def main():
	config = load_config()
	log_boot_marker()
	while True:
		uptime_sec = get_uptime_seconds()
		uptime_str = format_uptime(uptime_sec)

		now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
		line = f"{now} | Uptime: {uptime_str}"

		print(line)

		with open(LOG_FILE, "a") as f:
			f.write(line + "\n")

		cleanup_logs(config)

		time.sleep(2)

if __name__ == "__main__":

	main()
