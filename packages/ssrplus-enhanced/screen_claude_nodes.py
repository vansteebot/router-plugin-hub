import json
import re
import time
from pathlib import Path

import paramiko

HOST = '192.168.8.1'
USER = 'root'
PASSWORD = 'Lance8995!'
OUT_PATH = Path(r'C:\Users\Admin\ssrplus_router_mod\screen_claude_nodes_results.json')


def ssh_exec(client, cmd, timeout=40):
    stdin, stdout, stderr = client.exec_command(cmd, timeout=timeout)
    return stdout.read().decode('utf-8', 'ignore'), stderr.read().decode('utf-8', 'ignore')


def get_uci(client, key):
    out, _ = ssh_exec(client, f"uci -q get {key}")
    return out.strip()


def main():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USER, password=PASSWORD, timeout=15)
    sftp = client.open_sftp()
    try:
        out, _ = ssh_exec(client, "uci show shadowsocksr | grep '=servers'")
        sections = []
        for line in out.splitlines():
            sec = line.split('=')[0].split('.')[-1]
            if sec and sec not in sections:
                sections.append(sec)

        results = []
        base_port = 19080
        for idx, sec in enumerate(sections):
            alias = get_uci(client, f'shadowsocksr.{sec}.alias')
            server = get_uci(client, f'shadowsocksr.{sec}.server')
            server_port = get_uci(client, f'shadowsocksr.{sec}.server_port')
            password = get_uci(client, f'shadowsocksr.{sec}.password')
            method = get_uci(client, f'shadowsocksr.{sec}.encrypt_method_ss')
            plugin = get_uci(client, f'shadowsocksr.{sec}.plugin')
            plugin_opts = get_uci(client, f'shadowsocksr.{sec}.plugin_opts')
            port = base_port + idx
            cfg = {
                'server': server,
                'server_port': int(server_port),
                'password': password,
                'method': method,
                'plugin': plugin,
                'plugin_opts': plugin_opts,
                'local_address': '127.0.0.1',
                'local_port': port,
            }
            cfg_path = f'/tmp/ssrprobe-{sec}.json'
            log_path = f'/tmp/ssrprobe-{sec}.log'
            pid_path = f'/tmp/ssrprobe-{sec}.pid'
            res = {
                'section': sec,
                'alias': alias,
                'server': server,
                'server_port': server_port,
                'ok': False,
            }
            try:
                with sftp.open(cfg_path, 'w') as fp:
                    fp.write(json.dumps(cfg))
                ssh_exec(client, f"rm -f {log_path} {pid_path}; /usr/bin/sslocal -c {cfg_path} >{log_path} 2>&1 & echo $! > {pid_path}; sleep 2", timeout=10)
                geo_out, geo_err = ssh_exec(client, f"curl --socks5-hostname 127.0.0.1:{port} -4 -sS --max-time 20 https://api.ip.sb/geoip", timeout=30)
                claude_out, claude_err = ssh_exec(client, f"curl --socks5-hostname 127.0.0.1:{port} -4 -L -sS --max-time 25 https://claude.com", timeout=35)
                if geo_out.strip().startswith('{'):
                    geo = json.loads(geo_out.strip())
                    res['ok'] = True
                    res['exit_ip'] = geo.get('ip', '')
                    res['country'] = geo.get('country', '')
                    res['country_code'] = geo.get('country_code', '')
                    res['region'] = geo.get('region', '')
                    res['city'] = geo.get('city', '')
                    res['org'] = geo.get('organization', '') or geo.get('isp', '')
                    res['asn_org'] = geo.get('asn_organization', '')
                    res['asn'] = geo.get('asn', '')
                else:
                    res['geo_error'] = (geo_err or geo_out)[:400]

                body = claude_out or ''
                if 'app-unavailable-in-region' in body or 'Application unavailable' in body or '应用程序不可用' in body:
                    res['claude_status'] = 'region_block'
                elif 'Just a moment' in body:
                    res['claude_status'] = 'cloudflare_challenge'
                elif 'Log in to Claude' in body or 'Try Claude' in body or 'data-cf-country=' in body:
                    res['claude_status'] = 'homepage_ok'
                    m = re.search(r'data-cf-country="([A-Z]{2})"', body)
                    if m:
                        res['claude_cf_country'] = m.group(1)
                elif body.strip():
                    res['claude_status'] = 'unknown_response'
                    res['claude_head'] = body[:240]
                else:
                    res['claude_status'] = 'request_failed'
                    res['claude_error'] = claude_err[:300]

                log_out, _ = ssh_exec(client, f"tail -n 12 {log_path}", timeout=10)
                if log_out.strip():
                    res['log_tail'] = log_out[-500:]
            finally:
                ssh_exec(client, f"[ -f {pid_path} ] && kill $(cat {pid_path}) 2>/dev/null || true; rm -f {cfg_path} {pid_path}", timeout=10)
                ssh_exec(client, f"pkill -f '/tmp/ssrprobe-{sec}.json' 2>/dev/null || true", timeout=10)
            results.append(res)
            print(f"{alias}: {res.get('exit_ip','-')} {res.get('country_code','-')} {res.get('org','-')} {res.get('claude_status','-')}")

        OUT_PATH.write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
        print(f'\nsaved {OUT_PATH}')
    finally:
        try:
            sftp.close()
        except Exception:
            pass
        client.close()


if __name__ == '__main__':
    main()
