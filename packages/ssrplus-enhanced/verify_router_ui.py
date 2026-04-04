import json
import requests

BASE = "http://192.168.8.1:8080"
USERNAME = "root"
PASSWORD = "Lance8995!"


def main():
    session = requests.Session()
    session.post(
        BASE + "/cgi-bin/luci",
        data={"luci_username": USERNAME, "luci_password": PASSWORD},
        timeout=15,
    )

    client = session.get(BASE + "/cgi-bin/luci/admin/services/shadowsocksr/client", timeout=15)
    print("CLIENT", client.status_code, client.url)
    for marker in [
        "ssrplus_import_path",
        "ssrplus_action_status",
        "/admin/services/shadowsocksr/export_installer",
        "/admin/services/shadowsocksr/export_full",
        "/admin/services/shadowsocksr/flush",
        "/admin/services/shadowsocksr/import_ss",
    ]:
        print("MARKER", marker, marker in client.text)

    flush = session.get(BASE + "/cgi-bin/luci/admin/services/shadowsocksr/flush", timeout=30)
    print("FLUSH", flush.status_code, flush.headers.get("content-type"))
    print(flush.text[:500])

    imported = session.get(
        BASE + "/cgi-bin/luci/admin/services/shadowsocksr/import_ss",
        params={"path": "/root/ssrplus-txt", "preferred": "HK8 Annual 2"},
        timeout=90,
    )
    print("IMPORT", imported.status_code, imported.headers.get("content-type"))
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


if __name__ == "__main__":
    main()
