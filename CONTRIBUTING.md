# Contributing to Parley

Thanks for your interest! Parley is a small, personal tool that I ([@gruz0](https://github.com/gruz0))
built to transcribe my own founder & investor calls locally. It's shared in the hope it's useful to
others — contributions are welcome, especially the kind below.

## Good first contributions

- **Other-platform support.** Parley is only tested on **WSL2 + Debian 12 with an NVIDIA GPU**. If you
  get it running on macOS (Apple Silicon), native Linux, or a different GPU/CPU setup, a PR documenting
  the steps (or adapting the scripts) would help a lot.
- **Docs.** Clarifications, fixes, and better examples in the README are always appreciated.
- **Small features.** Things like batch-processing a folder, an AI-summary helper, or extra output
  formats. See [ROADMAP.md](ROADMAP.md) for fleshed-out ideas (each written to become an issue, with
  the 🥇 ones marked as good first issues), or open an issue to discuss first.

## Before you start

- **Open an issue** for anything non-trivial so we can agree on the approach before you write code.
- Keep it **simple and dependency-light.** Parley is intentionally a thin wrapper of shell scripts +
  one small Python file around [WhisperX](https://github.com/m-bain/whisperX). Please match that style
  rather than introducing a framework.
- **Using an AI assistant?** Point it at [AGENTS.md](AGENTS.md) (Claude Code reads
  [CLAUDE.md](CLAUDE.md), which imports it) — it captures the conventions and hard rules below.

## Dev setup

Follow the **Setup** section in the [README](README.md). In short:

```bash
sudo apt install -y ffmpeg python3 python3-venv python3-pip git
python3 -m venv ~/whisperx-env && source ~/whisperx-env/bin/activate && pip install whisperx
git clone https://github.com/gruz0/parley.git && cd parley
echo "HUGGING_FACE_ACCESS_TOKEN=hf_xxxx" > .env
```

## Testing your change

There's no formal test suite — Parley is verified by running it on a real recording. A quick way to
smoke-test without waiting on a full hour:

```bash
# make a ~45s clip from any recording
ffmpeg -ss 00:00:00 -t 45 -i "input.mp4" -vn -c:a aac clip.m4a

# run it through the pipeline
./transcribe.sh clip.m4a en 2 2
./rename-speakers.sh clip SPEAKER_00=A SPEAKER_01=B
```

Confirm the transcript appears under `transcripts/clip/` and the speaker labels look right. For quieter
or noisier output while debugging, toggle `VERBOSE=1`.

## Formatting docs

Markdown is formatted with [Prettier](https://prettier.io) via [Bun](https://bun.sh). Before opening a
PR that touches any `.md`:

```bash
bun install          # first time only — installs Prettier
bun run format       # format all markdown
bun run format:check # verify (used in review)
```

## Pull requests

1. Fork and create a branch: `git checkout -b my-change`.
2. Make your change; keep commits focused and the diff minimal.
3. Update the README if you changed behavior, flags, or setup.
4. Describe **what** and **why** in the PR, and mention what platform/GPU you tested on.

## Please don't commit

- **`.env`** (your Hugging Face token) — it's git-ignored; keep it that way.
- **`transcripts/`** — real call transcripts are private and git-ignored.
- Large media files or model weights.

If you use Claude Code, a committed `PreToolUse` hook (`.claude/`) blocks the assistant from opening
`.env` directly — belt-and-suspenders on top of `.gitignore`. It needs `jq` + GNU `grep -P` (Linux;
not stock macOS). Claude Code will ask you to approve the hook the first time.

## License

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
