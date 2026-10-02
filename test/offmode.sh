#!/bin/sh
# Check mode off: it must typeset every given test exactly as mode warn
# (byte for byte), and without the warnings about margin notes.
#
# Usage (from the repository root, after make marginfix.sty):
#   test/offmode.sh [TEST.tex ...]
tests=${*:-test/priority.tex test/fill.tex}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export SOURCE_DATE_EPOCH=0 FORCE_SOURCE_DATE=1
status=0
for t in $tests; do
  job=$(basename "$t" .tex)
  for m in warn off; do
    mkdir -p "$tmp/$m"
    for i in 1 2 3; do
      TEXINPUTS=".//:" pdflatex -interaction=nonstopmode \
        -output-directory="$tmp/$m" -jobname="$job" \
        "\\pdftrailerid{}\\def\\prioritymode{$m}\\input{$t}" > /dev/null 2>&1
    done
  done
  if ! cmp -s "$tmp/warn/$job.pdf" "$tmp/off/$job.pdf"; then
    echo "DIFFERENT: $job (off vs warn)"; status=1
  elif grep -q 'Package marginfix Warning: .*[Mm]argin note' "$tmp/off/$job.log"; then
    echo "WARNINGS:  $job (mode off)"; status=1
  elif ! grep -q 'Package marginfix Warning: Margin note' "$tmp/warn/$job.log"; then
    echo "NO WARNING: $job (mode warn)"; status=1
  else
    echo "same, silent: $job"
  fi
done
exit $status
