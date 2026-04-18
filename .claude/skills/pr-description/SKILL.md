---
name: pr-description
description: Generate a PR description for the current branch using the repo PR template
user-invocable: true
model: Sonnet
allowed-tools: Bash(git log:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(git branch:*), Read
---

# PR Description Generator

## Purpose

Generate a pull request description for the current branch, filled from the repo's PR
template at `.github/PULL_REQUEST_TEMPLATE.md`.

## Steps

1. **Determine the base branch** — default to `main`; if `main` does not exist, fall back
   to `master`.

2. **Collect the diff** — run `git log` and `git diff` for all commits on this branch that
   are not yet on the base branch:

   ```bash
   git log --oneline origin/main..HEAD
   git diff origin/main...HEAD
   ```

3. **Read the PR template** — read `.github/PULL_REQUEST_TEMPLATE.md` verbatim; this is
   the skeleton you must fill in.

4. **Fill in the template** — replace every `{{ placeholder }}` and populate every section:

   | Template section | What to write |
   |-----------------|---------------|
   | `## Description` | One concise paragraph: *what* changed and *why* (the business/user motivation). No implementation detail. |
   | `## Changes`    | Bulleted list of concrete changes (files, resources, modules). Be specific — name the files or resources. |
   | `## Testing`    | Check the boxes that honestly apply; add a note if manual testing was done. |
   | `## Checklist`  | Check every box that is satisfied; leave unchecked anything not yet done. |

5. **Output** — wrap the completed description in a fenced markdown code block tagged
   `markdown` so the user can copy the raw text in one click:

   ````text
   ```markdown
   ## Description
   …
   ```
   ````

## Quality rules

- Do **not** invent changes that are not visible in the diff.
- Do **not** add extra sections beyond what the template defines.
- Keep the Description to ≤ 3 sentences.
- The Changes list must use plain Markdown bullets (`-`), not numbered lists.
- Preserve every HTML comment (`<!-- … -->`) from the template; do not delete them.
- Do **not** commit or push anything.

## Example invocation

```text
/pr-description
```

Output is the filled template, ready to paste.
