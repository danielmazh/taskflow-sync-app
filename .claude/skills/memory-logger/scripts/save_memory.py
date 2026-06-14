#!/usr/bin/env python3
"""
save_memory.py — Append one project-memory file under <project-root>/.claude/memory/.

Handles the fiddly, error-prone parts deterministically so the agent doesn't have to:
  - resolve the project root (git toplevel of cwd, else cwd),
  - refuse to write into the GLOBAL ~/.claude (memory is per-project, never global),
  - refuse to write when a project-level memory convention already owns persistent
    context (an obsidian vault, an existing docs/KB directory, or a CLAUDE.md
    directive) unless the caller passes --force,
  - scan the directory and pick the next 4-digit sequential prefix,
  - stamp today's date at the top using the canonical `Date: YYYY-MM-DD` line,
  - write exactly one insight to its own uniquely-named file,
  - warn if the body looks longer than the ~50-100 token budget or is missing the
    mandatory `Rule:` line.

Usage:
  save_memory.py --slug bastion-ssh-proxyjump --content "Insight: ...\nRule: ..."
  echo "Insight: ...\nRule: ..." | save_memory.py --slug pm2-log-rotation
  save_memory.py --slug redis-endpoint --content "..." --root /opt/git/some-project
  save_memory.py --slug ... --content "..." --force   # override defer-to-project guard

Prints the path of the created file. Exits non-zero on a guard failure.
"""

import argparse
import datetime
import os
import re
import subprocess
import sys


def project_root(explicit):
    if explicit:
        return os.path.realpath(explicit)
    try:
        top = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, cwd=os.getcwd(),
        )
        if top.returncode == 0 and top.stdout.strip():
            return os.path.realpath(top.stdout.strip())
    except Exception:
        pass
    return os.path.realpath(os.getcwd())


def slugify(s):
    s = s.strip().lower()
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return re.sub(r"-{2,}", "-", s) or "note"


def next_index(memory_dir):
    mx = 0
    if os.path.isdir(memory_dir):
        for name in os.listdir(memory_dir):
            m = re.match(r"(\d{3})-.+\.md$", name)
            if m:
                mx = max(mx, int(m.group(1)))
    return mx + 1


def detect_competing_convention(root):
    """Return a human-readable reason if the project already owns persistent context."""
    vault_dir = os.path.join(root, ".claude", "vault")
    if os.path.isdir(vault_dir):
        return f"obsidian-vault present at {vault_dir}"

    claude_md = os.path.join(root, "CLAUDE.md")
    if os.path.isfile(claude_md):
        try:
            with open(claude_md, "r", encoding="utf-8", errors="replace") as f:
                text = f.read().lower()
            markers = ("obsidian-vault", ".claude/vault", "knowledge base", "memory convention")
            if any(m in text for m in markers):
                return f"CLAUDE.md references a project memory convention ({claude_md})"
        except Exception:
            pass

    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--slug", required=True,
                    help="Short hyphenated description of THIS one insight.")
    ap.add_argument("--content", default=None,
                    help="The insight body. If omitted, read from stdin.")
    ap.add_argument("--root", default=None,
                    help="Project root override. Default: git toplevel of cwd, else cwd.")
    ap.add_argument("--date", default=None,
                    help="Override the date stamp (YYYY-MM-DD). Default: today.")
    ap.add_argument("--force", action="store_true",
                    help="Bypass the defer-to-project-convention guard. Use sparingly.")
    args = ap.parse_args()

    body = args.content if args.content is not None else sys.stdin.read()
    body = body.strip()
    if not body:
        print("ERROR: empty content — nothing to save.", file=sys.stderr)
        sys.exit(2)

    root = project_root(args.root)
    memory_dir = os.path.join(root, ".claude", "memory")

    # Guard 1: memory is per-project. Never let it land inside the GLOBAL ~/.claude.
    global_claude = os.path.realpath(os.path.expanduser("~/.claude"))
    if os.path.realpath(memory_dir).startswith(global_claude + os.sep) or \
       os.path.realpath(memory_dir) == global_claude:
        print(f"ERROR: refusing to write under the global {global_claude}. "
              f"Run from inside a project, or pass --root <project-dir>.", file=sys.stderr)
        sys.exit(3)

    # Guard 2: defer to existing project memory conventions unless --force.
    if not args.force:
        reason = detect_competing_convention(root)
        if reason:
            print(
                f"ERROR: project at {root} already owns persistent context "
                f"({reason}). Route this note to that system instead, or rerun "
                f"with --force if you are certain memory-logger is correct here.",
                file=sys.stderr,
            )
            sys.exit(4)

    os.makedirs(memory_dir, exist_ok=True)

    idx = next_index(memory_dir)
    slug = slugify(args.slug)
    fname = f"{idx:03d}-{slug}.md"
    path = os.path.join(memory_dir, fname)

    date = args.date or datetime.date.today().isoformat()
    text = f"Date: {date}\n{body}\n"
    with open(path, "x", encoding="utf-8") as f:
        f.write(text)

    notes = []
    words = len(body.split())
    if words > 90:
        notes.append(f"~{words} words — consider trimming toward the 50-100 token target")
    if not re.search(r"(?im)^\s*Rule:\s*\S", body):
        notes.append("missing mandatory `Rule:` line — add an imperative directive")

    suffix = f"  (note: {'; '.join(notes)})" if notes else ""
    print(path + suffix)


if __name__ == "__main__":
    main()
