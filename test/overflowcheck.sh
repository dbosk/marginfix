#!/bin/sh
# Check \marginnoteoverflow on test/overflow.tex.  Each case is run until
# the .aux file stops changing (at most six runs; it must settle within
# them, and the last run must not ask for another), then the log is
# checked:
#   carry, local  notes carried and logged as intended, no early page end;
#   break         no note carried, at least one early page end.
#
# Usage (from the repository root, after make marginfix.sty):
#   test/overflowcheck.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=0
for c in carry break local; do
  settled=no
  for i in 1 2 3 4 5 6; do
    [ -f "$tmp/$c.aux" ] && cp "$tmp/$c.aux" "$tmp/$c.aux.old"
    TEXINPUTS=".//:" pdflatex -interaction=nonstopmode \
      -output-directory="$tmp" -jobname="$c" \
      "\\def\\overflowcase{$c}\\input{test/overflow}" > /dev/null 2>&1
    if [ -f "$tmp/$c.aux.old" ] && cmp -s "$tmp/$c.aux" "$tmp/$c.aux.old" \
       && ! grep -q 'Rerun\|may have changed' "$tmp/$c.log"; then
      settled=yes; break
    fi
  done
  log=$tmp/$c.log
  intended=$(grep -c '^marginfix-spill: .* intended$' "$log")
  unresolved=$(grep -c '^marginfix-spill: .* unresolved$' "$log")
  yields=$(grep -c '^marginfix-yield: ' "$log")
  errors=$(grep -c '^!' "$log")
  case $c,$settled,$errors in
    *,yes,0) ;;
    *) echo "UNEXPECTED:  $c (settled: $settled, errors: $errors)";
       status=1; continue;;
  esac
  case $c in
    break)
      if [ "$intended$unresolved" = 00 ] && [ "$yields" -gt 0 ]; then
        echo "as expected: $c ($yields early page ends, settled after $i runs)"
      else
        echo "UNEXPECTED:  $c (spills: $intended intended," \
          "$unresolved unresolved; early ends: $yields)"; status=1
      fi;;
    *)
      if [ "$intended" -gt 0 ] && [ "$unresolved$yields" = 00 ]; then
        echo "as expected: $c ($intended notes carried, intended)"
      else
        echo "UNEXPECTED:  $c (spills: $intended intended," \
          "$unresolved unresolved; early ends: $yields)"; status=1
      fi;;
  esac
done
exit $status
