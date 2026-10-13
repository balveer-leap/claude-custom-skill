#!/usr/bin/env bash
# Clone the sibling repositories of an estate, read-only, into $ESTATE_DIR.
#
# Environment:
#   ESTATE_REPOS     sibling repos, separated by spaces, commas or newlines. Each entry is
#                    `name`, `owner/name`, `https://github.com/owner/name[.git]`, optionally
#                    followed by `@ref` (branch or tag). A bare `name` uses DEFAULT_OWNER.
#   CURRENT_REPO     `owner/name` of the repository under review; it is skipped if listed.
#   DEFAULT_OWNER    owner for bare names (default: owner of CURRENT_REPO).
#   ESTATE_TOKEN     optional read token for private siblings. Sent as a per-command header,
#                    never written to disk.
#   ESTATE_DIR       destination (default: .estate).
#   REQUIRE_ESTATE   "true" (default): fail if any listed sibling cannot be cloned.
#   CLONE_RETRIES    attempts per repo (default: 3).
#   CLONE_TIMEOUT    seconds per attempt (default: 300).
#   GIT_BASE_URL     default https://github.com (overridable for tests and GHES).
#
# Writes `expected=` and `cloned=` to $GITHUB_OUTPUT when it is set.
set -euo pipefail

ESTATE_DIR="${ESTATE_DIR:-.estate}"
REQUIRE_ESTATE="${REQUIRE_ESTATE:-true}"
CLONE_RETRIES="${CLONE_RETRIES:-3}"
CLONE_TIMEOUT="${CLONE_TIMEOUT:-300}"
GIT_BASE_URL="${GIT_BASE_URL:-https://github.com}"
CURRENT_REPO="${CURRENT_REPO:-}"
DEFAULT_OWNER="${DEFAULT_OWNER:-${CURRENT_REPO%%/*}}"
ESTATE_TOKEN="${ESTATE_TOKEN:-}"

log() { printf '%s\n' "$*"; }
fail() { printf '::error::%s\n' "$*" >&2; exit 1; }

output() {
  if [ -n "${GITHUB_OUTPUT:-}" ]; then printf '%s=%s\n' "$1" "$2" >> "$GITHUB_OUTPUT"; fi
}

# Run a command with a timeout when one is available (GNU timeout or gtimeout).
with_timeout() {
  if command -v timeout >/dev/null 2>&1; then timeout "$CLONE_TIMEOUT" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$CLONE_TIMEOUT" "$@"
  else "$@"; fi
}

# Normalise one entry to "owner/name<TAB>ref". Rejects anything that is not a plain repo id.
normalise() {
  local entry="$1" ref="" repo
  entry="${entry#https://github.com/}"
  entry="${entry#http://github.com/}"
  entry="${entry#github.com/}"
  if [[ "$entry" == *@* ]]; then ref="${entry#*@}"; entry="${entry%%@*}"; fi
  entry="${entry%/}"
  entry="${entry%.git}"
  if [[ "$entry" != */* ]]; then
    [ -n "$DEFAULT_OWNER" ] || fail "'$entry' has no owner and DEFAULT_OWNER is not set"
    entry="$DEFAULT_OWNER/$entry"
  fi
  repo="$entry"
  [[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail "not a repository: '$1'"
  [[ -z "$ref" || "$ref" =~ ^[A-Za-z0-9_./-]+$ ]] || fail "not a branch or tag: '$ref' in '$1'"
  printf '%s\t%s\n' "$repo" "$ref"
}

clone_one() {
  local repo="$1" ref="$2" dest="$3" url="$GIT_BASE_URL/$1.git" attempt=1
  # actions/checkout leaves this repo's job token as an extraheader in git config.
  # An empty value clears it, so siblings never receive two credentials.
  local -a git_cfg=(-c "http.${GIT_BASE_URL}/.extraheader=" -c "credential.helper=")
  local -a args=(clone --depth 1 --quiet --no-tags)
  [ -n "$ref" ] && args+=(--branch "$ref")
  while [ "$attempt" -le "$CLONE_RETRIES" ]; do
    rm -rf "$dest"
    if GIT_TERMINAL_PROMPT=0 with_timeout git "${git_cfg[@]}" "${args[@]}" "$url" "$dest" 2>/dev/null; then
      return 0
    fi
    if [ -n "$ESTATE_TOKEN" ]; then
      local header
      header="AUTHORIZATION: basic $(printf 'x-access-token:%s' "$ESTATE_TOKEN" | base64 | tr -d '\n')"
      if GIT_TERMINAL_PROMPT=0 with_timeout git "${git_cfg[@]}" \
          -c "http.${GIT_BASE_URL}/.extraheader=$header" \
          "${args[@]}" "$url" "$dest" 2>/dev/null; then
        return 0
      fi
    fi
    attempt=$((attempt + 1))
    [ "$attempt" -le "$CLONE_RETRIES" ] && sleep $((attempt * 2))
  done
  rm -rf "$dest"
  return 1
}

mkdir -p "$ESTATE_DIR"
# Keep the clones out of `git status` so they never look like part of the change.
if [ -d .git/info ] && ! grep -qxF "/$ESTATE_DIR/" .git/info/exclude 2>/dev/null; then
  printf '/%s/\n' "$ESTATE_DIR" >> .git/info/exclude
fi

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

expected=0 cloned=0 failed="" seen=" "
current="$(lower "$CURRENT_REPO")"
# shellcheck disable=SC2086  # split on spaces, commas and newlines on purpose
for entry in $(printf '%s' "${ESTATE_REPOS:-}" | tr ',\n' '  '); do
  norm="$(normalise "$entry")" || exit 1
  repo="${norm%%$'\t'*}"
  ref="${norm#*$'\t'}"
  key="$(lower "$repo")"
  [ "$key" = "$current" ] && continue
  case "$seen" in *" $key "*) continue ;; esac
  seen="$seen$key "
  expected=$((expected + 1))
  name="${repo#*/}"
  dest="$ESTATE_DIR/$name"
  [ -e "$dest" ] && dest="$ESTATE_DIR/${repo%%/*}__$name"
  if clone_one "$repo" "$ref" "$dest"; then
    # No history and no git config: nothing in the clone can carry a credential.
    rm -rf "$dest/.git"
    cloned=$((cloned + 1))
    log "  cloned $repo${ref:+@$ref} -> $dest"
  else
    failed="$failed $repo${ref:+@$ref}"
    log "::warning::could not clone $repo${ref:+@$ref} (is it readable with the token provided?)"
  fi
done

output expected "$expected"
output cloned "$cloned"

if [ "$expected" -eq 0 ]; then
  log "::notice::No sibling repositories configured; reviewing this repository on its own."
  exit 0
fi
if [ -n "$ESTATE_TOKEN" ] && grep -rqsF "$ESTATE_TOKEN" "$ESTATE_DIR"; then
  fail "ESTATE_TOKEN found inside $ESTATE_DIR; stopping before Claude runs"
fi
log "estate: $cloned/$expected sibling repositories in $ESTATE_DIR"
if [ -n "$failed" ] && [ "$REQUIRE_ESTATE" = "true" ]; then
  fail "missing siblings:$failed. Refusing to review without the estate (set require_estate: false to continue)."
fi
