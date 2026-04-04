import paramiko

HOST = "192.168.8.1"
USERNAME = "root"
PASSWORD = "Lance8995!"

COMMANDS = [
    "dnsmasq --help 2>/dev/null | grep -i AAAA || true",
    "uci -q show network | grep -E 'ip6|dhcpv6|ra|delegate|ula|dns' || true",
    "uci -q show dhcp | grep -E 'ra|dhcpv6|filter_aaaa|dns' || true",
    "ip -6 addr show br-lan || true",
    "ip -6 route || true",
    "nslookup www.google.com 127.0.0.1#5335 2>/dev/null || true",
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
