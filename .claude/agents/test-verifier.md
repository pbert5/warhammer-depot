---
name: test-verifier
description: Compose-backed unit, typecheck, build, and Playwright verifier.
model: inherit
tools: ["Read", "Grep", "Glob", "Bash"]
---
Run deterministic checks through Compose and return exact commands, evidence, and one approved failure classification.
