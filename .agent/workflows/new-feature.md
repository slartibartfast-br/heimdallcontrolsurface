---
description: Implement a new feature using the Heimdall pipeline
---

# New Feature Workflow — HEIMDALL Control Surface

## Phases

1. **Plan** — Explore the codebase, design the approach, write a plan
2. **Implement** — Write code and tests following the approved plan
3. **Ship** — Run full test suite, commit, push, create PR

## Before Starting

- Read CLAUDE.md for project rules
- Check `git status` — working tree must be clean
- Read the Plane issue for requirements and acceptance criteria

## Implementation Rules

- Functions under 50 lines
- Write tests alongside code
- Conventional commits: `feat(HCS-N): description`
- Run tests via Docker before shipping
