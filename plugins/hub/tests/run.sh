#!/usr/bin/env bash
# Runs every tests/test_*.sh in order; exits non-zero if any failed.
TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
failed=0
for t in "$TESTS_DIR"/test_*.sh; do
  [ -e "$t" ] || continue
  if bash "$t"; then :; else echo "FAIL $t"; failed=$((failed + 1)); fi
done
[ "$failed" -eq 0 ] || { echo "$failed test file(s) failed"; exit 1; }
echo "all tests passed"
