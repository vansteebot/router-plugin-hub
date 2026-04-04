import paramiko

HOST = "192.168.8.1"
USER = "root"
PWD = "Lance8995!"

TARGETS = [
    ("node-hkcn2.hkss.online", "1634"),
    ("kagoya.hkss.online", "1634"),
    ("node-hktous2.hkss.online", "1634"),
    ("tw-hinet1.hkss.online", "1634"),
    ("sgp-1.hkss.online", "1634"),
    ("hkp-1.hkss.online", "1634"),
]


def main():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USER, password=PWD, timeout=20)

    for host, port in TARGETS:
        print(f"\n=== {host}:{port} ===", flush=True)
        for cmd in [
            f"nslookup {host} 127.0.0.1 2>/dev/null || true",
            f"tcping -q -c 1 -i 1 -t 2 -p {port} {host} 2>/dev/null || true",
            f"tcping -q -c 1 -i 1 -t 2 -p {port} {host} 2>/dev/null | grep -o 'time=[0-9]*' | awk -F '=' '{{print $2}}' || true",
            f"ping -c 1 -W 1 {host} 2>/dev/null || true",
            f"ping -c 1 -W 1 {host} 2>/dev/null | grep -o 'time=[0-9]*' | awk -F '=' '{{print $2}}' || true",
        ]:
            stdin, stdout, stderr = client.exec_command(cmd)
            out = stdout.read().decode("utf-8", "ignore")
            err = stderr.read().decode("utf-8", "ignore")
            print("CMD>", cmd, flush=True)
            print(out[:2000], flush=True)
            if err:
                print("ERR>", err[:500], flush=True)

    client.close()


if __name__ == "__main__":
    main()
