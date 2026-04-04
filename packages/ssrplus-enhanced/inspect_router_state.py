import requests
import paramiko

HOST = "192.168.8.1"
BASE = "http://192.168.8.1:8080"
USER = "root"
PWD = "Lance8995!"


def p(*args):
    print(*args, flush=True)


def main():
    s = requests.Session()
    r = s.post(
        BASE + "/cgi-bin/luci",
        data={"luci_username": USER, "luci_password": PWD},
        timeout=20,
        allow_redirects=True,
    )
    p("LOGIN", r.status_code, r.url)

    for path in [
        "/cgi-bin/luci/admin/services/shadowsocksr/status_info",
        "/cgi-bin/luci/admin/services/shadowsocksr/run",
    ]:
        resp = s.get(BASE + path, timeout=20)
        p("\nHTTP", path, resp.status_code)
        p(resp.text[:1000])

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, username=USER, password=PWD, timeout=20)

    base_cmds = [
        "uci -q get shadowsocksr.@global[0].global_server",
        "uci -q get shadowsocksr.@global[0].threads",
        "uci -q get shadowsocksr.@global[0].run_mode",
        "uci -q get shadowsocksr.@global[0].dports",
        "uci -q get shadowsocksr.@global[0].pdnsd_enable",
        "uci -q get shadowsocksr.@access_control[0].router_proxy",
        "uci -q get shadowsocksr.@access_control[0].lan_ac_mode",
        "uci -q get shadowsocksr.@access_control[0].lan_ac_ips",
        "uci -q get shadowsocksr.@access_control[0].lan_bp_ips",
        "cat /tmp/ssrplus-action-status.json 2>/dev/null || true",
        "busybox ps -w | grep -E 'ss-redir|sslocal|obfs-local|dns2tcp|dns2socks|chinadns-ng|ssr-switch' | grep -v grep || true",
        "grep -n \"Main node\\|Threads Started\\|Killed process\\|Out of memory\" /var/log/ssrplus.log 2>/dev/null | tail -n 80",
        "logread | grep -E 'shadowsocksr|ss-redir|Out of memory|Killed process|Threads Started' | tail -n 120",
    ]

    for cmd in base_cmds:
        stdin, stdout, stderr = c.exec_command(cmd)
        out = stdout.read().decode("utf-8", "ignore")
        err = stderr.read().decode("utf-8", "ignore")
        p("\nCMD>", cmd)
        p(out[:4000])
        if err:
            p("ERR>", err[:800])

    stdin, stdout, stderr = c.exec_command("uci -q get shadowsocksr.@global[0].global_server")
    active = stdout.read().decode("utf-8", "ignore").strip()
    p("\nACTIVE_SECTION", active)

    if active and active != "nil":
        cmds = [
            f"uci -q show shadowsocksr.{active}",
            "cat /var/etc/ssrplus/tcp-udp-ssr-retcp.json 2>/dev/null || true",
            f"nslookup $(uci -q get shadowsocksr.{active}.server) 127.0.0.1 2>/dev/null || true",
            f"nslookup $(uci -q get shadowsocksr.{active}.server) 119.29.29.29 2>/dev/null || true",
            f"tcping -q -c 1 -i 1 -t 2 -p $(uci -q get shadowsocksr.{active}.server_port) $(uci -q get shadowsocksr.{active}.server) 2>/dev/null || true",
            f"ping -c 1 -W 1 $(uci -q get shadowsocksr.{active}.server) 2>/dev/null || true",
            "curl -4 -m 8 -fsSL https://api.ip.sb/ip 2>/dev/null || true",
        ]
        for cmd in cmds:
            stdin, stdout, stderr = c.exec_command(cmd)
            out = stdout.read().decode("utf-8", "ignore")
            err = stderr.read().decode("utf-8", "ignore")
            p("\nCMD>", cmd)
            p(out[:4000])
            if err:
                p("ERR>", err[:800])

    for idx, alias in enumerate(["US America", "HK 2", "HK Premium 2", "JP VIP2"], start=1):
        stdin, stdout, stderr = c.exec_command(
            f"uci -q show shadowsocksr | grep \"alias='{alias}'\" | head -n 1"
        )
        line = stdout.read().decode("utf-8", "ignore").strip()
        p("\nALIAS_LOOKUP", alias, line)
        if not line:
            continue
        section = line.split(".")[1].split("=")[0]
        stdin, stdout, stderr = c.exec_command(
            f"sh -lc \"echo $(uci -q get shadowsocksr.{section}.server) $(uci -q get shadowsocksr.{section}.server_port)\""
        )
        sp = stdout.read().decode("utf-8", "ignore").strip().split()
        if len(sp) < 2:
            continue
        server, port = sp[0], sp[1]
        resp = s.get(
            BASE + "/cgi-bin/luci/admin/services/shadowsocksr/ping",
            params={"index": str(idx), "domain": server, "port": port},
            timeout=20,
        )
        p("PING_API", alias, resp.status_code, resp.text)

    c.close()


if __name__ == "__main__":
    main()
