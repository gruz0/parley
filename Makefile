# Parley — convenience commands.
# Run `make` or `make help` to see everything.
#
# Paths with spaces MUST be quoted. Note: ~ is NOT expanded inside quotes, so for
# such paths spell out the home dir:  make transcribe FILE="$HOME/Videos/Recordings/my call.mp4"

# Defaults (override on the command line, e.g. LANG=en)
LANG     ?=
SPEAKERS ?= 2 3
NAME     ?= Me
GUESTS   ?= 1 2

.DEFAULT_GOAL := help
.PHONY: help setup doctor transcribe tracks speakers rename clean

help:  ## Show this help
	@echo "Parley — commands:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Options: LANG=en|pt  SPEAKERS='min max'  NAME='Your Name'  GUESTS='min max'  VERBOSE=1"
	@echo
	@echo "Examples:"
	@echo "  make transcribe FILE=\"~/Videos/Recordings/call.mp4\" LANG=pt"
	@echo "  make tracks FILE=\"~/Videos/Recordings/call.mkv\" LANG=en NAME=Alex"
	@echo "  make speakers FILE=\"call\""
	@echo "  make rename FILE=\"call\" MAP=\"SPEAKER_00=Alex SPEAKER_01=Bob\""

setup:  ## Install dependencies (ffmpeg, venv, whisperx) — Debian/Ubuntu, one time
	@./setup.sh

doctor:  ## Preflight check: ffmpeg, GPU, venv, token, model readiness
	@./doctor.sh

transcribe:  ## Transcribe a single-track recording  (FILE=... [LANG=] [SPEAKERS='2 3'])
	@test -n "$(FILE)" || { echo "Usage: make transcribe FILE=<path> [LANG=pt] [SPEAKERS='2 3']"; exit 1; }
	@./transcribe.sh "$(FILE)" "$(LANG)" $(SPEAKERS)

tracks:  ## Per-track OBS multi-track recording  (FILE=... [LANG=] [NAME=Alex] [GUESTS='1 2'])
	@test -n "$(FILE)" || { echo "Usage: make tracks FILE=<path> [LANG=en] [NAME=Alex] [GUESTS='1 2']"; exit 1; }
	@./transcribe-tracks.sh "$(FILE)" "$(LANG)" "$(NAME)" $(GUESTS)

speakers:  ## Preview detected speakers for a transcript  (FILE=<basename>)
	@test -n "$(FILE)" || { echo "Usage: make speakers FILE=<basename>"; exit 1; }
	@./rename-speakers.sh "$(FILE)"

rename:  ## Rename speakers  (FILE=<basename> MAP='SPEAKER_00=Alex SPEAKER_01=Bob')
	@test -n "$(FILE)" || { echo "Usage: make rename FILE=<basename> MAP='SPEAKER_00=Alex ...'"; exit 1; }
	@test -n "$(MAP)"  || { echo "Set MAP='SPEAKER_00=Alex SPEAKER_01=Bob'"; exit 1; }
	@./rename-speakers.sh "$(FILE)" $(MAP)

clean:  ## Remove *.bak backups and *.log files
	@rm -f transcripts/*.bak *.log && echo "Removed backups and logs."
