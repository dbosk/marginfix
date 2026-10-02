#!/bin/sh
# Compare the PDFs of the tests typeset with marginfix at a base revision
# (default: the parent of the first commit with deferrable notes) and with
# the marginfix.sty in the working tree, byte for byte.  The tests use the
# default mode (warn), which must not change the layout.
#
# Usage (from the repository root, after make marginfix.sty):
#   test/regress.sh [BASE] [TEST.tex ...]
set -e
if [ $# -gt 0 ]; then
  base=$1; shift
else
  first=$(git log --reverse --format=%H -S'\marginnotedeferrable' \
    -- marginfix.dtx | head -n 1)
  [ -n "$first" ] || { echo "no commit with deferrable notes" >&2; exit 2; }
  base=$first^
fi
tests=${*:-test/*.tex}
root=$(pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/sty-base" "$tmp/base" "$tmp/new"
git show "$base:marginfix.dtx" > "$tmp/sty-base/marginfix.dtx"
git show "$base:marginfix.ins" > "$tmp/sty-base/marginfix.ins"
(cd "$tmp/sty-base" && yes | latex marginfix.ins > /dev/null)
mkdir -p "$tmp/sty-new"
cp marginfix.sty "$tmp/sty-new/"
# Reproducible PDFs: fixed dates and no trailer id.
export SOURCE_DATE_EPOCH=0 FORCE_SOURCE_DATE=1
status=0
for t in $tests; do
  case $t in */prioritycheck.tex|*/modechange-part.tex) continue;; esac
  # A test that sets a mode of its own is not about the default mode.
  if grep -q '^% regress: skip' "$t"; then echo "skipped:   $(basename "$t" .tex)"; continue; fi
  job=$(basename "$t" .tex)
  for v in base new; do
    for i in 1 2 3; do
      (cd "$root" && TEXINPUTS="$tmp/sty-$v//:" pdflatex -interaction=nonstopmode \
        -output-directory="$tmp/$v" -jobname="$job" \
        "\\pdftrailerid{}\\input{$t}" > /dev/null 2>&1) || true
    done
  done
  if cmp -s "$tmp/base/$job.pdf" "$tmp/new/$job.pdf"; then
    echo "same:      $job"
  else
    echo "DIFFERENT: $job"
    status=1
  fi
done
exit $status
