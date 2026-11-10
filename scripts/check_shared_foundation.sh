#!/bin/bash
# Check that the shared Rocq foundation has not diverged.
#   bash scripts/check_shared_foundation.sh                # this project only
#   bash scripts/check_shared_foundation.sh <other-project-root>   # also compare
# Exit status 1 on any mismatch with SHARED_FOUNDATION_MANIFEST.txt or with
# the other project.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OTHER="$1"
status=0
grep -E '^[0-9a-f]{64}  ' "$ROOT/SHARED_FOUNDATION_MANIFEST.txt" | while read -r h f; do
  a=$(sha256sum "$ROOT/$f" | cut -d' ' -f1)
  if [ "$a" = "$h" ]; then echo "ok        $f"; else echo "MODIFIED  $f"; echo 1 > /tmp/.shared_fail; fi
  if [ -n "$OTHER" ]; then
    b=$(sha256sum "$OTHER/$f" 2>/dev/null | cut -d' ' -f1)
    if [ "$a" = "$b" ]; then echo "identical $f (other project)"; else echo "DIVERGED  $f (other project)"; echo 1 > /tmp/.shared_fail; fi
  fi
done
if [ -f /tmp/.shared_fail ]; then rm -f /tmp/.shared_fail; status=1; fi
exit $status
