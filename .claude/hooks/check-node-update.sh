#!/usr/bin/env bash
# SessionStart hook: at most once a month, check nodejs.org for a Node.js
# release newer than the embedded NODE_VERSION and, if there is one, ask
# Claude to offer the upgrade. Plain stdout from a SessionStart hook is added
# to Claude's context. Always exits 0 so a failed check never blocks a session.
#
# Set NODE_UPDATE_CHECK_FORCE=1 to skip the once-a-month throttle.
set -uo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
WORKFLOW="$ROOT/.github/workflows/publish.yml"
STAMP="$ROOT/.claude/.node-update-check"
INTERVAL=$((30 * 24 * 60 * 60))

# Platform archives scripts/download-node.sh needs, as named in index.tab.
REQUIRED_FILES="win-x64-zip win-arm64-zip linux-x64 linux-arm64 osx-x64-tar osx-arm64-tar"

current="$(awk -F'"' '/^[[:space:]]*NODE_VERSION:/ { print $2; exit }' "$WORKFLOW" 2>/dev/null)"
[[ "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 0

now="$(date +%s)"
if [[ -z "${NODE_UPDATE_CHECK_FORCE:-}" ]]; then
  # The last check is the newer of this checkout's stamp and the last commit
  # that changed NODE_VERSION, so fresh clones (cloud sessions) are throttled too.
  last_check="$(cat "$STAMP" 2>/dev/null)"
  [[ "$last_check" =~ ^[0-9]+$ ]] || last_check=0
  last_bump="$(git -C "$ROOT" log -1 --format=%ct -G '^[[:space:]]*NODE_VERSION:' -- .github/workflows/publish.yml 2>/dev/null)"
  [[ "$last_bump" =~ ^[0-9]+$ ]] || last_bump=0
  (( last_bump > last_check )) && last_check=$last_bump
  (( now - last_check < INTERVAL )) && exit 0
fi

index="$(curl -fsSL --max-time 10 https://nodejs.org/dist/index.tab 2>/dev/null)" || exit 0
{ echo "$now" > "$STAMP"; } 2>/dev/null

# Newest release that ships every archive we embed: "<version>\t<date>\t<lts>".
latest="$(awk -F'\t' -v need="$REQUIRED_FILES" '
  BEGIN { n = split(need, files, " ") }
  NR > 1 {
    for (i = 1; i <= n; i++) if (index("," $3 ",", "," files[i] ",") == 0) next
    sub(/^v/, "", $1)
    print $1 "\t" $2 "\t" $10
    exit
  }' <<<"$index")"
IFS=$'\t' read -r latest_version latest_date latest_lts <<<"$latest"
[[ "${latest_version:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 0

version_gt() {
  local IFS=.
  local -a a=($1) b=($2)
  local i
  for i in 0 1 2; do
    (( a[i] > b[i] )) && return 0
    (( a[i] < b[i] )) && return 1
  done
  return 1
}
version_gt "$latest_version" "$current" || exit 0

if [[ "$latest_lts" == "-" || -z "$latest_lts" ]]; then
  status="Current, not LTS"
else
  status="LTS \"$latest_lts\""
fi

files="$(git -C "$ROOT" grep -l -F "$current" 2>/dev/null | tr '\n' ' ')"
[[ -n "$files" ]] || files=".github/workflows/publish.yml README.md src/NodeJs.Embedded/README.md scripts/download-node.sh"

echo "Monthly Node.js check: a newer Node.js is available for the embedded runtime: $current -> $latest_version (released $latest_date, $status)."
if [[ "${current%%.*}" != "${latest_version%%.*}" ]]; then
  echo "This is a new major version. Review https://github.com/nodejs/node/blob/main/doc/changelogs/CHANGELOG_V${latest_version%%.*}.md for breaking changes and mention them to the user."
fi
cat <<EOF
Tell the user about this at the start of your first reply and offer to do the upgrade (if they already asked for an upgrade or general maintenance, just do it). Upgrade steps:
1. Replace $current with $latest_version in: $files
2. Run ./scripts/download-node.sh $latest_version to verify all six platform archives download, and check that the binary for this host reports v$latest_version.
3. Commit as "Upgrade embedded Node.js to $latest_version".
EOF
exit 0
