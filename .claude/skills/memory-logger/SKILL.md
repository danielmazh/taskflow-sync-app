---
name: memory-logger
description: Persist isolated, highly concise project-local technical memory entries — SSH/proxy access patterns, Docker/container quirks, environment flags, network/IP inventories, credential locations, and engineering rules — into sequential `./.claude/memory/nnn-<slug>.md` files. Use this whenever you map a network component, establish an SSH or Docker access method, discover an environment-specific flag or kernel/runtime quirk, identify a credential or key location, or codify a non-obvious infrastructure rule worth recalling next session. Trigger even when the user does not explicitly say "remember this" — silently capture the insight when the context shift is significant. Skip when the active project already defines its own memory convention (e.g., a vault, knowledge base, or memory directory documented in CLAUDE.md); defer to that system instead.
user-invocable: true
---

# memory-logger

Logs one isolated technical insight per file into the active project's `./.claude/memory/` directory, indexed sequentially. The goal is durable, terse, machine-and-human-readable context that survives across agent sessions without bloating any one file.

A bundled script (`scripts/save_memory.py`) handles project-root resolution, sequence numbering, date stamping, the global-`~/.claude` guard, and the defer-to-project-convention guard. **Use the script — do not hand-roll file writes.**

## When to use

Trigger this skill the moment you learn something concrete that future-you would need to act effectively in the same project. Concretely:

- A new SSH command, bastion/proxyjump topology, or key path is established.
- A Docker, container, or runtime flag/env-var/socket-mount requirement is discovered.
- A network component, IP, subnet, or hostname inventory is mapped.
- A credential, secret, or key location is identified (record the *location*, never the secret itself).
- An engineering rule — ordering constraint, sequencing requirement, version pin — is codified.
- A non-obvious environment quirk that bit you (or almost did) needs preserving.

Do not trigger for: ephemeral task state, things derivable from `git log`, content already in `CLAUDE.md`, or anything subjective.

## When NOT to use — defer to existing project conventions

**This is a hard precedence rule, not a suggestion.** Before writing anything, check whether the active project already owns persistent context through another system. If any of the following are present, **route the note there and skip this skill entirely**:

- `<project-root>/.claude/vault/` exists → the project uses `obsidian-vault`. Write a vault note instead.
- `CLAUDE.md` (or a sibling guide) names a knowledge base, docs/ tree, external KB, or specific memory directory → use whatever it specifies.
- Any other project-level memory directive in `CLAUDE.md` → it outranks this global default.

The bundled script enforces this guard automatically: if it detects `.claude/vault/` or a CLAUDE.md that references a memory convention, it exits non-zero and refuses to write. The `--force` flag can override the guard, but you should only use it when you are certain `memory-logger` is the correct destination and the project's convention does not actually cover this note's content.

Project policy outranks this global default. When in doubt, prompt the operator to confirm rather than forcing the write.

## Strict rules

1. **Location:** Always `<project-root>/.claude/memory/`. Never `~/.claude/`. The script refuses writes under the global `~/.claude` and resolves project root as *git toplevel of cwd, else cwd*.
2. **One insight per file.** Never bundle two distinct findings. If you have two, call the script twice.
3. **Sequential naming:** `nnn-<concise-hyphenated-description>.md`, where `nnn` is zero-padded to 3 digits and one greater than the highest existing index (project-local convention; the bundled script in this project is patched to 3 digits). The script computes this — do not guess.
4. **Token budget: 50-100 tokens of body content.** Terse enough to scan, dense enough to act on. The script warns if the body exceeds ~90 words.
5. **Mandatory first line (stamped by the script):** `Date: YYYY-MM-DD`. No frontmatter, no headings before the date.
6. **Mandatory `Rule:` line** in the body, in imperative form. The script warns if it is missing.
7. **Never write secrets.** Record where a secret lives (path, vault, env-var name), never the value.

## How to save — use the script

```bash
python3 .claude/skills/memory-logger/scripts/save_memory.py \
  --slug <short-hyphenated-description> \
  --content "<the body — labeled fields ending with a Rule: line>"
```

For multi-line bodies, pipe via stdin instead of `--content`. Pass `--root <dir>` only when targeting a project other than the current one. The script prints the path it wrote, e.g. `<project>/.claude/memory/003-redis-endpoint-oci.md`, plus any warnings (length, missing `Rule:` line).

Exit codes:
- `2` — empty body.
- `3` — refused: would write under global `~/.claude`.
- `4` — refused: project already owns persistent context (vault or CLAUDE.md directive). Re-run with `--force` only if you are certain.

## Body template

```
Insight: <one-sentence statement of the core technical truth>
<Optional one-line context fields — pick the labels that fit, e.g.:>
Access: <command, host, key path>
Configuration: <flag, mount, env-var>
Nodes: <IPs, hostnames>
Authentication: <key location, not the key>
Constraint: <what must hold for this to work>
Rule: <the actionable directive a future agent should follow>
```

The labels above are guidance, not a rigid schema — use the ones that match the insight. Always end with a `Rule:` line in imperative form, because that is what a future session will scan for.

## Execution

1. Compose the body using the template (labels + mandatory `Rule:` line). Keep it 50-100 tokens.
2. Choose a slug: 3-6 hyphenated lowercase words capturing the core subject (e.g., `vm1-clickhouse-ssh-form`, `litellm-proxy-header-trust`).
3. Invoke the script. Let it resolve the root, pick the index, stamp the date, and apply guards.
4. If the script exits 4 (existing convention), do not bypass with `--force` reflexively — instead, route the note to the project's actual memory system.
5. Mention to the user, in one short line, that the insight was captured and report the filename the script printed.

## Examples

**`./.claude/memory/001-bastion-ssh-proxyjump.md`** (after the script stamps the date)
```
Date: 2026-06-02
Insight: Internal worker nodes are only reachable via the bastion on 10.0.4.15:2222 due to subnet isolation.
Access: ssh -J admin@10.0.4.15:2222 root@<internal-node-ip>
Authentication: ~/.ssh/antigravity_root.pem
Rule: Always proxyjump through the bastion for any automated task targeting internal workers.
```

**`./.claude/memory/002-docker-socket-mount.md`**
```
Date: 2026-06-02
Insight: Test containers that need to run sibling containers must mount the host Docker socket.
Configuration: append `-v /var/run/docker.sock:/var/run/docker.sock` to `docker run`.
Constraint: container user must belong to GID 999 (docker group) or socket access is denied.
Rule: Bake the GID and the socket mount into the test-runner image, not into ad-hoc invocations.
```

**`./.claude/memory/003-prod-worker-inventory.md`**
```
Date: 2026-06-02
Insight: The production task cluster is exactly three PM2-managed nodes; ordering matters for stateful operations.
Nodes: worker-01 (10.0.5.1), worker-02 (10.0.5.2), worker-03 (10.0.5.3).
Authentication: /etc/vault/keys/deploy.key on all three.
Rule: Sequence rollouts and migrations strictly from worker-01 → worker-02 → worker-03 to preserve state.
```

## Why the constraints exist

- **Isolation** (one insight per file) means future agents can grep, link, or delete a finding without disturbing siblings.
- **Sequential indexes** give a stable referent (`memory/017`) for cross-linking and chronology.
- **50-100 token budget** keeps the directory cheap to skim. A bloated memory directory is unread; a terse one gets consulted.
- **The `Rule:` line** is what the next session reads first — it should stand on its own as a directive without requiring the rest of the file as context.
- **The defer-to-project guard** prevents this skill from polluting projects that already have a richer convention (vault, KB, etc.). Enforced both in prose and in the script so an agent that misses the rule still cannot override the project's convention by accident.
- **The script** moves project-root resolution, sequencing, date stamping, and both guards out of agent-judgement and into deterministic code — the parts agents reliably get wrong.
