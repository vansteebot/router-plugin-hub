import pathlib
import time
import paramiko
import requests

HOST = "192.168.8.1"
BASE = "http://192.168.8.1:8080"
USERNAME = "root"
PASSWORD = "Lance8995!"

ROOT = pathlib.Path(__file__).resolve().parent
INSTALLER = ROOT / "ssrplus-enhanced-installer.run"
TXT_FILE = pathlib.Path(r"C:\Users\Admin\订阅链接.txt")


def upload_and_install():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USERNAME, password=PASSWORD, timeout=15)
    sftp = client.open_sftp()
    try:
        try:
            sftp.mkdir("/root/ssrplus-txt")
        except OSError:
            pass
        sftp.put(str(INSTALLER), "/tmp/ssrplus-enhanced-installer.run")
        sftp.chmod("/tmp/ssrplus-enhanced-installer.run", 0o755)
        sftp.put(str(TXT_FILE), "/root/ssrplus-txt/hkss.txt")
        stdin, stdout, stderr = client.exec_command("sh /tmp/ssrplus-enhanced-installer.run")
        out = stdout.read().decode("utf-8", "ignore")
        err = stderr.read().decode("utf-8", "ignore")
        print("INSTALL_OUT")
        print(out)
        print("INSTALL_ERR")
        print(err)
    finally:
        sftp.close()
        client.close()


def verify_http():
    session = requests.Session()
    session.post(
        BASE + "/cgi-bin/luci",
        data={"luci_username": USERNAME, "luci_password": PASSWORD},
        timeout=15,
    )
    client = session.get(BASE + "/cgi-bin/luci/admin/services/shadowsocksr/client", timeout=15)
    print("CLIENT", client.status_code, client.url)
    for marker in [
        "ssrplus_action_status",
        "/admin/services/shadowsocksr/status_info",
        "/admin/services/shadowsocksr/export_installer",
        "/admin/services/shadowsocksr/export_full",
        "/admin/services/shadowsocksr/export_windows_recover",
        "/admin/services/shadowsocksr/flush",
    ]:
        print("MARKER", marker, marker in client.text)

    status_info = session.get(BASE + "/cgi-bin/luci/admin/services/shadowsocksr/status_info", timeout=30)
    print("STATUS_INFO", status_info.status_code, status_info.headers.get("content-type"))
    print(status_info.text[:500])

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(HOST, username=USERNAME, password=PASSWORD, timeout=15)
    try:
        for command in [
            "uci -q get shadowsocksr.@global[0].run_mode",
            "uci -q get shadowsocksr.@global[0].dports",
            "uci -q get shadowsocksr.@global[0].threads",
            "uci -q get shadowsocksr.@global[0].enable_switch",
            "uci -q get shadowsocksr.@access_control[0].router_proxy",
            "uci -q get dhcp.@dnsmasq[0].filter_aaaa",
        ]:
            stdin, stdout, stderr = client.exec_command(command)
            print("VERIFY", command, "=>", stdout.read().decode("utf-8", "ignore").strip())
    finally:
        client.close()

    servers = session.get(BASE + "/cgi-bin/luci/admin/services/shadowsocksr/servers", timeout=15)
    print("SERVERS", servers.status_code, servers.url)
    for marker in [
        "ssrplus_bulk_path",
        "ssrplus_bulk_payload",
        "ssrplus_server_import_status",
        "/admin/services/shadowsocksr/import_ss",
        "ssrplus_ping_run",
        "ssrplus_ping_stop",
        "ssrplus_ping_status",
        "可连通",
    ]:
        print("SERVER_MARKER", marker, marker in servers.text)

    try:
        started = time.perf_counter()
        flush = session.get(BASE + "/cgi-bin/luci/admin/services/shadowsocksr/flush", timeout=90)
        print("FLUSH_DEEP", flush.status_code, flush.headers.get("content-type"), round(time.perf_counter() - started, 2))
        print(flush.text[:500])
    except Exception as exc:
        print("FLUSH_DEEP_ERROR", exc)

    started = time.perf_counter()
    imported = session.get(
        BASE + "/cgi-bin/luci/admin/services/shadowsocksr/import_ss",
        params={"path": "/root/ssrplus-txt", "preferred": "HK8 Annual 2"},
        timeout=90,
    )
    print("IMPORT", imported.status_code, imported.headers.get("content-type"), round(time.perf_counter() - started, 2))
    print(imported.text[:800])

    installer = session.get(
        BASE + "/cgi-bin/luci/admin/services/shadowsocksr/export_installer",
        timeout=30,
        stream=True,
    )
    print("INSTALLER", installer.status_code, installer.headers.get("content-type"))
    first_chunk = next(installer.iter_content(128), b"")
    print("INSTALLER_BYTES", len(first_chunk), first_chunk[:32])

    backup = session.get(
        BASE + "/cgi-bin/luci/admin/services/shadowsocksr/export_full",
        timeout=30,
        stream=True,
    )
    print("BACKUP", backup.status_code, backup.headers.get("content-type"))
    backup_chunk = next(backup.iter_content(128), b"")
    print("BACKUP_BYTES", len(backup_chunk), backup_chunk[:32])

    recover = session.get(
        BASE + "/cgi-bin/luci/admin/services/shadowsocksr/export_windows_recover",
        timeout=30,
        stream=True,
    )
    print("WINDOWS_RECOVER", recover.status_code, recover.headers.get("content-type"))
    recover_chunk = next(recover.iter_content(128), b"")
    print("WINDOWS_RECOVER_BYTES", len(recover_chunk), recover_chunk[:64])


if __name__ == "__main__":
    upload_and_install()
    verify_http()
