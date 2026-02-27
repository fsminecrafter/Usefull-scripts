import socket
import smtplib
import ssl

FROM = "minecrafterjoel100@gmail.com"
TO = ["minecrafterjoel100@gmail.com"]
SUBJECT = "IP change"
APP_PASSWORD = "jomjliegpfryubbd"

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Use a dummy address — doesn't have to be reachable
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    finally:
        s.close()
    return ip

def send_email(text):
    message = f"""From: {FROM}
To: {", ".join(TO)}
Subject: {SUBJECT}

{text}
"""

    context = ssl.create_default_context()

    with smtplib.SMTP_SSL("smtp.gmail.com", 465, context=context) as server:
        server.login(FROM, APP_PASSWORD)
        server.sendmail(FROM, TO, message)


initialIP = get_local_ip()
CurrentIP = initialIP
StoredIP = initialIP

apppassword = "jomj lieg pfry ubbd"

if __name__ == "__main__":
	print(f"Initial IP: {initialIP}")
	text = f"Initial startup IP of Lepotato Arm64 is: {initialIP}"
	send_email(text)
	while True:
		try:
			CurrentIP = get_local_ip()
			if CurrentIP != StoredIP:
    				print("IP changed")
    				StoredIP = CurrentIP
    				text = f"The IP of Lepotato Arm64 computer has changed! {CurrentIP}"
    				send_email(text)
		except Exception as e:
			print(f"An error has appeared: {e}")
