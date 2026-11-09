#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""在 GitHub Actions 里把编译好的 ipa 通过 api.github.com 写回仓库。

这是 artifact 下载的第二条通道：某些网络下 artifacts 的 302 目标域名很慢，
而 api.github.com 通常可直连。本机 build_remote.py 会优先用 artifact，
失败时再从仓库的 output/DocScan-unsigned.ipa 读取。
"""
from __future__ import annotations

import base64
import json
import os
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IPA = ROOT / "build" / "DocScan-unsigned.ipa"
REMOTE_PATH = "output/DocScan-unsigned.ipa"


def request(url, token, payload=None, method="GET", timeout=180):
    headers = {
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
        "User-Agent": "DocScan-Builder/1.0",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    data = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        body = resp.read()
        return json.loads(body.decode("utf-8")) if body else {}


def main():
    if not IPA.exists():
        raise SystemExit("找不到编译产物：%s" % IPA)
    raw = IPA.read_bytes()
    token = os.environ["GH_TOKEN"]
    repo = os.environ["GH_REPO"]
    branch = os.environ.get("GH_BRANCH") or "main"
    url = "https://api.github.com/repos/%s/contents/%s" % (repo, REMOTE_PATH)
    print("ipa 大小：%.2f MB" % (len(raw) / 1048576))

    sha = None
    try:
        sha = request(url + "?ref=" + branch, token, timeout=60).get("sha")
    except urllib.error.HTTPError as e:
        if e.code != 404:
            raise
    payload = {
        "message": "Publish unsigned IPA (build %s)" % os.environ.get("GITHUB_RUN_ID", "?"),
        "content": base64.b64encode(raw).decode("ascii"),
        "branch": branch,
    }
    if sha:
        payload["sha"] = sha
    result = request(url, token, payload, method="PUT")
    print("已回传仓库：%s" % result.get("content", {}).get("path", REMOTE_PATH))


if __name__ == "__main__":
    main()
