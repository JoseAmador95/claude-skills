#!/usr/bin/env python3
"""Validate YAML frontmatter in skill, agent, and command markdown files.

Rules:
  - <skill>/SKILL.md           must have: name, description
  - <skill>/agents/*.md        must have: name, description, tools, model
                               and, if present, effort must be a valid value
  - <skill>/commands/*.md      must have: description

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

def find_skill_dirs(root: Path) -> list[Path]:
    """Return direct subdirectories of root that look like skill directories.

    A skill directory must contain a SKILL.md file at its top level.
    Hidden directories (starting with '.') are excluded.
    """
    skill_dirs = []
    try:
        entries = sorted(root.iterdir())
    except OSError:
        return skill_dirs
    for entry in entries:
        if entry.is_dir() and not entry.name.startswith("."):
            if (entry / "SKILL.md").exists():
                skill_dirs.append(entry)
    return skill_dirs


# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------

SKILL_REQUIRED = {"name", "description"}
AGENT_REQUIRED = {"name", "description", "tools", "model"}
COMMAND_REQUIRED = {"description"}
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

    skill_dirs = find_skill_dirs(root)
    if not skill_dirs:
        print("WARNING: no skill directories found (directories with SKILL.md) under", root)
        return True

    for skill_dir in skill_dirs:
        # --- SKILL.md ---
        check_file(skill_dir / "SKILL.md", root, SKILL_REQUIRED, errors, checked)

        # --- agents/*.md ---
        agents_dir = skill_dir / "agents"
        if agents_dir.is_dir():
            for agent_md in sorted(agents_dir.glob("*.md")):
                check_file(agent_md, root, AGENT_REQUIRED, errors, checked)

        # --- commands/*.md ---
        commands_dir = skill_dir / "commands"
        if commands_dir.is_dir():
            for command_md in sorted(commands_dir.glob("*.md")):
                check_file(command_md, root, COMMAND_REQUIRED, errors, checked)

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
