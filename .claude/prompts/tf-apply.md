---
name: tf-apply
description: Run terraform apply with AWS auth check — shows plan first and requires explicit confirmation before applying
---

# Terraform Apply

Apply the Terraform root module with an auth check and plan review before touching infrastructure.

## Steps

1. Use the `aws` skill to verify authentication is valid before proceeding.

2. Use the `terraform` skill to run a plan first:

   ```bash
   mise exec -- terraform plan -out=tfplan.tmp
   ```

3. Summarise the plan output (adds, changes, destroys). If there are **any destroys or replacements**, list them explicitly and **stop here** — ask the user to confirm before continuing.

4. Only after the user confirms (or if there are no destructive changes): apply the saved plan:

   ```bash
   mise exec -- terraform apply tfplan.tmp
   ```

5. Clean up the plan file:

   ```bash
   rm -f tfplan.tmp
   ```

6. Report the apply outcome — outputs and any errors.
