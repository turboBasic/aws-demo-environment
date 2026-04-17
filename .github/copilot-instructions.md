# AI Instructions - GitHub Copilot

This repository keeps AI coding instructions in a single source of truth:

- [docs/ai-instructions.md](../docs/ai-instructions.md)

GitHub Copilot: follow the linked instructions as if they were in this file.

Shared skills are defined in `.claude/skills/`. Use those skills and avoid creating duplicated skill instructions under `.github/skills/`.

## Command execution permissions

When evaluating or executing shell commands, GitHub Copilot should consult the workspace permissions declared in `.claude/settings.json` and follow them exactly. In particular:

- Only allow commands that match patterns listed under `permissions.allow` in `.claude/settings.json`.
- Never execute commands that match patterns listed under `permissions.deny` in `.claude/settings.json`.
