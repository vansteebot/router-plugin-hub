import paramiko

HOST = "192.168.8.1"
USERNAME = "root"
PASSWORD = "Lance8995!"

COMMANDS = [
    "sed -n '1,260p' /etc/init.d/shadowsocksr | head -n 260",
    "START=$(date +%s); /etc/init.d/shadowsocksr restart >/tmp/ssr-restart-probe.log 2>&1; END=$(date +%s); echo DURATION=$((END-START)); cat /tmp/ssr-restart-probe.log",
    "START=$(date +%s); killall -HUP dnsmasq >/dev/null 2>&1 || true; END=$(date +%s); echo DNSMASQ_HUP=$((END-START))",
]


def main():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USERNAME, password=PASSWORD, timeout=15)
    try:
        for command in COMMANDS:
            print("CMD>", command)
            stdin, stdout, stderr = client.exec_command(command)
            print(stdout.read().decode("utf-8", "ignore"))
            print(stderr.read().decode("utf-8", "ignore"))
    finally:
        client.close()


if __name__ == "__main__":
    main()
