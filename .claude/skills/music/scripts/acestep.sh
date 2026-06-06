#!/usr/bin/env bash
#
# acestep.sh — render a song spec (.md) to a WAV via a local ACE-Step API.
#
# Usage:
#   .claude/skills/music/scripts/acestep.sh songs/my-song.md [out.wav]
#
# Reads the YAML front-matter (`style`, `length`, `slug`) and the lyrics body
# (everything after the `# LYRICS` line) from the Markdown file, POSTs them to
# an ACE-Step API server, and saves the resulting audio next to the .md file.
#
# Configuration (env vars):
#   ACESTEP_API_URL   Base URL of the ACE-Step server (default http://localhost:7865)
#   ACESTEP_ENDPOINT  Generation endpoint path     (default /generate)
#   ACESTEP_STEPS     Inference steps              (default 60)
#
# ACE-Step server flavours differ. This targets a simple JSON endpoint that
# accepts {tags, lyrics, audio_duration, infer_step} and returns audio. If your
# server speaks the Gradio /call/ protocol instead, point ACESTEP_ENDPOINT at it
# and adjust the payload below — the parsing of the .md file stays the same.
set -euo pipefail

API_URL="${ACESTEP_API_URL:-http://localhost:7865}"
ENDPOINT="${ACESTEP_ENDPOINT:-/generate}"
STEPS="${ACESTEP_STEPS:-60}"

die() { echo "error: $*" >&2; exit 1; }

[[ $# -ge 1 ]] || die "usage: acestep.sh <song.md> [out.wav]"
SRC="$1"
[[ -f "$SRC" ]] || die "no such file: $SRC"

for bin in curl awk; do
  command -v "$bin" >/dev/null 2>&1 || die "required tool not found: $bin"
done

# --- parse front-matter (between the first two '---' lines) -----------------
fm_get() {
  # fm_get <key> : print the value of a front-matter scalar, quotes stripped
  awk -v key="$1" '
    /^---[[:space:]]*$/ { d++; next }
    d==1 && $0 ~ "^"key":" {
      sub("^"key":[[:space:]]*", "")
      gsub(/^"|"$/, "")
      print
      exit
    }' "$SRC"
}

STYLE="$(fm_get style)"
LENGTH="$(fm_get length)"
SLUG="$(fm_get slug)"
[[ -n "$STYLE" ]] || die "front-matter is missing a 'style' field"

# length "m:ss" -> seconds (default 180)
DURATION=180
if [[ "$LENGTH" =~ ^([0-9]+):([0-9]{1,2})$ ]]; then
  DURATION=$(( BASH_REMATCH[1] * 60 + BASH_REMATCH[2] ))
fi

# --- extract lyrics (everything after the '# LYRICS' marker) ----------------
LYRICS="$(awk 'f{print} /^#[[:space:]]*LYRICS/{f=1}' "$SRC")"
LYRICS="$(printf '%s' "$LYRICS" | sed -e 's/^[[:space:]]*$//' )"
[[ -n "${LYRICS//[$'\n\t ']/}" ]] || die "no lyrics found after '# LYRICS' marker"

# --- output path ------------------------------------------------------------
if [[ $# -ge 2 ]]; then
  OUT="$2"
else
  base="${SLUG:-$(basename "${SRC%.*}")}"
  OUT="$(dirname "$SRC")/${base}.wav"
fi

# --- server reachability ----------------------------------------------------
if ! curl -sf --max-time 5 "$API_URL/" >/dev/null 2>&1; then
  die "ACE-Step server not reachable at $API_URL — start it (see README.md) or use the Suno path."
fi

# --- build JSON payload (no jq dependency) ----------------------------------
json_escape() { python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'; }
TAGS_JSON="$(printf '%s' "$STYLE"  | json_escape)"
LYR_JSON="$(printf '%s'  "$LYRICS" | json_escape)"

PAYLOAD=$(cat <<JSON
{"tags": ${TAGS_JSON}, "lyrics": ${LYR_JSON}, "audio_duration": ${DURATION}, "infer_step": ${STEPS}}
JSON
)

echo "→ rendering '$SRC' via $API_URL$ENDPOINT (${DURATION}s, ${STEPS} steps)…" >&2

# Stream the audio response straight to the output file.
http_code="$(curl -s -o "$OUT" -w '%{http_code}' \
  -X POST "$API_URL$ENDPOINT" \
  -H 'Content-Type: application/json' \
  --data "$PAYLOAD")"

if [[ "$http_code" != "200" ]]; then
  echo "--- server response ---" >&2; cat "$OUT" >&2 || true; echo >&2
  rm -f "$OUT"
  die "ACE-Step returned HTTP $http_code"
fi

[[ -s "$OUT" ]] || die "ACE-Step returned an empty file"
echo "✓ wrote $OUT" >&2
echo "$OUT"
