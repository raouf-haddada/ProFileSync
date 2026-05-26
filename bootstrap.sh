#!/usr/bin/env bash
# ProFileSync bootstrap — fetch the tool and run a subcommand in one shot.
#
# Install the autobackup service (root):
#   curl -fsSL <raw>/bootstrap.sh | sudo bash -s -- install \
#       --backup-remote git@github.com:you/profilesync-backups.git --user "$USER"
#
# Restore on a fresh machine (pull from the backup repo, pick what to restore):
#   curl -fsSL <raw>/bootstrap.sh | bash -s -- restore \
#       --remote git@github.com:you/profilesync-backups.git --branch <host>-<id> --pick
#
# Anything after `--` is passed straight to `profilesync`.
#
# Env:
#   PROFILESYNC_TOOL_REMOTE  tool repo to clone (default below)
#   PROFILESYNC_TOOL_REF     branch/tag to clone (default: main)
#   PROFILESYNC_KEEP=1       keep the temporary clone (for debugging)
set -euo pipefail

TOOL_REMOTE="${PROFILESYNC_TOOL_REMOTE:-git@github.com:raouf-haddada/ProFileSync.git}"
TOOL_REF="${PROFILESYNC_TOOL_REF:-main}"

command -v git >/dev/null 2>&1 || { echo "[bootstrap] git is required" >&2; exit 1; }

dest="$(mktemp -d -t profilesync-boot.XXXXXX)"
# shellcheck disable=SC2064
trap "[[ -n \"\${PROFILESYNC_KEEP:-}\" ]] || rm -rf -- '$dest'" EXIT

echo "[bootstrap] cloning $TOOL_REMOTE ($TOOL_REF) → $dest" >&2
git clone --depth 1 --branch "$TOOL_REF" "$TOOL_REMOTE" "$dest" >/dev/null 2>&1 \
  || git clone --depth 1 "$TOOL_REMOTE" "$dest" >/dev/null

tool="$dest/bin/profilesync"
[[ -x "$tool" ]] || chmod +x "$tool"

if [[ $# -eq 0 ]]; then
  echo "[bootstrap] no subcommand given — showing help" >&2
  exec "$tool" help
fi
exec "$tool" "$@"
