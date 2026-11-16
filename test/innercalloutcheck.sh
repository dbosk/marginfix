#!/bin/sh
# Check test/innercallout.tex: each case ends, with the same errors and
# multicol warnings and the same number of pages as without marginfix.
# Needs pdfinfo from poppler.
#
# Usage (from the repository root, after make marginfix.sty):
#   test/innercalloutcheck.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=0
for c in minipage multicols figure footnote mbox; do
  for v in with without; do
    d="\\def\\innercase{$c}"
    [ $v = without ] && d="$d\\let\\usemf\\relax"
    for i in 1 2; do
      TEXINPUTS=".//:" timeout 60 pdflatex -interaction=nonstopmode \
        -output-directory="$tmp" -jobname="$c-$v" "$d\\input{test/innercallout}" \
        > /dev/null 2>&1
      [ $? = 124 ] && { echo "UNEXPECTED:  innercallout $c ($v marginfix) doesn't end"; status=1; continue 3; }
    done
    grep -a '^!\|not allowed inside' "$tmp/$c-$v.log" | sort -u > "$tmp/$c-$v.msg"
    pdfinfo "$tmp/$c-$v.pdf" 2>/dev/null | awk '/^Pages/{print $2}' > "$tmp/$c-$v.pages"
  done
  if cmp -s "$tmp/$c-with.msg" "$tmp/$c-without.msg" \
     && cmp -s "$tmp/$c-with.pages" "$tmp/$c-without.pages"; then
    echo "as expected: innercallout $c ($(tr '\n' ' ' < "$tmp/$c-with.msg"))"
  else
    echo "UNEXPECTED:  innercallout $c (with: $(cat "$tmp/$c-with.msg" "$tmp/$c-with.pages" | tr '\n' ' '); without: $(cat "$tmp/$c-without.msg" "$tmp/$c-without.pages" | tr '\n' ' '))"
    status=1
  fi
done
exit $status
