#!/bin/sh
# Check test/calloutbreak.tex: page 1 ends with the line that calls out a
# note (L20), and page 3 doesn't leave a first line with a note alone at its
# foot (it ends with F19).  Needs pdftotext from poppler.
#
# Usage (from the repository root, after make marginfix.sty):
#   test/calloutbreakcheck.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
TEXINPUTS=".//:" pdflatex -interaction=nonstopmode -output-directory="$tmp" \
  test/calloutbreak.tex > /dev/null 2>&1
status=0
for want in 1:L20 3:F19; do
  p=${want%%:*} line=${want#*:}
  last=$(pdftotext -f "$p" -l "$p" -layout "$tmp/calloutbreak.pdf" - \
    | grep -o '^ *[LFC][0-9][0-9]' | tail -1 | tr -d ' ')
  if [ "$last" = "$line" ]; then
    echo "as expected: calloutbreak (page $p ends with $last)"
  else
    echo "UNEXPECTED:  calloutbreak (page $p ends with ${last:-nothing}, not $line)"
    status=1
  fi
done
exit $status
