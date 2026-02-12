---
name: terraform
description: Find terraform executable to run terraform commands
user-invocable: false
model: Haiku
allowed-tools: Bash(*/find-terraform.sh)
---

In order to find terraform executable, execute script [find-terraform.sh](scripts/find-terraform.sh). It returns the path to terraform executable or error message if it is not found.
