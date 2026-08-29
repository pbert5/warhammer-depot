Read `AGENTS.md` first. This file only adds Claude Code bootstrap notes; the
shared operating model, ownership boundaries, and Compose-first contract live
there and in `docs/agent-workflows.md`.

The repository root owns integration Compose, Docker, networking, launcher,
and submodule gitlinks. `vendor/depot` and `vendor/mundamanager` remain
independent repositories with their own standalone Compose topologies.
