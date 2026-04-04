import paramiko

HOST = "192.168.8.1"
USERNAME = "root"
PASSWORD = "Lance8995!"

COMMANDS = [
    "uci set dhcp.@dnsmasq[0].filter_aaaa='1'",
    "uci commit dhcp",
    "/etc/init.d/dnsmasq restart >/tmp/dnsmasq-filter-aaaa.log 2>&1",
    "uci -q get dhcp.@dnsmasq[0].filter_aaaa",
    "grep -n 'filter_aaaa' /etc/config/dhcp || true",
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
        stdin, stdout, stderr = client.exec_command("cat /tmp/dnsmasq-filter-aaaa.log 2>/dev/null || true")
        print("DNSMASQ_LOG")
        print(stdout.read().decode("utf-8", "ignore"))
        print(stderr.read().decode("utf-8", "ignore"))
    finally:
        client.close()


if __name__ == "__main__":
    main()
