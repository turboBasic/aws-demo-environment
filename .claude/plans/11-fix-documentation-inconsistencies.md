# Critical Audit: Human vs AI Documentation
<!-- pyml disable md029 -->

## Context

The user asked for a critical review of human-facing and AI-facing docs to find
inconsistencies and duplications, using [docs/ai-instructions.md](docs/ai-instructions.md)
as the single source of truth (SSoT) for AI instructions (consumed by both Claude Code
and GitHub Copilot). Short duplications should be left alone; big ones should be
replaced with references to the AI SSoT.

The goal: correct factual drift, collapse redundant prose, and keep Copilot-friendly
ergonomics (no bloat, plain markdown links instead of `@`-references where Copilot reads).

## Findings

### A. Factual inconsistencies (must-fix — SSoT is wrong)

All located in [docs/ai-instructions.md](docs/ai-instructions.md):

1. **Line 14** — "Ephemeral 1-day AWS demo environment (VPC, ALB, NAT, EC2)…" misses
   half the stack. Actual resources: VPC + ALB + **ECS Fargate** + **CloudFront** +
   **S3 static site** + **Obsidian vaults** + **generic storage (MFA)**. Optional EC2
   web instance. NAT Gateway is optional (`create_nat_gateway = false` by default per
   [README.md:139](README.md#L139)).
2. **Line 14 + 24** — "Lambda container that runs `terraform destroy`" / "runs
   `terraform destroy` when TTL expires" is **wrong**. Verified against
   [bootstrap/lambda-destroyer/handler.py:29-416](bootstrap/lambda-destroyer/handler.py#L29-L416):
   the handler discovers TTL-tagged resources (ECS services, ALBs, target groups,
   EC2 instances, NAT gateways, Elastic IPs) and deletes them via AWS SDK calls.
   README's mermaid label is correct: "destroys only TTL-tagged resources"
   ([README.md:20](README.md#L20)).
3. **Line 20** — claims bootstrap creates "Secrets Manager, ECR repo". Verified false:
   `grep aws_secretsmanager|aws_ecr` on [bootstrap/](bootstrap/) returns nothing.
   Bootstrap actually creates: S3 state bucket, S3 bootstrap backup bucket, DynamoDB
   lock table, Lambda destroyer, EventBridge rule, IAM roles (per
   [bootstrap/README.md:41-48](bootstrap/README.md#L41-L48) and the `.tf` files).
4. **Line 18-22** — Header says "Two-stage architecture" but the list has 3 numbered
   items (item 3 is actually a restatement, not a third stage).

### B. Other inconsistencies

5. **[README.md:96-106](README.md#L96-L106)** — the Modules table lists only 8 of 10
   modules. Missing: `web-instance` and `networking-nat-gw` (both present in
   [modules/](modules/) and documented in
   [docs/ai-instructions.md:150-161](docs/ai-instructions.md#L150-L161)).

### C. Duplications — big enough to consolidate

6. **Architecture description** appears in three places with differing scope:
   - [README.md:7-61](README.md#L7-L61) — rich mermaid diagram (unique visual content).
   - [docs/ai-instructions.md:16-26](docs/ai-instructions.md#L16-L26) — text summary
     (the wrong one from finding A).
   - [.claude/plans/04-00-aws-demo-environment-architecture.md](.claude/plans/04-00-aws-demo-environment-architecture.md)
     — design decisions (referenced by ai-instructions).

   Since the three serve different purposes (visual / AI-text / design rationale),
   they're **not a harmful duplication** — but the ai-instructions text must be fixed
   (finding A) and should point to the README diagram and the architecture plan
   rather than re-stating resource lists that will drift.

### D. Duplications — short / acceptable (leave alone)

- **Make targets** — brief primer in [README.md:69-81](README.md#L69-L81), full
  reference in [docs/ai-instructions.md:56-82](docs/ai-instructions.md#L56-L82). README
  already defers at line 83-84. Acceptable primer/reference split.
- **Terraform commands** — [README.md:120-128](README.md#L120-L128) is a usage snippet;
  [docs/ai-instructions.md:111-121](docs/ai-instructions.md#L111-L121) is a command
  reference. Different purposes.
- **AWS auth** — README one-liner → ai-instructions section → skill. Correct layering.
- **"Shared skills are in `.claude/skills/`"** — appears in both ai-instructions and
  `.github/copilot-instructions.md`. Intentional top-level signpost for Copilot.

### E. Non-issues (verified, no action)

- `CLAUDE.md` is a thin wrapper around `@docs/ai-instructions.md` with only Claude-
  specific additions. Good.
- `.github/copilot-instructions.md` is a thin wrapper with a markdown link. Good.
- Module READMEs are not duplicated by AI docs.
- Project Structure tree in ai-instructions.md is complete (all 10 modules listed,
  verified by globbing [modules/](modules/)).
- Pre-commit hooks, Code Style, Commit conventions — all live in ai-instructions with
  README/CLAUDE.md deferring. No duplication.

## Recommended changes

### 1. Fix [docs/ai-instructions.md](docs/ai-instructions.md) Architecture section (lines 12-26)

Replace the current "Ephemeral 1-day AWS demo environment (VPC, ALB, NAT, EC2)…"
paragraph and the 3-item numbered list with:

- Correct one-line summary naming the real components (or better, a non-enumerating
  description — "web-facing ephemeral demo exposed via CloudFront/ALB, with optional
  EC2/NAT, plus persistent S3-backed storage for Obsidian vaults and generic S3 use").
- Clean two-stage description:
  1. `bootstrap/` (persistent) — S3 state backend, DynamoDB locks, Lambda destroyer,
     EventBridge hourly schedule, IAM. **Remove** the `Secrets Manager, ECR repo` claim.
  2. Root module `/` (ephemeral demo) — networking, ALB, ECS Fargate, optional EC2,
     CloudFront/S3, Obsidian/generic storage.
- Correct Lambda description: "Lambda destroyer checks state-file age hourly; when TTL
  expires, it deletes TTL-tagged resources (ALB, ECS, NAT Gateway, EIPs, instances,
  target groups) via AWS SDK calls." **Do not** say `terraform destroy`.
- Add a one-line pointer to [README.md#architecture](README.md#architecture) for the
  visual diagram, keep existing pointer to the architecture plan.

### 2. Fix [README.md](README.md) Modules table (lines 96-105)

Add the two missing rows:

| Module              | Source                        | Purpose                                          |
| ------------------- | ----------------------------- | ------------------------------------------------ |
| `networking_nat_gw` | `./modules/networking-nat-gw` | NAT Gateway and private-subnet routing           |
| `web_instance`      | `./modules/web-instance`      | Optional EC2 web instance (httpd via cloud-init) |

Confirm the exact module call names by grepping [main.tf](main.tf) before edit (ai-instructions describes them as snake_case — verify actual usage).

### 3. Minor cross-reference polish (optional, skip if noisy)

- [docs/ai-instructions.md:86-93](docs/ai-instructions.md#L86-L93) can keep the current
  two-line `Cargonautica` profile snippet; the skill reference below it is already correct.

### 4. Nothing else to change

- No README → ai-instructions de-duplication is needed — the current primer/reference
  split is working.
- Bootstrap/README is accurate as-is.
- `.github/copilot-instructions.md` and `CLAUDE.md` are already minimal wrappers.

## Critical files to modify

- [docs/ai-instructions.md](docs/ai-instructions.md) — Architecture section rewrite (lines 12-26).
- [README.md](README.md) — Modules table additions (lines 96-105).

## Verification

After changes:

1. `make lint` — ensures `pymarkdown` passes on the edited markdown.
2. Manually read the rewritten Architecture block and confirm it matches:
   - [bootstrap/lambda-destroyer/handler.py](bootstrap/lambda-destroyer/handler.py)
     (Lambda behavior)
   - [bootstrap/*.tf](bootstrap/) (what bootstrap creates)
   - [main.tf](main.tf) (what root creates)
3. `grep -r "Secrets Manager\|terraform destroy\|ECR repo" docs/` — should find no
   stale references inside the AI SSoT after the edit.
4. Confirm the new README rows match the module block names used in
   [main.tf](main.tf) (e.g., `module "networking_nat_gw"` vs `module "web_instance"`).

## Out of scope

- Refactoring the architecture plan in `.claude/plans/` — it's a historical design doc.
- Reorganizing module READMEs.
- Changing the skills documentation.
