#!/usr/bin/env python3
import argparse
import json
import mimetypes
import os
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def api_request(url, token, method="GET", data=None, extra_headers=None):
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "router-plugin-hub-release-publisher",
    }
    if extra_headers:
        headers.update(extra_headers)
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def ensure_release(owner, repo, tag, title, body, token):
    lookup_url = f"https://api.github.com/repos/{owner}/{repo}/releases/tags/{tag}"
    try:
        release = api_request(lookup_url, token)
        print(f"existing_release {release['html_url']}")
        return release
    except urllib.error.HTTPError as exc:
        if exc.code != 404:
            raise
    payload = json.dumps(
        {
            "tag_name": tag,
            "target_commitish": "main",
            "name": title,
            "body": body,
            "draft": False,
            "prerelease": False,
        }
    ).encode("utf-8")
    release = api_request(
        f"https://api.github.com/repos/{owner}/{repo}/releases",
        token,
        method="POST",
        data=payload,
        extra_headers={"Content-Type": "application/json"},
    )
    print(f"created_release {release['html_url']}")
    return release


def upload_assets(release, assets, token):
    upload_url = release["upload_url"].split("{", 1)[0]
    existing = {asset["name"] for asset in release.get("assets", [])}
    for asset in assets:
        if not asset.exists():
            print(f"missing_asset {asset}")
            continue
        if asset.name in existing:
            print(f"asset_exists {asset.name}")
            continue
        content = asset.read_bytes()
        content_type = mimetypes.guess_type(asset.name)[0] or "application/octet-stream"
        query = urllib.parse.urlencode({"name": asset.name})
        uploaded = api_request(
            upload_url + "?" + query,
            token,
            method="POST",
            data=content,
            extra_headers={"Content-Type": content_type},
        )
        print(f"uploaded {uploaded['name']} {uploaded['browser_download_url']}")


def main():
    parser = argparse.ArgumentParser(description="Publish a GitHub release and upload assets.")
    parser.add_argument("--owner", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--title", required=True)
    parser.add_argument("--body-file", required=True)
    parser.add_argument("--asset", action="append", default=[])
    args = parser.parse_args()

    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        raise SystemExit("GITHUB_TOKEN is required.")

    body = Path(args.body_file).read_text(encoding="utf-8")
    assets = [Path(path) for path in args.asset]

    release = ensure_release(args.owner, args.repo, args.tag, args.title, body, token)
    upload_assets(release, assets, token)
    print(f"release_url {release['html_url']}")


if __name__ == "__main__":
    main()
