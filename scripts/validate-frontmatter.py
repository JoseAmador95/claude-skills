#!/usr/bin/env python3
"""Validate YAML frontmatter in skill and agent markdown files.

Rules:
  - <skill>/SKILL.md           must have: name, description
  - <skill>/agents/*.md        must have: name, description, tools, model

Frontmatter is the block between the first pair of --- delimiters at the top
of the file.  We parse only the top-level scalar keys that appear at column 0
(no leading whitespace), which avoids the need for an external YAML library
while correctly handling multi-line block scalars (>-, |-, etc.).

Exit 0 if all files pass; exit 1 otherwise.
"""

import os
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# Frontmatter extraction
# ---------------------------------------------------------------------------

def extract_frontmatter_keys(path: Path) -> set[str] | None:
    """Return the set of top-level YAML keys found in the frontmatter block.

    Returns None if the file has no frontmatter (does not start with ---).
    """
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"  ERROR: cannot read {path}: {exc}", file=sys.stderr)
        return set()

    lines = text.splitlines()
    if not lines or lines[0].rstrip() != "---":
        return None

    keys: set[str] = set()
    for line in lines[1:]:
        stripped = line.rstrip()
        if stripped == "---":
            break  # end of frontmatter
        # A top-level key starts at column 0 with no leading whitespace and
        # contains a colon.  We deliberately skip lines that start with
        # whitespace (continuation of block scalars) or that are blank.
        if line and not line[0].isspace() and ":" in line:
            key = line.split(":", 1)[0].strip()
            if key:
                keys.add(key)

    return keys


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
        skill_md = skill_dir / "SKILL.md"
        keys = extract_frontmatter_keys(skill_md)
        rel = skill_md.relative_to(root)
        if keys is None:
            errors.append(f"{rel}: missing frontmatter (file must start with ---)")
        else:
            missing = SKILL_REQUIRED - keys
            if missing:
                errors.append(
                    f"{rel}: missing required keys: {', '.join(sorted(missing))}"
                )
            else:
                checked.append(str(rel))

        # --- agents/*.md ---
        agents_dir = skill_dir / "agents"
        if agents_dir.is_dir():
            for agent_md in sorted(agents_dir.glob("*.md")):
                rel_a = agent_md.relative_to(root)
                keys_a = extract_frontmatter_keys(agent_md)
                if keys_a is None:
                    errors.append(
                        f"{rel_a}: missing frontmatter (file must start with ---)"
                    )
                else:
                    missing_a = AGENT_REQUIRED - keys_a
                    if missing_a:
                        errors.append(
                            f"{rel_a}: missing required keys: "
                            f"{', '.join(sorted(missing_a))}"
                        )
                    else:
                        checked.append(str(rel_a))

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
