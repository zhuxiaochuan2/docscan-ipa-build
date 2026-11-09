#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DocScan 云端编译助手 —— Windows 专用，不需要 Mac、Xcode、GitHub CLI。

它只调用 GitHub 的接口完成这些事：
  1. 用你的 GitHub 账号创建一个公开仓库，把源码逐个文件传上去
  2. 触发仓库里的 GitHub Actions（云端 macOS + Xcode）编译出未签名 ipa
  3. 等编译结束，把 ipa 下载回本机

用法：双击项目根目录的 build-ipa.bat，或命令行运行：
      python tools/build_remote.py

token 获取：本脚本会打印一个链接，打开后点几下就能生成一个。
所有源码、图片都只在你自己的 GitHub 仓库里，不包含任何密钥。
"""
from __future__ import annotations

import base64
import getpass
import io
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

ROOT = Path(__file__).resolve().parent.parent
API = "https://api.github.com"
TOKEN_FILE = ROOT / "tools" / "token.txt"
TOKEN_URL = "https://github.com/settings/tokens/new?scopes=repo,workflow&description=DocScan-Build"
SIGNUP_URL = "https://github.com/signup"
WORKFLOW = "build-ipa.yml"
REPO_NAME = os.environ.get("DOCSCAN_REPO", "docscan-ipa-build")

SKIP_DIRS = {".git", "build", "__pycache__", "gh_portable", ".idea", ".vscode"}
SKIP_NAMES = {"token.txt", ".DS_Store", "gh.exe"}
SKIP_SUFFIX = {".zip", ".ipa", ".log", ".pyc", ".xcuserstate"}


class ApiError(Exception):
    def __init__(self, code: int, body: str):
        super().__init__("GitHub API %d: %s" % (code, body[:300]))
        self.code = code
        self.body = body


class NoAuthRedirect(urllib.request.HTTPRedirectHandler):
    """下载 artifact 会 302 到签名 URL，重定向时去掉 Authorization 头。"""
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new is not None:
            new.headers.pop("Authorization", None)
            new.unredirected_hdrs.pop("Authorization", None)
        return new


OPENER = urllib.request.build_opener(NoAuthRedirect())


def ask_token() -> str:
    token = (os.environ.get("DOCSCAN_TOKEN") or os.environ.get("GITHUB_TOKEN")
             or os.environ.get("GH_TOKEN") or "").strip()
    if token:
        return token
    if TOKEN_FILE.exists():
        token = TOKEN_FILE.read_text(encoding="utf-8").strip()
        if token:
            print("[信息] 已读取本地保存的 token：tools/token.txt")
            return token
    print()
    print("=" * 66)
    print("  第一次使用，需要一个 GitHub 访问令牌（只需做一次）")
    print("=" * 66)
    print("  1. 没有账号？先注册（免费）： %s" % SIGNUP_URL)
    print("  2. 打开这个链接（已自动勾好权限）：")
    print("     %s" % TOKEN_URL)
    print("  3. 拉到页面底部点 Generate token，复制那串 ghp_ 开头的字符")
    print("  4. 回到这个窗口，粘贴到下面并回车（输入时不会显示）")
    print("=" * 66)
    try:
        token = getpass.getpass("\n  请粘贴 token：").strip()
    except Exception:
        token = input("\n  请粘贴 token：").strip()
    if not token:
        raise SystemExit("没有输入 token，已退出。")
    return token


def api(method: str, path: str, payload=None, token: str = "", raw: bool = False, timeout: int = 90):
    url = path if path.startswith("http") else API + path
    body = json.dumps(payload).encode("utf-8") if payload is not None else None
    headers = {
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
        "User-Agent": "DocScan-Builder/1.0",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if body is not None:
        headers["Content-Type"] = "application/json"
    last: Exception | None = None
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, data=body, method=method, headers=headers)
            with OPENER.open(req, timeout=timeout) as resp:
                data = resp.read()
                if raw:
                    return data
                return json.loads(data.decode("utf-8")) if data else {}
        except urllib.error.HTTPError as e:
            text = e.read().decode("utf-8", "replace")
            if e.code in (400, 401, 403, 404, 409, 422) or attempt == 2:
                raise ApiError(e.code, text)
            last = e
        except Exception as e:
            last = e
            if attempt == 2:
                raise
        time.sleep(2 * (attempt + 1))
    raise last or RuntimeError("unknown error")


def collect_files() -> list[tuple[str, bytes]]:
    out: list[tuple[str, bytes]] = []
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file():
            continue
        rel = path.relative_to(ROOT).as_posix()
        parts = rel.split("/")
        if any(p in SKIP_DIRS for p in parts[:-1]):
            continue
        if path.name in SKIP_NAMES or path.suffix.lower() in SKIP_SUFFIX:
            continue
        out.append((rel, path.read_bytes()))
    return out


def ensure_repo(token: str) -> tuple[str, str]:
    who = api("GET", "/user", token=token)["login"]
    print("[1/6] GitHub 账号：%s" % who)
    full = ""
    branch = "main"
    for name in [REPO_NAME] + ["%s-%d" % (REPO_NAME, i) for i in range(2, 6)]:
        try:
            repo = api("GET", "/repos/%s/%s" % (who, name), token=token)
            full = repo["full_name"]
            branch = repo.get("default_branch") or "main"
            print("[2/6] 复用已有仓库：%s" % full)
            break
        except ApiError as e:
            if e.code != 404:
                raise
        try:
            repo = api("POST", "/user/repos", {
                "name": name,
                "description": "DocScan TrollStore unsigned IPA build",
                "private": False,
                "auto_init": False,
                "has_issues": False,
                "has_projects": False,
                "has_wiki": False,
            }, token=token)
            full = repo["full_name"]
            branch = repo.get("default_branch") or "main"
            print("[2/6] 已创建公开仓库：%s" % full)
            break
        except ApiError as e:
            if e.code not in (422, 409):
                raise
    if not full:
        raise RuntimeError("无法创建仓库，请检查 token 是否勾选了 repo 权限。")
    return full, branch


def upload_files(full: str, branch: str, token: str) -> str:
    files = collect_files()
    print("[3/6] 上传 %d 个源码文件（只走 api.github.com，不依赖 github.com 网页）" % len(files))
    # 空仓库第一次提交不能指定不存在的分支，交给 GitHub 建默认分支
    try:
        empty = api("GET", "/repos/%s" % full, token=token).get("size", 0) == 0
    except Exception:
        empty = False
    done = 0
    for rel, data in files:
        b64 = base64.b64encode(data).decode("ascii")
        q = urllib.parse.quote(rel, safe="/")
        ep = "/repos/%s/contents/%s" % (full, q)
        sha = None
        try:
            cur = api("GET", ep + "?ref=" + urllib.parse.quote(branch), token=token)
            if "".join(cur.get("content", "").split()) == b64:
                done += 1
                continue
            sha = cur.get("sha")
        except ApiError as e:
            if e.code != 404:
                raise
        payload = {"message": "Add " + rel, "content": b64}
        if not (empty and done == 0):
            payload["branch"] = branch
        if sha:
            payload["sha"] = sha
        api("PUT", ep, payload, token=token)
        done += 1
        if empty and done == 1:
            info = api("GET", "/repos/%s" % full, token=token)
            branch = info.get("default_branch") or branch
            empty = False
        if done % 5 == 0 or done == len(files):
            print("      %d/%d ..." % (done, len(files)), flush=True)
        time.sleep(0.25)
    print("      上传完成，默认分支：%s" % branch)
    return branch


def wait_workflow(full: str, token: str) -> None:
    print("[4/6] 等待 GitHub 识别工作流 ...", flush=True)
    for _ in range(20):
        try:
            wf = api("GET", "/repos/%s/actions/workflows" % full, token=token)
            if any(w["name"] == "Build unsigned IPA" or w["path"].endswith(WORKFLOW)
                   for w in wf.get("workflows", [])):
                return
        except ApiError:
            pass
        time.sleep(4)
    print("      [提示] 工作流识别较慢，继续尝试触发")


def trigger_and_watch(full: str, branch: str, token: str) -> tuple[int, str]:
    disp = "/repos/%s/actions/workflows/%s/dispatches" % (full, WORKFLOW)
    try:
        before = api("GET", "/repos/%s/actions/workflows/%s/runs?per_page=1" % (full, WORKFLOW), token=token)
        runs = before.get("workflow_runs", [])
        last_id = runs[0]["id"] if runs else 0
    except ApiError:
        last_id = 0

    api("POST", disp, {"ref": branch}, token=token)
    print("[5/6] 已触发云端编译（macOS + Xcode），等待任务出现 ...", flush=True)
    run_id = 0
    for _ in range(40):
        try:
            res = api("GET", "/repos/%s/actions/workflows/%s/runs?per_page=5" % (full, WORKFLOW), token=token)
            for r in res.get("workflow_runs", []):
                if r["id"] > last_id:
                    run_id = r["id"]
                    break
            if run_id:
                break
        except ApiError:
            pass
        time.sleep(5)
    if not run_id:
        raise RuntimeError("没能找到编译任务，请打开 %s/actions 查看。" % ("https://github.com/" + full))

    url = "https://github.com/%s/actions/runs/%d" % (full, run_id)
    print("      任务地址：%s" % url)
    start = time.time()
    while True:
        r = api("GET", "/repos/%s/actions/runs/%d" % (full, run_id), token=token)
        if r.get("status") == "completed":
            print("      编译结束：%s（用时 %d 秒）" % (r.get("conclusion"), int(time.time() - start)))
            return run_id, r.get("conclusion") or "unknown"
        elapsed = int(time.time() - start)
        print("      编译中 ... 已等待 %d 秒" % elapsed, flush=True)
        if elapsed > 2100:
            raise RuntimeError("编译超时（35 分钟），请到任务页面查看：%s" % url)
        time.sleep(15)


def download_artifact(full: str, run_id: int, name: str, token: str) -> bytes | None:
    try:
        arts = api("GET", "/repos/%s/actions/runs/%d/artifacts" % (full, run_id), token=token)
        for a in arts.get("artifacts", []):
            if a["name"] == name and not a.get("expired"):
                return api("GET", "/repos/%s/actions/artifacts/%d/zip" % (full, a["id"]),
                           token=token, raw=True, timeout=180)
    except Exception as e:
        print("      [提示] 下载 %s 失败：%s" % (name, e))
    return None


def download_ipa_from_repo(full: str, branch: str, token: str) -> bytes | None:
    """备用通道：从仓库 contents + git blob 读取 ipa，全程只走 api.github.com。"""
    ep = "/repos/%s/contents/output/DocScan-unsigned.ipa?ref=%s" % (
        full, urllib.parse.quote(branch))
    try:
        info = api("GET", ep, token=token, timeout=60)
    except ApiError as e:
        if e.code == 404:
            return None
        print("      [提示] 读取仓库产物失败：%s" % e)
        return None
    sha = info.get("sha")
    if not sha:
        return None
    try:
        blob = api("GET", "/repos/%s/git/blobs/%s" % (full, sha), token=token, timeout=240)
        content = "".join(blob.get("content", "").split())
        return base64.b64decode(content) if content else None
    except Exception as e:
        print("      [提示] 读取 blob 失败：%s" % e)
        return None


def main() -> int:
    if "--dry-run" in sys.argv:
        files = collect_files()
        print("dry-run: 将上传 %d 个文件" % len(files))
        for rel, data in files:
            print("  %-62s %7d B" % (rel, len(data)))
        return 0

    print()
    print("  DocScan · Windows 云端编译助手")
    print("  本机不需要 Mac / Xcode，编译在 GitHub 的 macOS 机器上完成")
    print()

    token = ask_token()
    try:
        user = api("GET", "/user", token=token)
    except ApiError as e:
        print("\n[失败] token 无效或权限不足（%s）" % e)
        print("       请确认勾选了 repo 和 workflow 两项权限，或重新生成一个。")
        return 1
    if TOKEN_FILE.parent.exists() and not TOKEN_FILE.exists() and not os.environ.get("DOCSCAN_TOKEN"):
        try:
            TOKEN_FILE.write_text(token, encoding="utf-8")
            print("[信息] token 已存到 tools/token.txt，下次不用重输（用完可删除该文件并在 GitHub 撤销）")
        except Exception:
            pass
    print("[0/6] token 有效：%s" % user.get("login"))

    full, branch = ensure_repo(token)
    branch = upload_files(full, branch, token)
    wait_workflow(full, token)
    run_id, conclusion = trigger_and_watch(full, branch, token)

    print("[6/6] 取回编译产物 ...")
    log = download_artifact(full, run_id, "build-log", token)
    if log:
        try:
            z = zipfile.ZipFile(io.BytesIO(log))
            text = b"\n".join(z.read(n) for n in z.namelist() if n.endswith(".log"))
            (ROOT.parent / "xcodebuild.log").write_bytes(text)
            print("      编译日志已保存：%s" % (ROOT.parent / "xcodebuild.log"))
        except Exception as e:
            print("      [提示] 日志解析失败：%s" % e)

    if conclusion != "success":
        print()
        print("=" * 66)
        print("  编译失败了。日志已保存到：%s" % (ROOT.parent / "xcodebuild.log"))
        print("  任务页面：https://github.com/%s/actions/runs/%d" % (full, run_id))
        print("  把 xcodebuild.log 里最后的报错发给我，我改完你再跑一次即可。")
        print("=" * 66)
        return 2

    ipa_bytes: bytes | None = None
    data = download_artifact(full, run_id, "DocScan-unsigned-ipa", token)
    if data:
        try:
            z = zipfile.ZipFile(io.BytesIO(data))
            member = next(n for n in z.namelist() if n.lower().endswith(".ipa"))
            ipa_bytes = z.read(member)
        except Exception as e:
            print("      [提示] artifact 解压失败：%s" % e)
    if ipa_bytes is None:
        print("      改走接口通道取回 ipa ...", flush=True)
        ipa_bytes = download_ipa_from_repo(full, branch, token)
    if not ipa_bytes:
        print()
        print("  编译成功，但本机两条通道都没能取回 ipa（多半是网络）。")
        print("  请用浏览器打开下面地址，找到 Artifacts 里的 DocScan-unsigned-ipa 手动下载：")
        print("  https://github.com/%s/actions/runs/%d" % (full, run_id))
        return 3

    dest = ROOT.parent / "DocScan-unsigned.ipa"
    dest.write_bytes(ipa_bytes)

    print()
    print("=" * 66)
    print("  编译完成！ipa 已放在：")
    print("  %s" % dest)
    print("  大小：%.2f MB" % (dest.stat().st_size / 1048576))
    print()
    print("  接下来：把这个 ipa 传到 iPhone → 用 TrollStore 打开 → Install")
    print("=" * 66)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\n已取消")
        sys.exit(130)
    except Exception as exc:
        print("\n[出错] %s: %s" % (type(exc).__name__, exc))
        sys.exit(1)
