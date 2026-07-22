#!/usr/bin/env python3
"""Deterministic structural validation of the marketplace and plugin manifests.

Without any external dependency or network access, checks that:
  - .claude-plugin/marketplace.json is valid JSON with a non-empty ``name``, an
    ``owner`` object carrying a ``name``, and a non-empty ``plugins`` array; every
    entry has a ``name`` and a ``source``, and a local ``"./..."`` source points at
    a directory that carries a ``.claude-plugin/plugin.json`` manifest.
  - every plugins/<plugin>/.claude-plugin/plugin.json is valid JSON with a
    non-empty ``name`` (the only field Claude Code requires).

This is the CI backstop for the plugin packaging: it runs deterministically even
when the ``claude plugin validate`` CLI is unavailable in the runner. Exit 0 on
success, 1 on the first structural problem found.
"""

import json
import sys
from pathlib import Path


def validate(root: Path) -> bool:
    errors: list[str] = []

    # --- marketplace.json ---
    mkt_path = root / ".claude-plugin" / "marketplace.json"
    if not mkt_path.is_file():
        print(f"FAIL — missing {mkt_path.relative_to(root)}")
        return False
    try:
        mkt = json.loads(mkt_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"FAIL — {mkt_path.relative_to(root)} is not valid JSON: {exc}")
        return False

    if not isinstance(mkt.get("name"), str) or not mkt["name"]:
        errors.append("marketplace.json: 'name' must be a non-empty string")
    owner = mkt.get("owner")
    if not isinstance(owner, dict) or not isinstance(owner.get("name"), str):
        errors.append("marketplace.json: 'owner' must be an object with a 'name'")
    plugins = mkt.get("plugins")
    if not isinstance(plugins, list) or not plugins:
        errors.append("marketplace.json: 'plugins' must be a non-empty array")
        plugins = []

    for i, entry in enumerate(plugins):
        where = f"marketplace.json plugins[{i}]"
        if not isinstance(entry, dict):
            errors.append(f"{where}: must be an object")
            continue
        if not isinstance(entry.get("name"), str) or not entry["name"]:
            errors.append(f"{where}: 'name' must be a non-empty string")
        source = entry.get("source")
        if source is None:
            errors.append(f"{where}: 'source' is required")
        elif isinstance(source, str) and source.startswith("./"):
            manifest = (root / source).resolve() / ".claude-plugin" / "plugin.json"
            if not manifest.is_file():
                errors.append(
                    f"{where}: source '{source}' has no .claude-plugin/plugin.json"
                )

    # --- every plugins/<plugin>/.claude-plugin/plugin.json ---
    plugins_root = root / "plugins"
    if plugins_root.is_dir():
        for manifest in sorted(plugins_root.glob("*/.claude-plugin/plugin.json")):
            rel = manifest.relative_to(root)
            try:
                data = json.loads(manifest.read_text(encoding="utf-8"))
            except json.JSONDecodeError as exc:
                errors.append(f"{rel}: not valid JSON: {exc}")
                continue
            if not isinstance(data.get("name"), str) or not data["name"]:
                errors.append(f"{rel}: 'name' must be a non-empty string")

    if errors:
        print("FAIL — plugin manifest validation errors:")
        for e in errors:
            print(f"  - {e}")
        return False

    print("OK — marketplace and plugin manifests are structurally valid.")
    return True


if __name__ == "__main__":
    repo_root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    sys.exit(0 if validate(repo_root.resolve()) else 1)
