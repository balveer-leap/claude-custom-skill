#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # checks are single-quoted on purpose and run through eval
# Tests for scripts/clone-estate.sh against local repositories (no network).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/clone-estate.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
pass=0 failures=0

ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { failures=$((failures + 1)); printf '  FAIL %s\n' "$1"; }
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# A fake "server": $WORK/server/<owner>/<name>.git, each with a main and a dev branch.
make_repo() {
  local owner="$1" name="$2" src="$WORK/src/$1/$2"
  mkdir -p "$src" "$WORK/server/$owner"
  git -C "$src" init -q -b main
  printf '%s main\n' "$owner/$name" > "$src/README"
  git -C "$src" add README
  git -C "$src" -c user.name=t -c user.email=t@t commit -q -m init
  git -C "$src" checkout -q -b dev
  printf '%s dev\n' "$owner/$name" > "$src/README"
  git -C "$src" -c user.name=t -c user.email=t@t commit -q -am dev
  git -C "$src" checkout -q main
  git clone -q --bare "$src" "$WORK/server/$owner/$name.git"
}
make_repo acme billing
make_repo acme ledger
make_repo acme web
make_repo other ledger

# Run the script in a fresh "checkout" directory; prints its exit code.
run() {
  local dir="$WORK/run-$1"; shift
  rm -rf "$dir"; mkdir -p "$dir/.git/info"; : > "$dir/out"
  (cd "$dir" && env -i PATH="$PATH" HOME="$HOME" GIT_BASE_URL="file://$WORK/server" \
      CURRENT_REPO=acme/web GITHUB_OUTPUT="$dir/out" CLONE_RETRIES=1 "$@" \
      bash "$SCRIPT" > "$dir/log" 2>&1)
  echo $?
}

echo "clone-estate.sh"

code=$(run basic ESTATE_REPOS="billing, acme/ledger@dev
https://github.com/acme/web acme/billing")
d="$WORK/run-basic"
check "exits 0 when every sibling clones" '[ "$code" = 0 ]'
check "bare name uses the current owner" '[ -f "$d/.estate/billing/README" ]'
check "@ref clones that branch" 'grep -q "acme/ledger dev" "$d/.estate/ledger/README"'
check "skips the repository under review" '[ ! -e "$d/.estate/web" ]'
check "de-duplicates repeated entries" 'grep -qx "expected=2" "$d/out"'
check "reports the clone count" 'grep -qx "cloned=2" "$d/out"'
check "removes .git from clones" '[ ! -e "$d/.estate/billing/.git" ]'
check "adds .estate to .git/info/exclude" 'grep -qx "/.estate/" "$d/.git/info/exclude"'

code=$(run samename ESTATE_REPOS="acme/ledger other/ledger")
d="$WORK/run-samename"
check "same name from two owners does not collide" \
  '[ "$code" = 0 ] && [ -f "$d/.estate/ledger/README" ] && grep -q "other/ledger" "$d/.estate/other__ledger/README"'

code=$(run missing ESTATE_REPOS="billing nosuchrepo")
check "fails when a sibling is missing (require_estate=true)" '[ "$code" = 1 ]'
check "names the missing sibling" 'grep -q "acme/nosuchrepo" "$WORK/run-missing/log"'

code=$(run lenient ESTATE_REPOS="billing nosuchrepo" REQUIRE_ESTATE=false)
check "continues when require_estate=false" '[ "$code" = 0 ] && grep -qx "cloned=1" "$WORK/run-lenient/out"'

code=$(run badref ESTATE_REPOS="billing@nosuchbranch")
check "fails on a branch that does not exist" '[ "$code" = 1 ]'

code=$(run empty ESTATE_REPOS="")
check "empty list = single-repo mode, exit 0" '[ "$code" = 0 ] && grep -qx "expected=0" "$WORK/run-empty/out"'

code=$(run inject ESTATE_REPOS='acme/billing;touch${IFS}pwned')
check "rejects entries that are not repository ids" '[ "$code" = 1 ] && [ ! -e "$WORK/run-inject/pwned" ]'

code=$(run badrefchars ESTATE_REPOS='billing@$(id)')
check "rejects refs with shell characters" '[ "$code" = 1 ]'

code=$(run token ESTATE_REPOS="billing" ESTATE_TOKEN="s3cr3t-token-value")
check "never writes the token to disk" \
  '[ "$code" = 0 ] && ! grep -rqs "s3cr3t-token-value" "$WORK/run-token"'

printf '\n%d passed, %d failed\n' "$pass" "$failures"
[ "$failures" -eq 0 ]
