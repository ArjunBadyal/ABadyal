#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MMT_JAR="${MMT_JAR:-/home/arjunbadyal/MMT/deploy/mmt.jar}"
ARCHIVE_ID="$(awk -F: '$1=="id"{print $2}' "$ROOT_DIR/META-INF/MANIFEST.MF" | tr -d '\r[:space:]')"
HOST="${HOST:-127.0.0.1}"
BUILD_ON_START="${BUILD_ON_START:-auto}"
DEFAULT_PORT=4382
PORT="${1:-$DEFAULT_PORT}"
STARTUP_FILE="$(mktemp /tmp/abadyal-mmt-stex.XXXXXX.msl)"
ARCHIVE_BROWSER_URL="http://$HOST:$PORT/:sTeX/browser?archive=$ARCHIVE_ID&filepath=index.xhtml"
DEFS_VIEWER_URL="http://$HOST:$PORT/:sTeX/browser?archive=$ARCHIVE_ID&filepath=ComputerScience/FormalLanguagesAndAutomata/FormalLanguagesAndAutomata_defs.xhtml"
NOTES_VIEWER_URL="http://$HOST:$PORT/:sTeX/browser?archive=$ARCHIVE_ID&filepath=ComputerScience/FormalLanguagesAndAutomata/DeterministicPDAsAndCFLMembership.xhtml"

cleanup() {
  rm -f "$STARTUP_FILE"
}

trap cleanup EXIT

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: $(basename "$0") [port]

Starts an MMT shell, loads the $ARCHIVE_ID archive, enables the sTeX server,
and starts the local web interface.

Defaults:
  port: $DEFAULT_PORT
  MMT_JAR: $MMT_JAR
  BUILD_ON_START: $BUILD_ON_START

Build behavior:
  BUILD_ON_START=auto builds the public Computer Science slice if xhtml output is missing.
  BUILD_ON_START=1 always builds before starting the server.
  BUILD_ON_START=0 starts the server without building.

Useful URLs:
  Archive index:
    http://$HOST:$DEFAULT_PORT/:sTeX/browser?archive=$ARCHIVE_ID&filepath=index.xhtml
  Formal Languages defs:
    http://$HOST:$DEFAULT_PORT/:sTeX/browser?archive=$ARCHIVE_ID&filepath=ComputerScience/FormalLanguagesAndAutomata/FormalLanguagesAndAutomata_defs.xhtml
  Deterministic PDA notes:
    http://$HOST:$DEFAULT_PORT/:sTeX/browser?archive=$ARCHIVE_ID&filepath=ComputerScience/FormalLanguagesAndAutomata/DeterministicPDAsAndCFLMembership.xhtml

Notes:
  Use the browser URLs above for the full viewer with semantic highlighting.
  Do not use /:sTeX/document?... directly unless you want the raw fragment endpoint.
EOF
  exit 0
fi

if [[ ! -f "$MMT_JAR" ]]; then
  echo "Missing MMT jar: $MMT_JAR" >&2
  exit 1
fi

RUN_BUILD=0
if [[ "$BUILD_ON_START" == "1" ]]; then
  RUN_BUILD=1
elif [[ "$BUILD_ON_START" == "auto" && ( ! -f "$ROOT_DIR/xhtml/index.xhtml" || ! -d "$ROOT_DIR/xhtml/ComputerScience" ) ]]; then
  RUN_BUILD=1
fi

{
  printf 'archive add %s\n' "$ROOT_DIR"

  if [[ -d /home/arjunbadyal/MathHub/sTeX/meta-inf ]]; then
    printf 'archive add %s\n' "/home/arjunbadyal/MathHub/sTeX/meta-inf"
  fi
  if [[ -d /home/arjunbadyal/MathHub/sTeX/MathTutorial ]]; then
    printf 'archive add %s\n' "/home/arjunbadyal/MathHub/sTeX/MathTutorial"
  fi
  if [[ -d /home/arjunbadyal/MathHub/sTeX/Documentation ]]; then
    printf 'archive add %s\n' "/home/arjunbadyal/MathHub/sTeX/Documentation"
  fi

  printf '%s\n' "extension info.kwarc.mmt.stex.STeXServer"

  if [[ "$RUN_BUILD" == "1" ]]; then
    printf 'build %s fullstex %s\n' "$ARCHIVE_ID" "index.tex"
    printf 'build %s fullstex %s\n' "$ARCHIVE_ID" "ComputerScience/ComputerScience_defs.tex"
    printf 'build %s fullstex %s\n' "$ARCHIVE_ID" "ComputerScience/FormalLanguagesAndAutomata/DeterministicPDAsAndCFLMembership.tex"
  fi

  printf '%s\n' "server on $PORT"
} > "$STARTUP_FILE"

cat <<EOF
Starting MMT+sTeX for archive $ARCHIVE_ID

Build on start:
  $RUN_BUILD

Archive index:
  $ARCHIVE_BROWSER_URL

Formal Languages defs:
  $DEFS_VIEWER_URL

Deterministic PDA notes:
  $NOTES_VIEWER_URL

Use the browser URLs above for the full viewer with semantic highlighting.
Avoid /:sTeX/document?... unless you explicitly want the raw fragment endpoint.

Press Ctrl-C to stop the server.
EOF

exec java -jar "$MMT_JAR" --file "$STARTUP_FILE" --shell
