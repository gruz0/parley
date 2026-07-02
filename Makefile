# Parley — convenience commands.
# Run `make` or `make help` to see everything.
#
# Paths with spaces MUST be quoted. Note: ~ is NOT expanded inside quotes, so for
# such paths spell out the home dir:  make transcribe FILE="$HOME/Videos/Recordings/my call.mp4"

# Defaults (override on the command line, e.g. LANG=en). SPEAKERS / GUESTS empty
# = auto-detect the speaker count.
#
# Use `=` / an origin guard, NOT `?=`: with `?=` a same-named shell variable would
# leak in. Notably $LANG is the POSIX locale (e.g. en_US.UTF-8), which Whisper
# rejects, and $NAME is often set too — both would silently override the default.
SPEAKERS =
NAME     = Me
GUESTS   =

# Transcription language: honor only an explicit command-line `LANG=xx`; ignore the
# inherited shell locale (and leave $LANG itself untouched for child processes).
LANGARG := $(if $(filter command line,$(origin LANG)),$(LANG))

.DEFAULT_GOAL := help
.PHONY: help setup doctor transcribe speakers rename clean

help:  ## Show this help
	@echo "Parley — commands:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Options: LANG=en|pt  NAME='Your Name'  VERBOSE=1  (speaker count is auto-detected;"
	@echo "         override with SPEAKERS='min max', or GUESTS='min max' to force per-track mode)"
	@echo
	@echo "Examples:"
	@echo "  make transcribe FILE=\"~/Videos/Recordings/call.mp4\" LANG=pt        # auto-detects everything"
	@echo "  make transcribe FILE=\"~/Videos/Recordings/call.mp4\" SPEAKERS='2 2' # force single-track headcount"
	@echo "  make transcribe FILE=\"~/Videos/Recordings/call.mkv\" NAME=Alex GUESTS='1 1' # force per-track"
	@echo "  make speakers FILE=\"call\""
	@echo "  make rename FILE=\"call\" MAP=\"SPEAKER_00=Alex SPEAKER_01=Bob\""

setup:  ## Install dependencies (ffmpeg, venv, whisperx) — Debian/Ubuntu, one time
	@./setup.sh

doctor:  ## Preflight check: ffmpeg, GPU, venv, token, model readiness
	@./doctor.sh

transcribe:  ## Transcribe any recording — auto-detects tracks & speakers  (FILE=... [LANG=])
	@test -n "$(FILE)" || { echo "Usage: make transcribe FILE=<path> [LANG=pt] [NAME=Alex] [SPEAKERS='2 2'] [GUESTS='1 1']"; exit 1; }
	@PARLEY_NAME="$(NAME)" PARLEY_GUESTS="$(GUESTS)" ./transcribe.sh "$(FILE)" "$(LANGARG)" $(SPEAKERS)

speakers:  ## Preview detected speakers for a transcript  (FILE=<basename>)
	@test -n "$(FILE)" || { echo "Usage: make speakers FILE=<basename>"; exit 1; }
	@./rename-speakers.sh "$(FILE)"

rename:  ## Rename speakers  (FILE=<basename> MAP='SPEAKER_00=Alex SPEAKER_01=Bob')
	@test -n "$(FILE)" || { echo "Usage: make rename FILE=<basename> MAP='SPEAKER_00=Alex ...'"; exit 1; }
	@test -n "$(MAP)"  || { echo "Set MAP='SPEAKER_00=Alex SPEAKER_01=Bob'"; exit 1; }
	@./rename-speakers.sh "$(FILE)" $(MAP)

clean:  ## Remove *.bak backups and *.log files
	@rm -f transcripts/*.bak *.log && echo "Removed backups and logs."
