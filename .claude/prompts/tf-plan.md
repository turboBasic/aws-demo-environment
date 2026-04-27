---
name: tf-plan
description: Run terraform plan with AWS auth check and summarise the proposed changes
---

# Terraform Plan

Run a Terraform plan for the root module and summarise the output.

## Steps

1. Use the `aws` skill to verify authentication is valid before proceeding.

2. Use the `terraform` skill to run:

   ```bash
   mise exec -- terraform plan
   ```

3. Summarise the plan output:
   - List resources to be **added**, **changed**, and **destroyed** (counts + names).
   - Call out any **destructive changes** (destroy or replacement) explicitly — these need user confirmation before applying.
   - If the plan shows no changes, say so clearly.

4. Do **not** run `terraform apply` — stop after summarising the plan.
