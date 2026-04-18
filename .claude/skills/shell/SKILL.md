---
name: shell
description: Enforce the repo-standard structure for shell scripts (main() first, steps as functions, invocation at the bottom)
user-invocable: true
model: Haiku
allowed-tools: Bash(mise exec -- uv run pre-commit run:*), Bash(*/mise exec -- uv run pre-commit run:*)
---

# Shell Script Structure

## Purpose

Every shell script created or modified in this repository must follow a consistent, top-down layout so that a reader can understand *what* the script does from `main()` alone, and drill into *how* each step works by reading the dedicated function below.

## When to Use

**ALWAYS** use this skill when:

- Creating a new shell script (`.sh`, `.bash`) anywhere in the repo (e.g. `scripts/`, `.claude/skills/*/scripts/`, `bootstrap/`, ad-hoc helpers).
- Modifying an existing shell script — if it does not yet match this structure, refactor it into this shape as part of the change.
- Reviewing AI-generated shell code before writing it to disk.

## Required Structure

Every script must be organised in this exact order:

1. **Shebang** — `#!/usr/bin/env bash` (preferred) or `#!/bin/bash`.
2. **Header comment block** — one-line purpose, usage, options, examples.
3. **Strict mode** — `set -euo pipefail` (add `IFS=$'\n\t'` if word-splitting matters).
4. **`main()` function** — declared *before* any other function.
5. **Helper functions** — one per high-level step, declared *after* `main()`.
6. **Invocation line** — `main "$@"` on the last line of the file.

## Formatting

Always read and respect `.editorconfig` at the repo root before writing or modifying a shell script. It is the source of truth for indentation, line endings, charset, and final-newline rules. `shellcheck` won't flag it, but it breaks `.editorconfig` consistency.

### `main()` rules

- Stays minimal: sets a few required global variables (or parses args) and calls helpers.
- Reads like a human-language outline of the script: each line is a high-level step.
- No inline business logic, no nested loops, no `case` blocks beyond simple arg parsing.
- Helpers have verb-based, descriptive names (`validate_inputs`, `fetch_state`, `run_destroy`, `cleanup`).

### Helper function rules

- Declared *below* `main()`, in roughly the order they are called.
- Each corresponds to one human-understandable step from `main()`.
- Use `local` for every variable inside a function.
- Return meaningful exit codes; let `set -e` propagate failures.

## Template

```bash
#!/usr/bin/env bash
#
# <one-line purpose>
#
# Usage:
#   ./script-name.sh [--flag VALUE] [ARG]
#
# Options:
#   --flag VALUE   <description>
#
# Example:
#   ./script-name.sh --flag foo bar
#

set -euo pipefail

main() {
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  TARGET="${1:-default}"

  parse_args "$@"
  validate_inputs
  do_the_thing
  cleanup
}

parse_args() {
  # flag parsing here
  :
}

validate_inputs() {
  local dir="$REPO_ROOT/$TARGET"
  [[ -d "$dir" ]] || { echo "ERROR: missing $dir" >&2; exit 1; }
}

do_the_thing() {
  # core logic — one responsibility
  :
}

cleanup() {
  # tear down temp files, etc.
  :
}

main "$@"
```

> Indentation above is 2 spaces per repo `.editorconfig`. Adjust if the target repo's `.editorconfig` says otherwise — `.editorconfig` always wins over this template.

## Anti-patterns to reject

- Top-level imperative code other than `set …`, constant assignments that `main()` genuinely cannot own, and the final `main "$@"` line.
- `main()` defined at the bottom of the file (below helpers) — this repo requires `main()` on top.
- A `main()` that contains the whole logic as one long sequence instead of delegating to named steps.
- Helpers defined *above* `main()` — reader should hit the outline first.
- Missing `main "$@"` invocation at the bottom.
- Relying on function hoisting tricks or sourcing the script without `main` being explicitly invoked.

## Quality checks

After writing or modifying a shell script, run:

```bash
mise exec -- uv run pre-commit run --files path/to/script.sh
```

This triggers `shellcheck` (configured in `.pre-commit-config.yaml`) and fixes indentation/EOL per `.editorconfig`. Resolve every finding before finishing the task.

## Rationale

- **Readability** — `main()` at the top gives a reader the table of contents; they only drill into helpers they care about.
- **Testability** — isolated helpers are easy to source and unit-test with `bats` or by calling them directly.
- **Consistency** — matches the style already used in longer scripts in `scripts/` and mirrors the top-down layout of Python entry points in this codebase.
