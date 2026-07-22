#!/usr/bin/env python3
"""Validate YAML frontmatter in plugin skill and agent markdown files.

Rules (for every plugin under ``plugins/<plugin>/``):
  - skills/<skill>/SKILL.md   must have: name, description
  - agents/*.md               must have: name, description, tools, model
                              and, if present, effort must be a valid value

A plugin directory is a direct subdirectory of ``plugins/`` that carries a
``.claude-plugin/plugin.json`` manifest.  The ``_template/`` scaffold at the repo
root is intentionally not a plugin directory, so it is skipped.

Frontmatter is the block between the first pair of --- delimiters at the top
of the file.  We parse only the top-level scalar keys that appear at column 0
(no leading whitespace), which avoids the need for an external YAML library
while correctly handling multi-line block scalars (>-, |-, etc.).

Exit 0 if all files pass; exit 1 otherwise.
"""

import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Frontmatter extraction
# ---------------------------------------------------------------------------

def extract_frontmatter(path: Path) -> dict[str, str] | None:
    """Return the top-level YAML keys (mapped to their inline scalar value).

    The value is the text after the first colon on the key's line, stripped.
    For block scalars (``key: >-``) the value is the indicator (``>-``); the
    folded body lives on indented continuation lines we deliberately skip.
    Returns None if the file has no frontmatter (does not start with ---).
    """
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"  ERROR: cannot read {path}: {exc}", file=sys.stderr)
        return {}

    lines = text.splitlines()
    if not lines or lines[0].rstrip() != "---":
        return None

    fm: dict[str, str] = {}
    for line in lines[1:]:
        stripped = line.rstrip()
        if stripped == "---":
            break  # end of frontmatter
        # A top-level key starts at column 0 with no leading whitespace and
        # contains a colon.  We deliberately skip lines that start with
        # whitespace (continuation of block scalars) or that are blank.
        if line and not line[0].isspace() and ":" in line:
            key, value = line.split(":", 1)
            key = key.strip()
            if key:
                fm[key] = value.strip()

    return fm


# ---------------------------------------------------------------------------
# Discovery
# ---------------------------------------------------------------------------

def find_plugin_dirs(root: Path) -> list[Path]:
    """Return plugin directories under ``<root>/plugins/``.

    A plugin directory is a direct subdirectory of ``plugins/`` that carries a
    ``.claude-plugin/plugin.json`` manifest.  Hidden directories are excluded.
    """
    plugin_dirs: list[Path] = []
    plugins_root = root / "plugins"
    try:
        entries = sorted(plugins_root.iterdir())
    except OSError:
        return plugin_dirs
    for entry in entries:
        if entry.is_dir() and not entry.name.startswith("."):
            if (entry / ".claude-plugin" / "plugin.json").exists():
                plugin_dirs.append(entry)
    return plugin_dirs


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

SKILL_REQUIRED = {"name", "description"}
AGENT_REQUIRED = {"name", "description", "tools", "model"}
EFFORT_VALID = {"low", "medium", "high", "xhigh", "max", "inherit"}


def check_file(
    path: Path,
    root: Path,
    required: set[str],
    errors: list[str],
    checked: list[str],
) -> None:
    """Validate one markdown file's frontmatter against a required key set."""
    rel = path.relative_to(root)
    fm = extract_frontmatter(path)
    if fm is None:
        errors.append(f"{rel}: missing frontmatter (file must start with ---)")
        return

    missing = required - fm.keys()
    if missing:
        errors.append(f"{rel}: missing required keys: {', '.join(sorted(missing))}")
        return

    # effort is optional, but if declared it must be a known value.  It is an
    # optional subagent/skill field; we validate the value without requiring
    # the key, so agents that omit it and the scaffold template keep passing.
    effort = fm.get("effort")
    if effort is not None and effort not in EFFORT_VALID:
        errors.append(
            f"{rel}: invalid effort '{effort}' "
            f"(expected one of: {', '.join(sorted(EFFORT_VALID))})"
        )
        return

    checked.append(str(rel))


def validate(root: Path) -> bool:
    """Run all checks and return True if everything passes."""
    errors: list[str] = []
    checked: list[str] = []

    plugin_dirs = find_plugin_dirs(root)
    if not plugin_dirs:
        print(
            "WARNING: no plugin directories found "
            "(plugins/*/.claude-plugin/plugin.json) under", root
        )
        return True

    for plugin_dir in plugin_dirs:
        # --- skills/<skill>/SKILL.md ---
        skills_dir = plugin_dir / "skills"
        if skills_dir.is_dir():
            for skill_md in sorted(skills_dir.glob("*/SKILL.md")):
                check_file(skill_md, root, SKILL_REQUIRED, errors, checked)

        # --- agents/*.md ---
        agents_dir = plugin_dir / "agents"
        if agents_dir.is_dir():
            for agent_md in sorted(agents_dir.glob("*.md")):
                check_file(agent_md, root, AGENT_REQUIRED, errors, checked)

    if errors:
        print("FAIL — frontmatter validation errors:")
        for err in errors:
            print(f"  - {err}")
        return False

    print(f"OK — {len(checked)} file(s) validated successfully:")
    for f in checked:
        print(f"  + {f}")
    return True


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    repo_root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
    repo_root = repo_root.resolve()
    ok = validate(repo_root)
    sys.exit(0 if ok else 1)
