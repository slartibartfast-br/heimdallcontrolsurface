---
description: Fix a Plane issue using the Heimdall pipeline
---

# Fix Issue Workflow — HEIMDALL Control Surface

## Phases

1. **Plan** — Read the issue, explore the codebase, write a plan
2. **Implement** — Write code following the approved plan
3. **Ship** — Run tests, commit, push, create PR

## Before Starting

- Read CLAUDE.md for project rules
- Check `git status` — working tree must be clean
- Read the Plane issue for requirements

## Implementation Rules

- Functions under 50 lines
- Conventional commits: `fix(HCS-N): description`
- Run tests via Docker before shipping
