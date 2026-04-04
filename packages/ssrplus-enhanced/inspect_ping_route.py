import paramiko


HOST = "192.168.8.1"
USER = "root"
PASSWORD = "Lance8995!"


COMMAND = r"""
grep -n "admin/services/shadowsocksr/ping\|function ping\|function act_ping\|call(\"ping\")" /usr/lib/lua/luci/controller/shadowsocksr.lua 2>/dev/null
echo ---
sed -n '1,260p' /usr/lib/lua/luci/controller/shadowsocksr.lua 2>/dev/null
"""


def main():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USER, password=PASSWORD, timeout=10)
    try:
        _, stdout, stderr = client.exec_command(COMMAND)
        print(stdout.read().decode("utf-8", "ignore"))
        err = stderr.read().decode("utf-8", "ignore")
        if err:
            print("STDERR:")
            print(err)
    finally:
        client.close()


if __name__ == "__main__":
    main()
