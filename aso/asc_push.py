"""Writes aso/metadata.py to App Store Connect through the official API.

Credentials come from the environment only (never stored in the repo):
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH   (path to the AuthKey_XXXX.p8 file)

  python3 aso/asc_push.py status            read-only: versions, states, existing localizations
  python3 aso/asc_push.py push              dry run: prints what would be created/updated
  python3 aso/asc_push.py push --apply      writes it

Name/subtitle/privacy URL live on appInfoLocalizations; keywords, promo text, description and the
support URL live on appStoreVersionLocalizations.
"""
from __future__ import annotations

import os
import sys
import time
from pathlib import Path

import jwt
import requests

sys.path.insert(0, str(Path(__file__).resolve().parent))
import metadata  # noqa: E402

API = "https://api.appstoreconnect.apple.com/v1"
APP_ID = "6790362517"
SESSION = requests.Session()


def token() -> str:
    key = Path(os.environ["ASC_KEY_PATH"]).read_text()
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1200,
                       "aud": "appstoreconnect-v1"}, key, algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


def call(method: str, path: str, body: dict | None = None, ok_fail: bool = False, **params):
    url = path if path.startswith("http") else API + path
    for attempt in range(5):
        r = SESSION.request(method, url, json=body, params=params or None,
                            headers={"Authorization": f"Bearer {token()}"}, timeout=60)
        if r.status_code == 429 or r.status_code >= 500:
            time.sleep(2 ** attempt)
            continue
        if r.status_code >= 400:
            if ok_fail:
                return {"_error": r.status_code, "_body": r.text[:1200]}
            raise SystemExit(f"{method} {path} -> {r.status_code}\n{r.text[:1500]}")
        return r.json() if r.content else {}
    raise SystemExit(f"{method} {path}: gave up after retries")


def all_pages(path: str, **params) -> list[dict]:
    out, data = [], call("GET", path, **params)
    while True:
        out += data["data"]
        nxt = data.get("links", {}).get("next")
        if not nxt:
            return out
        data = call("GET", nxt)


def context():
    app = call("GET", f"/apps/{APP_ID}")["data"]
    versions = all_pages(f"/apps/{APP_ID}/appStoreVersions", **{"filter[platform]": "IOS"})
    infos = all_pages(f"/apps/{APP_ID}/appInfos")
    return app, versions, infos


def status():
    app, versions, infos = context()
    print("app:", app["attributes"]["name"], "| primary locale:", app["attributes"]["primaryLocale"])
    for v in versions:
        print("version", v["attributes"]["versionString"], "state:", v["attributes"]["appStoreState"],
              "| review state:", v["attributes"].get("appVersionState"), "| id", v["id"])
    for i in infos:
        print("appInfo", i["id"], "state:", i["attributes"].get("appStoreState") or i["attributes"].get("state"))
    live_info = infos[0]
    for loc in all_pages(f"/appInfos/{live_info['id']}/appInfoLocalizations"):
        a = loc["attributes"]
        print("  appInfoLocalization", a["locale"], "|", a.get("name"), "|", a.get("subtitle"))
    for v in versions:
        for loc in all_pages(f"/appStoreVersions/{v['id']}/appStoreVersionLocalizations"):
            a = loc["attributes"]
            print("  versionLocalization", v["attributes"]["versionString"], a["locale"],
                  "| kw:", (a.get("keywords") or "")[:50])


def pick_editable(versions, infos):
    editable_versions = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
                         "WAITING_FOR_REVIEW", "INVALID_BINARY"}
    version = next((v for v in versions if v["attributes"]["appStoreState"] in editable_versions), None)
    info = next((i for i in infos if (i["attributes"].get("appStoreState") or "") in editable_versions), infos[0])
    return version, info


def push(apply: bool):
    if "--source=scanmuse" in sys.argv:
        import scanmuse_import
        data = scanmuse_import.build()
        bad = scanmuse_import.hard_limits(data)
        if bad:
            raise SystemExit(f"over Apple limits: {bad}")
    else:
        data = metadata.build()
        problems = metadata.validate(data)
        if problems:
            raise SystemExit("metadata invalid:\n  " + "\n  ".join(problems))
    app, versions, infos = context()
    version, info = pick_editable(versions, infos)
    if not version:
        raise SystemExit("no editable App Store version found")
    print(f"version {version['attributes']['versionString']} [{version['attributes']['appStoreState']}], "
          f"appInfo [{info['attributes'].get('appStoreState')}] -> {'APPLY' if apply else 'DRY RUN'}")

    info_locs = {l["attributes"]["locale"]: l for l in all_pages(f"/appInfos/{info['id']}/appInfoLocalizations")}
    ver_locs = {l["attributes"]["locale"]: l
                for l in all_pages(f"/appStoreVersions/{version['id']}/appStoreVersionLocalizations")}

    # primary locale first so the others inherit screenshots/defaults from it
    order = [metadata.PRIMARY] + [l for l in data if l != metadata.PRIMARY]
    results = []
    for locale in order:
        m = data[locale]
        info_attrs = {"name": m["name"], "subtitle": m["subtitle"], "privacyPolicyUrl": m["privacyPolicyUrl"]}
        ver_attrs = {"keywords": m["keywords"], "promotionalText": m["promotionalText"],
                     "description": m["description"], "whatsNew": m["whatsNew"],
                     "supportUrl": m["supportUrl"]}
        for kind, existing, attrs, parent_type, parent_id, res_type in (
            ("appInfoLocalization", info_locs, info_attrs, "appInfo", info["id"], "appInfoLocalizations"),
            ("versionLocalization", ver_locs, ver_attrs, "appStoreVersion", version["id"],
             "appStoreVersionLocalizations"),
        ):
            if locale in existing:
                action, body = "update", {"data": {"type": res_type, "id": existing[locale]["id"],
                                                   "attributes": attrs}}
                method, path = "PATCH", f"/{res_type}/{existing[locale]['id']}"
            else:
                action = "create"
                body = {"data": {"type": res_type, "attributes": {"locale": locale, **attrs},
                                 "relationships": {parent_type: {"data": {"type": parent_type + "s",
                                                                          "id": parent_id}}}}}
                method, path = "POST", f"/{res_type}"
            if not apply:
                print(f"  [dry] {action:6} {kind:20} {locale}")
                continue
            res = call(method, path, body, ok_fail=True)
            if "_error" in res:
                print(f"  FAIL  {action:6} {kind:20} {locale} -> {res['_error']} {res['_body'][:300]}")
                results.append((kind, locale, "fail"))
            else:
                print(f"  ok    {action:6} {kind:20} {locale}")
                results.append((kind, locale, "ok"))
    if apply:
        bad = [r for r in results if r[2] == "fail"]
        print(f"\ndone: {len(results) - len(bad)} ok, {len(bad)} failed")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        status()
    elif cmd == "push":
        push("--apply" in sys.argv)
    else:
        raise SystemExit(__doc__)
