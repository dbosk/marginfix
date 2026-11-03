#!/bin/bash
# Check \marginnoteoverflow on test/overflow.tex.  Each case is run until
# the .aux file stops changing (at most eight runs; it must settle within
# them, and the last run must not ask for another), then the log is
# checked:
#   carry, local  notes carried and logged as intended, no early page end;
#   break         no note carried, at least one early page end;
#   cap           notes carried and logged as capped, each with a warning,
#                 and at least one early page end that stays;
#   caphigh       as break, since the limit is more than a page.
#   captall       the same case with a tall line, see test/overflow.tex: must
#                 settle, capped, with no early page end left.
# Then the cases below, from a warm .aux file.
#
# Usage (from the repository root, after make marginfix.sty):
#   test/overflowcheck.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=0
# settle <job> <preamble definitions>: runs <job> until its .aux file stops
# changing and the last run doesn't ask for another; sets $settled and $i.
settle() {
  settled=no
  for i in 1 2 3 4 5 6 7 8; do
    [ -f "$tmp/$1.aux" ] && cp "$tmp/$1.aux" "$tmp/$1.aux.old"
    TEXINPUTS=".//:" pdflatex -interaction=nonstopmode \
      -output-directory="$tmp" -jobname="$1" \
      "$2\\input{test/overflow}" > /dev/null 2>&1
    if [ -f "$tmp/$1.aux.old" ] && cmp -s "$tmp/$1.aux" "$tmp/$1.aux.old" \
       && ! grep -q 'Rerun\|may have changed' "$tmp/$1.log"; then
      settled=yes; break
    fi
  done
}
for c in carry break local cap caphigh; do
  settle "$c" "\\def\\overflowcase{$c}"
  log=$tmp/$c.log
  intended=$(grep -c '^marginfix-spill: .* intended$' "$log")
  unresolved=$(grep -c '^marginfix-spill: .* unresolved$' "$log")
  capped=$(grep -c '^marginfix-spill: .* capped$' "$log")
  yields=$(grep -c '^marginfix-yield: ' "$log")
  errors=$(grep -c '^!' "$log")
  case $c,$settled,$errors in
    *,yes,0) ;;
    *) echo "UNEXPECTED:  $c (settled: $settled, errors: $errors)";
       status=1; continue;;
  esac
  case $c in
    cap)
      warnings=$(grep -c 'marginnoteyieldlimit keeps page [0-9]*$' "$log")
      if [ "$capped" -gt 0 ] && [ "$intended$unresolved" = 00 ] \
         && [ "$yields" -gt 0 ] && [ "$warnings" = "$capped" ] \
         && grep -q '^Package marginfix Warning: .* note called out at' "$log"
      then
        echo "as expected: $c ($capped notes carried, capped, each with a" \
          "warning; $yields early page ends; settled after $i runs)"
      else
        echo "UNEXPECTED:  $c (spills: $capped capped, $intended" \
          "intended, $unresolved unresolved; early ends: $yields;" \
          "warnings: $warnings)"; status=1
      fi;;
    break|caphigh)
      if [ "$intended$unresolved$capped" = 000 ] && [ "$yields" -gt 0 ]
      then
        echo "as expected: $c ($yields early page ends, settled after $i runs)"
      else
        echo "UNEXPECTED:  $c (spills: $intended intended," \
          "$unresolved unresolved; early ends: $yields)"; status=1
      fi;;
    *)
      if [ "$intended" -gt 0 ] && [ "$unresolved$capped$yields" = 000 ]
      then
        echo "as expected: $c ($intended notes carried, intended)"
      else
        echo "UNEXPECTED:  $c (spills: $intended intended," \
          "$unresolved unresolved; early ends: $yields)"; status=1
      fi;;
  esac
done

# A record of a capped note must not outlive its reason.  Each of these starts
# from the settled .aux file of another case and must end up as a build from
# no .aux file does: <from> <job> <definitions>.  Without \marginnoteyieldlimit
# nothing is capped (warmoff), a higher limit lets the page end (warmhigh), a
# lower one caps (warmlow), and text that moves is tested anew, both ways
# (warmdown, warmup), since the notes keep their keys.
settle capdown '\def\overflowcase{cap}\def\overflowgap{15}'
[ "$settled" = yes ] || { echo "UNEXPECTED:  capdown (settled: no)"; status=1; }
while read -r from job defs; do
  [ -n "$from" ] || continue
  cp "$tmp/$from.aux" "$tmp/$job.aux"
  settle "$job" "$defs"
  settledwarm=$settled; runs=$i
  settle ref "$defs"
  settledref=$settled
  if [ "$settledwarm$settledref" != yesyes ]; then
    echo "UNEXPECTED:  $job (settled: $settledwarm from $from's .aux," \
      "$settledref from none)"; status=1
  elif [ "$(grep -c '^marginfix-\(spill\|yield\)' "$tmp/$job.log")" = 0 ] \
    || ! diff <(grep '^marginfix-\(spill\|yield\)' "$tmp/$job.log") \
              <(grep '^marginfix-\(spill\|yield\)' "$tmp/ref.log") >/dev/null \
    || ! diff <(pdftotext -layout "$tmp/$job.pdf" -) \
              <(pdftotext -layout "$tmp/ref.pdf" -) >/dev/null
  then
    echo "UNEXPECTED:  $job (from $from's .aux, differs from no .aux)"
    status=1
  else
    echo "as expected: $job (from $from's .aux, as from none;" \
      "settled after $runs runs)"
  fi
  rm -f "$tmp"/ref.*
done <<'CASES'
cap warmoff \def\overflowcase{break}
cap warmhigh \def\overflowcase{caphigh}
break warmlow \def\overflowcase{cap}
cap warmdown \def\overflowcase{cap}\def\overflowgap{15}
capdown warmup \def\overflowcase{cap}
CASES

settle captall '\def\overflowcase{cap}\def\overflowgap{26}\def\overflowtall{8}\def\overflowtallnote{5}'
capped=$(grep -c '^marginfix-spill: .* capped$' "$tmp/captall.log")
yields=$(grep -c '^marginfix-yield: page=[0-9]* before' "$tmp/captall.log")
warnings=$(grep -c 'marginnoteyieldlimit keeps page [0-9]*$' "$tmp/captall.log")
unresolved=$(grep -c '^marginfix-spill: .* unresolved$' "$tmp/captall.log")
if [ "$settled" = yes ] && [ "$capped" -gt 0 ] && [ "$yields$unresolved" = 00 ] \
   && [ "$warnings" = "$capped" ]; then
  echo "as expected: captall ($capped capped, each with a warning, no early" \
    "page end; settled after $i runs)"
else
  echo "UNEXPECTED:  captall (settled: $settled, capped: $capped, early ends:" \
    "$yields, unresolved: $unresolved, warnings: $warnings)"; status=1
fi
exit $status
