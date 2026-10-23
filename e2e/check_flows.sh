#!/usr/bin/env bash
# E2E flow manifest check (lock U1, Addendum A). Run from the repo root.
# Fails if integration_test/flows.md and the testWidgets names in
# integration_test/e2e_test.dart diverge. Reads files only; no network.
set -euo pipefail

app="apps/tell_me_a_story"
manifest="$app/integration_test/flows.md"
entry="$app/integration_test/e2e_test.dart"
support="$app/integration_test/support"
fail=0
err() { echo "check_flows: $*" >&2; fail=1; }

[ -f "$manifest" ] || { echo "check_flows: missing $manifest" >&2; exit 1; }
[ -f "$entry" ] || { echo "check_flows: missing $entry" >&2; exit 1; }

rows="$(grep -E '^\| C[0-9]+ \|' "$manifest" || true)"
[ -n "$rows" ] || { echo "check_flows: no flow rows in $manifest" >&2; exit 1; }

ids="$(printf '%s\n' "$rows" | awk -F'|' '{gsub(/^ +| +$/, "", $2); print $2}')"
names="$(printf '%s\n' "$rows" | awk -F'|' '{gsub(/^ +| +$/, "", $3); gsub(/`/, "", $3); print $3}')"
count="$(printf '%s\n' "$ids" | wc -l)"

dup="$(printf '%s\n' "$ids" | sort | uniq -d)"
[ -z "$dup" ] || err "duplicate flow ids: $dup"
[ "$count" -le 10 ] || err "$count flows is over the U4 budget of 10"

while IFS='|' read -r _ id name _ paths _; do
  id="$(echo "$id" | sed -E 's/^ +| +$//g')"
  name="$(echo "$name" | sed -E 's/^ +| +$//g; s/`//g')"
  case "$name" in
    "$id "*) ;;
    *) err "$id: test name '$name' does not start with '$id '" ;;
  esac
  printf '%s\n' "$name" | grep -qE '^C[0-9]+ [a-z0-9 ,/-]+$' ||
    err "$id: test name '$name' has characters outside [a-z0-9 ,/-]"
  [ "${#name}" -le 64 ] || err "$id: test name is over 64 characters"
  for p in $(printf '%s\n' "$paths" | grep -oE '`[^`]+`' | tr -d '`'); do
    [ -e "$app/lib/$p" ] || err "$id: owning path lib/$p does not exist"
  done
done <<< "$rows"

tests="$(grep -oE "'C[0-9]+ [^']*'" "$entry" | tr -d "'" | grep -E '^C[0-9]+ [a-z0-9 ,/-]+$' | sort || true)"
want="$(printf '%s\n' "$names" | sort)"
if [ "$tests" != "$want" ]; then
  err "flows.md and e2e_test.dart disagree:"
  diff <(printf '%s\n' "$want") <(printf '%s\n' "$tests") >&2 || true
fi

calls="$(grep -c 'testWidgets(' "$entry" || true)"
[ "$calls" -eq "$count" ] || err "e2e_test.dart has $calls testWidgets calls; flows.md has $count rows"

if [ -d "$support" ] && grep -rlE 'testWidgets\(' "$support" >/dev/null; then
  err "testWidgets( found under $support; tests live only in e2e_test.dart"
fi

[ "$fail" -eq 0 ] || exit 1
echo "check_flows: $count flows match ($manifest <-> $entry)"
