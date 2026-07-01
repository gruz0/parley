# CLAUDE.md

This project keeps its AI-assistant guidance in **AGENTS.md** (the cross-tool standard) so every
assistant shares one source of truth. Claude Code doesn't read `AGENTS.md` natively yet, so it's
imported below.

@AGENTS.md

Reminders for Claude Code specifically:

- Never read or commit `.env` or anything under `transcripts/` — private call data.
- After editing Markdown run `bun run format`; before finishing, `shellcheck *.sh` and `ruff check .`
  must pass (CI enforces all three).
