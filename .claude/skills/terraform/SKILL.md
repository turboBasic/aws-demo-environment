---
name: terraform
description: Run the repo-pinned version of terraform via mise
user-invocable: false
model: Haiku
allowed-tools: Bash(*/mise:*),Bash(mise:*)
---

# Terraform via mise

## Purpose

Run `terraform` using the version pinned by this repo's [.mise.toml](../../../.mise.toml). [mise](https://mise.jdx.dev) resolves the correct terraform binary per directory.

## When to Use

**ALWAYS** use this skill before running ANY `terraform` command (`init`, `plan`, `apply`, `destroy`, `fmt`, `validate`, etc.).

## Step 1 — Locate `mise`

Resolve `mise` once per session. Try these in order and stop at the first hit:

1. `mise` already on `PATH` (use it as-is)
2. `/opt/homebrew/bin/mise` — macOS Homebrew (Apple Silicon)
3. `/usr/local/bin/mise` — macOS Homebrew (Intel) / common Linux install
4. `/home/linuxbrew/.linuxbrew/bin/mise` — Linux Homebrew
5. `$HOME/.local/bin/mise` — mise installer default

If none resolve, tell the user mise is missing and suggest `brew install mise` (or <https://mise.jdx.dev/getting-started.html>).

## Step 2 — Run terraform

Prefix every terraform invocation with `<mise> exec --`. mise reads `.mise.toml` from the current working directory and injects the pinned tool's `bin/` into `PATH` for the wrapped command.

```bash
mise exec -- terraform init
mise exec -- terraform plan
mise exec -- terraform apply
mise exec -- terraform fmt -check
```

Substitute the full path from Step 1 if `mise` is not on `PATH` (e.g. `/opt/homebrew/bin/mise exec -- terraform init`).

## Working Directory

`mise exec` reads `.mise.toml` relative to CWD. When operating on `bootstrap/` or any other subdirectory, `cd` into it first (or pass `--chdir`) so mise picks up the correct config.

## Error Handling

- **`mise` not found in any candidate path** → install via `brew install mise`, or see <https://mise.jdx.dev/getting-started.html>.
- **`terraform: no such tool installed`** → run `mise install` from the repo root to install tools declared in `.mise.toml`.
- **Version mismatch with `.mise.toml`** → run `mise install terraform` to sync.
