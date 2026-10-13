#!/usr/bin/env bash
# The review method lives in prompts/. Check that every copy of it says the same thing.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
failures=0
ok() { printf '  ok   %s\n' "$1"; }
bad() { failures=$((failures + 1)); printf '  FAIL %s\n' "$1"; }

# Standalone workflows embed the prompt under `prompt: |`, indented 12 spaces.
embedded() { sed -n '/prompt: |/,$p' "$1" | tail -n +2 | sed -E 's/^ {12}//'; }

echo "prompts"
for v in 1 2; do
  wf=$(ls "$ROOT"/standalone/claude-review-v$v-*-step.yml)
  if diff -q <(embedded "$wf") "$ROOT/prompts/review-v$v.md" >/dev/null; then
    ok "standalone v$v embeds prompts/review-v$v.md unchanged"
  else
    bad "standalone v$v differs from prompts/review-v$v.md"; diff <(embedded "$wf") "$ROOT/prompts/review-v$v.md"
  fi
done

# The skill restates the v2 method; each numbered step must appear in it word for word.
norm() { tr -s ' \n' ' ' ; }
skill=$(norm < "$ROOT/skills/estate-review/SKILL.md")
for n in 1 2 3 4 5 6 7 8; do
  step=$(awk -v n="$n" '
    $0 ~ "^"n"\\. " {on=1}
    on && $0 ~ "^"(n+1)"\\. " {exit}
    on && /^Report, as/ {exit}
    on {print}' "$ROOT/prompts/review-v2.md" | norm | sed 's/ $//')
  if [ -n "$step" ] && [[ "$skill" == *"$step"* ]]; then ok "SKILL.md carries v2 step $n"; else bad "SKILL.md is missing or changed v2 step $n"; fi
done

printf '\n%d failed\n' "$failures"
[ "$failures" -eq 0 ]
