#!/bin/bash
# Check that a page doesn't end early for a note that fits, on test/stale.tex
# (see there).  Each case is run until the .aux file stops changing (at most
# eight runs, and the last must not ask for another), then:
#   stale, article  settled within five runs (latexmk's default), no page
#                   less than half full, a record retired, no note carried;
#   needed          settled within five runs, at least two early page ends
#                   and no record retired, no note carried;
#   linemate        settled (in six runs, as before records were retired),
#                   no record retired or made for good, no note carried;
#   all four        every break that stands is needed: with all the records
#                   of its note taken out of the settled .aux file, the runs
#                   settle on the same text, page by page;
#   split, defer, off, limit  stale under these \marginnotepriority modes and
#                   a \marginnoteyieldlimit of 30 lines, less than the stale
#                   page leaves: as stale, and nothing capped;
#   xe              stale under XeLaTeX, where no page can end early: the
#                   notes are carried, and nothing is retired;
#   lie             needed, with the height of the note of its second break
#                   written wrong in every run (\stalelie): it settles, its
#                   record ends up for good (\mfx@yieldfirm), and the text is
#                   that of needed.
#
# Usage (from the repository root, after make marginfix.sty):
#   test/stalecheck.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=0
# settle <job> <preamble definitions>: as in test/overflowcheck.sh.
settle() {
  settled=no
  for i in 1 2 3 4 5 6 7 8; do
    [ -f "$tmp/$1.aux" ] && cp "$tmp/$1.aux" "$tmp/$1.aux.old"
    TEXINPUTS=".//:" pdflatex -interaction=nonstopmode \
      -output-directory="$tmp" -jobname="$1" \
      "$2\\input{test/stale}" > /dev/null 2>&1
    if [ -f "$tmp/$1.aux.old" ] && cmp -s "$tmp/$1.aux" "$tmp/$1.aux.old" \
       && ! grep -q 'Rerun\|may have changed' "$tmp/$1.log"; then
      settled=yes; break
    fi
  done
}
# standing <aux>: the keys whose last record ends their page.
standing() {
  grep -o '^\\mfx@\(yield\|yieldfirm\|unyield\){[^}]*}' "$1" \
    | sed 's/^\\mfx@\([a-z]*\){\(.*\)}$/\2 \1/' \
    | awk '{last[$1]=$2} END {for (k in last) if (last[k] != "unyield") print k}'
}
# needed <job> <definitions>: every standing break of the settled <job> is
# needed; sets $unneeded.
needed() {
  unneeded=
  for k in $(standing "$tmp/$1.aux"); do
    grep -v "{$k}" "$tmp/$1.aux" > "$tmp/drop.aux"
    rm -f "$tmp"/drop.aux.old
    settle drop "$2"
    if [ "$settled" != yes ] \
       || ! diff <(pdftotext -layout "$tmp/drop.pdf" -) \
                 <(pdftotext -layout "$tmp/$1.pdf" -) > /dev/null; then
      unneeded="$unneeded $k"
    fi
    rm -f "$tmp"/drop.*
  done
}
for c in stale article needed linemate; do
  settle "$c" "\\def\\stalecase{$c}"
  runs=$i; ok=$settled
  log=$tmp/$c.log
  errors=$(grep -c '^!' "$log")
  spills=$(grep -c '^marginfix-spill' "$log")
  yields=$(grep -c '^marginfix-yield: page=[0-9]* before' "$log")
  half=$(grep -c 'ends early, so' "$log")
  retired=$(grep -c '^\\mfx@unyield' "$tmp/$c.aux")
  firm=$(grep -c '^\\mfx@yieldfirm' "$tmp/$c.aux")
  needed "$c" "\\def\\stalecase{$c}"
  state="settled: $ok after $runs runs, errors: $errors, spills: $spills,"
  state="$state early ends: $yields, less than half full: $half,"
  state="$state retired: $retired, for good: $firm,"
  state="$state unneeded:${unneeded:- none}"
  limit=5
  case $c in
    needed) [ "$yields" -ge 2 ] && [ "$retired$firm" = 00 ];;
    linemate) limit=6; [ "$retired$firm" = 00 ];;
    *) [ "$half" = 0 ] && [ "$retired" -gt 0 ];;
  esac
  if [ $? = 0 ] && [ "$ok$errors$spills" = yes00 ] && [ "$runs" -le $limit ] \
     && [ -z "$unneeded" ]; then
    echo "as expected: $c ($state)"
  else
    echo "UNEXPECTED:  $c ($state)"; status=1
  fi
done

# The modes and the limit change nothing for this page: with no deferrable
# notes the priority modes place the notes alike, and a page that ends early
# for a note that fits is retired, not capped.
for c in split defer off limit; do
  case $c in
    limit) defs='\def\stalecase{stale}\def\stalelimit{30}';;
    *) defs="\\def\\stalecase{stale}\\def\\stalepriority{$c}";;
  esac
  settle "$c" "$defs"
  log=$tmp/$c.log
  state="settled: $settled after $i runs, errors: $(grep -c '^!' "$log"),"
  state="$state spills: $(grep -c '^marginfix-spill' "$log"),"
  state="$state retired: $(grep -c '^\\mfx@unyield' "$tmp/$c.aux"),"
  state="$state capped: $(grep -c '^\\mfx@noyield' "$tmp/$c.aux")"
  if [ "$settled" = yes ] && [ "$i" -le 5 ] && [ "$(grep -c '^!' "$log")" = 0 ] \
     && [ "$(grep -c '^marginfix-spill' "$log")" = 0 ] \
     && [ "$(grep -c '^\\mfx@unyield' "$tmp/$c.aux")" -gt 0 ] \
     && [ "$(grep -c '^\\mfx@noyield' "$tmp/$c.aux")" = 0 ] \
     && diff <(pdftotext -layout "$tmp/$c.pdf" -) \
             <(pdftotext -layout "$tmp/stale.pdf" -) > /dev/null; then
    echo "as expected: $c ($state)"
  else
    echo "UNEXPECTED:  $c ($state)"; status=1
  fi
done

# XeTeX has no \vadjust pre: the notes are carried and no page ends early.
if command -v xelatex > /dev/null; then
  for i in 1 2 3 4; do
    TEXINPUTS=".//:" xelatex -interaction=nonstopmode -output-directory="$tmp" \
      -jobname=xe '\def\stalecase{stale}\input{test/stale}' > /dev/null 2>&1
  done
  state="errors: $(grep -c '^!' "$tmp/xe.log"),"
  state="$state early ends: $(grep -c '^marginfix-yield: page=[0-9]* before' "$tmp/xe.log"),"
  state="$state carried: $(grep -c '^marginfix-spill' "$tmp/xe.log"),"
  state="$state retired: $(grep -c '^\\mfx@unyield' "$tmp/xe.aux")"
  if [ "$(grep -c '^!' "$tmp/xe.log")" = 0 ] \
     && [ "$(grep -c '^marginfix-yield: page=[0-9]* before' "$tmp/xe.log")" = 0 ] \
     && [ "$(grep -c '^marginfix-spill' "$tmp/xe.log")" -gt 0 ] \
     && [ "$(grep -c '^\\mfx@unyield' "$tmp/xe.aux")" = 0 ]; then
    echo "as expected: xe ($state)"
  else
    echo "UNEXPECTED:  xe ($state)"; status=1
  fi
else
  echo "skipped:     xe (no xelatex)"
fi

# A check that is wrong in every run must not keep the runs going.
key=$(grep -o '^\\mfx@yield{[^}]*}' "$tmp/needed.aux" | tail -1 \
  | sed 's/^\\mfx@yield{\(.*\)}$/\1/')
settle lie "\\def\\stalecase{needed}\\def\\stalelie{$key}"
if [ "$settled" = yes ] && [ -n "$key" ] \
   && [ "$(grep -c '^marginfix-spill' "$tmp/lie.log")" = 0 ] \
   && grep -q "^\\\\mfx@yieldfirm{$key}" "$tmp/lie.aux" \
   && diff <(pdftotext -layout "$tmp/lie.pdf" -) \
           <(pdftotext -layout "$tmp/needed.pdf" -) > /dev/null; then
  echo "as expected: lie (settled after $i runs, recorded for good)"
else
  echo "UNEXPECTED:  lie (settled: $settled after $i runs, key: $key)"
  status=1
fi
exit $status
