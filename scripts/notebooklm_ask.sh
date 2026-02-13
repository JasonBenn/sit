#!/usr/bin/env bash
# Ask a NotebookLM notebook a question.
#
# Usage:
#   notebooklm_ask.sh "What is emptiness?"
#   notebooklm_ask.sh "What is emptiness?" --mode concise
#   notebooklm_ask.sh "What is emptiness?" --notebook d0799cf2
#   notebooklm_ask.sh "What is emptiness?" --new
#
# Modes: default, concise, detailed, learning-guide
# If no notebook is specified, uses the currently active one (set with `notebooklm use <id>`).
#
# Known notebooks:
#   d0799cf2  Rigdzin

set -euo pipefail

QUESTION="${1:?Usage: notebooklm_ask.sh \"question\" [--mode concise] [--notebook ID] [--new]}"
shift

MODE=""
NOTEBOOK=""
NEW_FLAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --notebook) NOTEBOOK="$2"; shift 2 ;;
    --new) NEW_FLAG="--new"; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Switch notebook if specified
if [[ -n "$NOTEBOOK" ]]; then
  notebooklm use "$NOTEBOOK" > /dev/null 2>&1
fi

# Configure mode if specified
if [[ -n "$MODE" ]]; then
  notebooklm configure --mode "$MODE"
fi

# Ask the question
notebooklm ask $NEW_FLAG "$QUESTION"
