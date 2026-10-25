"""Download the public OSF node pqf6v and write a SHA-256 manifest.

Walks every storage provider on the node and on any child components,
following folder listings and API pagination. Microdata files are saved
under data/raw/. Documentation and code are saved under docs/source/.
Prints paths, sizes, and hashes only; never prints file contents.

Expected public files: days.sav (61,714 bytes) and persons.sav (8,734 bytes).
The node has no licence. Reuse terms are an author decision, not a licence grant.
"""

from __future__ import annotations

import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import requests

NODE_ID = "pqf6v"
API = "https://api.osf.io/v2"
ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"
SOURCE_DIR = ROOT / "docs" / "source"
MANIFEST_PATH = ROOT / "docs" / "osf_manifest.json"

if ROOT.name != "SelfCompassion-Diary-APHW":
    raise SystemExit(f"Refusing to run outside the project folder: {ROOT}")

# Microdata suffixes. Spreadsheets land in data/raw unless the file name
# marks them as a codebook or other documentation.
DATA_SUFFIXES = {
    ".dat",
    ".csv",
    ".tsv",
    ".sav",
    ".zsav",
    ".dta",
    ".rds",
    ".rdata",
    ".sas7bdat",
    ".por",
    ".xpt",
}
SHEET_SUFFIXES = {".xlsx", ".xls"}
DOC_NAME_MARKERS = (
    "codebook",
    "readme",
    "supplement",
    "documentation",
    "legend",
    "syntax",
)

USER_AGENT = "SelfCompassion-Diary-APHW-fetch/1.0 (public OSF metadata; +https://osf.io/pqf6v)"


def configure_stdio() -> None:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


def api_session() -> requests.Session:
    session = requests.Session()
    session.headers.update(
        {
            "Accept": "application/vnd.api+json",
            "User-Agent": USER_AGENT,
        }
    )
    return session


SESSION = api_session()


def get_json(url: str) -> dict:
    response = SESSION.get(url, timeout=120)
    response.raise_for_status()
    payload = response.json()
    if not isinstance(payload, dict):
        raise RuntimeError(f"Unexpected JSON from {url}")
    return payload


def folder_listing_url(item: dict) -> str | None:
    relationships = item.get("relationships") or {}
    files_rel = relationships.get("files") or {}
    related = (files_rel.get("links") or {}).get("related") or {}
    if isinstance(related, dict) and related.get("href"):
        return related["href"]
    return None


def paginate(url: str):
    """Yield entities from an OSF list endpoint, descending if a folder object is returned."""
    seen = set()
    while url:
        if url in seen:
            raise RuntimeError(f"Pagination loop at {url}")
        seen.add(url)
        payload = get_json(url)
        data = payload.get("data")
        if isinstance(data, dict):
            kind = (data.get("attributes") or {}).get("kind")
            child = folder_listing_url(data)
            if kind == "folder" and child and child not in seen:
                url = child
                continue
            raise RuntimeError(f"Expected a file listing at {url}")
        yield from data or []
        url = (payload.get("links") or {}).get("next")


def iter_files(listing_url: str):
    for item in paginate(listing_url):
        kind = (item.get("attributes") or {}).get("kind")
        if kind == "folder":
            child = folder_listing_url(item)
            if not child:
                raise RuntimeError(f"Folder has no children URL: {item.get('id')}")
            yield from iter_files(child)
        elif kind == "file":
            yield item
        else:
            raise RuntimeError(f"Unknown file kind {kind!r} for {item.get('id')}")


def destination_dir(name: str) -> Path:
    suffix = Path(name).suffix.lower()
    lowered = name.lower()
    if any(marker in lowered for marker in DOC_NAME_MARKERS):
        return SOURCE_DIR
    if suffix in DATA_SUFFIXES or suffix in SHEET_SUFFIXES:
        return RAW_DIR
    return SOURCE_DIR


def safe_name(name: str) -> str:
    cleaned = "".join("_" if ch in '<>:"|?*' else ch for ch in name).rstrip(" .")
    if not cleaned or cleaned in {".", ".."}:
        raise RuntimeError(f"Refusing file name {name!r}")
    return cleaned


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    temporary = dest.with_name(dest.name + ".part")
    headers = {"Accept": "*/*", "User-Agent": USER_AGENT}
    try:
        with requests.get(
            url, headers=headers, stream=True, timeout=300, allow_redirects=True
        ) as response:
            response.raise_for_status()
            with temporary.open("wb") as handle:
                for chunk in response.iter_content(chunk_size=1024 * 1024):
                    if chunk:
                        handle.write(chunk)
        temporary.replace(dest)
    except Exception:
        if temporary.exists():
            temporary.unlink()
        raise


def identifier_record(item: dict) -> dict:
    attributes = item.get("attributes") or {}
    return {
        "id": item.get("id"),
        "category": attributes.get("category"),
        "value": attributes.get("value"),
    }


def probe_osf_doi(node_id: str) -> dict:
    url = f"https://doi.org/10.17605/OSF.IO/{node_id.upper()}"
    try:
        response = requests.get(
            url,
            headers={"User-Agent": USER_AGENT, "Accept": "text/html"},
            timeout=60,
            allow_redirects=True,
        )
        return {
            "url": url,
            "status_code": response.status_code,
            "final_url": response.url,
        }
    except requests.RequestException as exc:
        return {"url": url, "error": type(exc).__name__}


def wiki_pages() -> list[dict]:
    pages = []
    for item in paginate(f"{API}/nodes/{NODE_ID}/wikis/"):
        attributes = item.get("attributes") or {}
        pages.append(
            {
                "id": item.get("id"),
                "name": attributes.get("name"),
                "kind": attributes.get("kind"),
                "date_modified": attributes.get("date_modified"),
            }
        )
    return pages


def main() -> int:
    configure_stdio()
    node = get_json(f"{API}/nodes/{NODE_ID}/")["data"]
    attributes = node["attributes"]
    license_data = (node.get("relationships") or {}).get("license", {}).get("data")
    identifiers = [
        identifier_record(item) for item in paginate(f"{API}/nodes/{NODE_ID}/identifiers/")
    ]
    children = list(paginate(f"{API}/nodes/{NODE_ID}/children/"))
    wikis = wiki_pages()
    doi_probe = probe_osf_doi(NODE_ID)

    nodes_to_walk = [(NODE_ID, list(paginate(f"{API}/nodes/{NODE_ID}/files/")))]
    for child in children:
        child_id = child["id"]
        nodes_to_walk.append((child_id, list(paginate(f"{API}/nodes/{child_id}/files/"))))

    used_paths: set[Path] = set()
    records = []
    for node_id, providers in nodes_to_walk:
        for provider in providers:
            listing = folder_listing_url(provider)
            if not listing:
                raise RuntimeError(f"No file listing for provider on node {node_id}")
            provider_name = (provider.get("attributes") or {}).get("provider")
            for item in iter_files(listing):
                file_attributes = item["attributes"]
                original_name = file_attributes["name"]
                stored_name = safe_name(original_name)
                dest = destination_dir(original_name) / stored_name
                if dest in used_paths:
                    guid = file_attributes.get("guid") or item["id"]
                    dest = dest.with_name(f"{guid}_{stored_name}")
                used_paths.add(dest)
                download(item["links"]["download"], dest)
                local_hash = sha256_file(dest)
                hashes = (file_attributes.get("extra") or {}).get("hashes") or {}
                osf_hash = hashes.get("sha256")
                local_size = dest.stat().st_size
                osf_size = file_attributes.get("size")
                record = {
                    "node_id": node_id,
                    "provider": file_attributes.get("provider") or provider_name,
                    "osf_id": item["id"],
                    "osf_guid": file_attributes.get("guid"),
                    "name": original_name,
                    "materialized_path": file_attributes.get("materialized_path"),
                    "download_url": item["links"].get("download"),
                    "osf_size": osf_size,
                    "local_size": local_size,
                    "size_match": local_size == osf_size,
                    "osf_sha256": osf_hash,
                    "sha256": local_hash,
                    "sha256_match": (
                        osf_hash.lower() == local_hash.lower() if isinstance(osf_hash, str) else None
                    ),
                    "local_path": dest.relative_to(ROOT).as_posix(),
                    "date_modified": file_attributes.get("date_modified"),
                }
                records.append(record)
                print(
                    f"{record['local_path']}\t{local_size}\t{local_hash}\tmatch={record['sha256_match']}",
                    flush=True,
                )

    description = attributes.get("description")
    manifest = {
        "node_id": NODE_ID,
        "html": node.get("links", {}).get("html") or f"https://osf.io/{NODE_ID}/",
        "api_node": f"{API}/nodes/{NODE_ID}/",
        "title": attributes.get("title"),
        "description": description,
        "description_present": bool(description and str(description).strip()),
        "public": attributes.get("public"),
        "category": attributes.get("category"),
        "date_created": attributes.get("date_created"),
        "date_modified": attributes.get("date_modified"),
        "tags": attributes.get("tags") or [],
        "node_license": attributes.get("node_license"),
        "license_relationship": license_data,
        "identifiers": identifiers,
        "osf_doi_probe": doi_probe,
        "child_node_ids": [child["id"] for child in children],
        "wiki_pages": wikis,
        "providers": [
            (provider.get("attributes") or {}).get("provider")
            for _, provider_items in nodes_to_walk
            for provider in provider_items
        ],
        "fetched_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "file_count": len(records),
        "total_bytes": sum(record["local_size"] for record in records),
        "files": records,
    }
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(
        f"MANIFEST docs/osf_manifest.json files={manifest['file_count']} "
        f"bytes={manifest['total_bytes']} wikis={len(wikis)} "
        f"license={attributes.get('node_license')!r} public={attributes.get('public')}",
        flush=True,
    )
    if any(record["sha256_match"] is False or record["size_match"] is False for record in records):
        print("HASH OR SIZE MISMATCH", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except requests.RequestException as exc:
        print(f"REQUEST FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
