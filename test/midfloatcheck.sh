#!/bin/sh
# Check test/midfloat.tex: the note and the side caption of the float in
# the text must not overlap on the page (needs pdftotext from poppler).
#
# Usage (from the repository root, after make marginfix.sty):
#   test/midfloatcheck.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for i in 1 2; do
  TEXINPUTS=".//:" pdflatex -interaction=nonstopmode -output-directory="$tmp" \
    test/midfloat.tex > /dev/null 2>&1
done
pdftotext -f 1 -l 1 -bbox "$tmp/midfloat.pdf" - | awk -F'"' '
  /<word/ { split($0, a, ">"); w = a[2]; sub(/<.*/, "", w)
    if (w ~ /^cap/)  { if (!c || $4 < c0) c0 = $4; if ($8 > c1) c1 = $8; c = 1 }
    if (w ~ /^note/) { if (!n || $4 < n0) n0 = $4; if ($8 > n1) n1 = $8; n = 1 } }
  END {
    if (!c || !n) { print "UNEXPECTED:  midfloat (caption or note missing)"; exit 1 }
    if (n1 <= c0 || n0 >= c1) {
      printf "as expected: midfloat (note %d-%d, caption %d-%d)\n", n0, n1, c0, c1
    } else {
      printf "UNEXPECTED:  midfloat (note %d-%d overlaps caption %d-%d)\n", n0, n1, c0, c1
      exit 1 } }'
