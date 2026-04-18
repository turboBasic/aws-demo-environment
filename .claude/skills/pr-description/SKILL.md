---
name: pr-description
description: Generate a PR description, create a feature branch if needed, and submit the PR to GitHub
user-invocable: true
model: Sonnet
allowed-tools: Bash(git log:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(git branch:*), Bash(git checkout:*), Bash(git push:*), Bash(gh pr create:*), Bash(gh pr view:*), Read
---

# PR Description Generator

## Purpose

Generate a pull request description filled from the repo's PR template, then create and
submit the PR on GitHub via `gh pr create`.

Handles two starting states:

- **On a feature branch** — uses the current branch as-is.
- **On `main`** — derives a branch name from the unmerged commit subjects, creates and
  pushes that branch, then opens the PR.

## Steps

### 1. Identify unmerged commits

```bash
git log --oneline origin/main..HEAD
```

If this produces no output, tell the user there is nothing to PR and stop.

### 2. Determine (or create) the feature branch

**If the current branch is NOT `main`:** use it directly — go to step 3.

**If the current branch IS `main`:**

a. Read the commit subjects from the log above.

b. Derive a branch name from the first (or most representative) commit subject:

- Strip the Conventional Commits prefix (`fix:`, `feat(scope):`, etc.) and any leading punctuation.
- Lower-case, replace spaces and special characters with `-`, truncate to 50 characters.
- Prefix with the Conventional Commits type when present: `feat/`, `fix/`, `chore/`, etc.
- Example: `feat(ci): add actionlint hook` → `feat/add-actionlint-hook`

c. Create and push the branch:

   ```bash
   git checkout -b <derived-branch-name>
   git push -u origin <derived-branch-name>
   ```

### 3. Collect the diff

```bash
git log --oneline origin/main..HEAD
git diff origin/main...HEAD
```

### 4. Read the PR template

Read `.github/PULL_REQUEST_TEMPLATE.md` verbatim — this is the skeleton to fill in.

### 5. Derive the PR title

The title **must** follow Conventional Commits format: `type(scope): subject`
(imperative mood, no trailing period, ≤ 72 characters total).

- If all commits share the same type and scope, use that type/scope directly.
- If commits span multiple types, pick the dominant one (prefer `feat` > `fix` > others).
- If commits span multiple scopes, omit the scope parenthetical.
- The subject must be a concise imperative phrase summarising the PR, not a list of
  commit subjects.
- Examples: `feat(ci): add actionlint pre-commit hook`,
  `fix(bootstrap): correct IAM policy for Lambda destroyer`

### 6. Fill in the template

Replace every `{{ placeholder }}` and populate every section:

| Template section | What to write |
|-----------------|---------------|
| `## Description` | One concise paragraph: *what* changed and *why*. No implementation detail. |
| `## Changes`    | Bulleted list of concrete changes (files, resources, modules). Name them. |
| `## Testing`    | Check boxes that honestly apply; add a note if manual testing was done. |
| `## Checklist`  | Check every box that is satisfied; leave unchecked anything not yet done. |

### 7. Create and submit the PR

Run `gh pr create` with the title and filled-in description:

```bash
gh pr create \
  --base main \
  --title "<PR title>" \
  --body "$(cat <<'EOF'
<filled PR description>
EOF
)"
```

After the command succeeds, output the PR URL returned by `gh pr create`.

## Quality rules

- Do **not** invent changes that are not visible in the diff.
- Do **not** add extra sections beyond what the template defines.
- Keep the Description to ≤ 3 sentences.
- The Changes list must use plain Markdown bullets (`-`), not numbered lists.
- Preserve every HTML comment (`<!-- … -->`) from the template; do not delete them.
- Do **not** commit or amend any existing commits.
- If `gh pr create` fails because the branch already has an open PR, report the existing
  PR URL and stop — do not create a duplicate.

## Example invocations

```text
/pr-description
```

Works from `main` (creates a branch) or from any feature branch.
