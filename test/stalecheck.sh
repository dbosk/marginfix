#!/bin/bash
# Check that a page doesn't end early for a note that fits, on test/stale.tex
# and test/stalefit.tex (see there).  Each case is run until the .aux file stops
# changing, and the last run must not ask for another, then:
#   stale, article, twoside  settled within five runs (latexmk's default), no
#                   page less than half full, a record retired, no note carried;
#   needed          settled within five runs, at least two early page ends
#                   and no record retired, no note carried;
#   linemate        settled (in six runs, as before records were retired),
#                   no record ever retired, no note carried;
#   these five      every break that stands is needed: with all the records
#                   of its note taken out of the settled .aux file, the runs
#                   settle on the same text, page by page;
#   split, defer, off, limit  stale under these \marginnotepriority modes and
#                   a \marginnoteyieldlimit of 30 lines, less than the stale
#                   page leaves: as stale, and nothing capped;
#   giveway-defer, giveway-split  stale with a deferrable note that fills the
#                   room of the stale note, which it gives way to;
#   twocol          stale in two columns: settled, a record retired;
#   xe              stale under XeLaTeX, where no page can end early: the
#                   notes are carried, and nothing is retired;
#   carried         a note in the mode carry is left over from the page, so
#                   the note after it can't fit, whatever the room: no record
#                   ever retired;
#   pieces          a record of a note that fits in a lower piece of the
#                   margin, below the piece where the notes end: retired;
#   edit            the first paragraph's notes taken out and put back, in
#                   the file it is in, with the .aux file kept: the same text
#                   as from no .aux file, the first time.  The second time the
#                   note has been retired twice: the page ends early, with a
#                   warning;
#   grow            the note of the stale record made too tall for its page,
#                   and back, with the .aux file kept: as from no .aux file;
#   older           the .aux file read by a version that doesn't know its
#                   records (\staleolder): no error;
#   lie             needed, with the height of its second note taken to be
#                   wrong in every run (\stalelie): it settles, with a warning,
#                   and the text is that of needed.
#
# Usage (from the repository root, after make marginfix.sty):
#   test/stalecheck.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
status=0
# settle <job> <preamble definitions> [<file>] [<most runs>]: as in
# test/overflowcheck.sh.
settle() {
  settled=no
  for i in $(seq 1 "${4:-8}"); do
    [ -f "$tmp/$1.aux" ] && cp "$tmp/$1.aux" "$tmp/$1.aux.old"
    TEXINPUTS=".//:" pdflatex -interaction=nonstopmode \
      -output-directory="$tmp" -jobname="$1" \
      "$2\\input{${3:-test/stale}}" > /dev/null 2>&1
    if [ -f "$tmp/$1.aux.old" ] && cmp -s "$tmp/$1.aux" "$tmp/$1.aux.old" \
       && ! grep -q 'Rerun\|may have changed' "$tmp/$1.log"; then
      settled=yes; break
    fi
  done
}
# count <pattern> <file>
count() { grep -c "$1" "$2"; }
# Numbers of the settled <job>, in variables and in $state.
look() {
  log=$tmp/$1.log; aux=$tmp/$1.aux; runs=$i
  errors=$(count '^!' "$log")
  spills=$(count '^marginfix-spill' "$log")
  yields=$(count '^marginfix-yield: page=[0-9]* before' "$log")
  half=$(count 'ends early, so' "$log")
  retired=$(count '^\\mfx@unyield' "$aux")
  tries=$(count '^\\mfx@yieldtries' "$aux")
  capped=$(count '^\\mfx@noyield' "$aux")
  state="settled: $settled after $runs runs, errors: $errors, spills: $spills,"
  state="$state early ends: $yields, less than half full: $half,"
  state="$state retired: $retired, recorded again: $tries, capped: $capped"
}
# report <job> <result of its check: 0 is good> [more to say]
report() {
  if [ "$2" = 0 ] && [ "$settled$errors" = yes0 ]; then
    echo "as expected: $1 ($state$3)"
  else
    echo "UNEXPECTED:  $1 ($state$3)"; status=1
  fi
}
same() { diff <(pdftotext -layout "$tmp/$1.pdf" -) \
              <(pdftotext -layout "$tmp/$2.pdf" -) > /dev/null; }
# standing <aux>: the keys whose last record ends their page.
standing() {
  grep -o '^\\mfx@\(yield\|unyield\){[^}]*}' "$1" \
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
    if [ "$settled" != yes ] || ! same drop "$1"; then
      unneeded="$unneeded $k"
    fi
    rm -f "$tmp"/drop.*
  done
}

for c in stale article twoside needed linemate; do
  settle "$c" "\\def\\stalecase{$c}"
  look "$c"; ok=$settled
  needed "$c" "\\def\\stalecase{$c}"
  settled=$ok
  limit=5
  case $c in
    needed) [ "$yields" -ge 2 ] && [ "$retired$tries" = 00 ];;
    linemate) limit=6; [ "$retired$tries" = 00 ];;
    *) [ "$half" = 0 ] && [ "$retired" -gt 0 ];;
  esac
  r=$?
  [ "$r" = 0 ] && [ "$spills" = 0 ] && [ "$runs" -le "$limit" ] \
    && [ -z "$unneeded" ]
  report "$c" $? ", unneeded:${unneeded:- none}"
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
  look "$c"
  [ "$runs" -le 5 ] && [ "$spills" = 0 ] && [ "$retired" -gt 0 ] \
    && [ "$capped" = 0 ] && same "$c" stale
  report "$c" $?
done

# A deferrable note that takes the room of the stale note gives way to it.
for c in defer:4 split:5; do
  j=giveway-${c%:*}
  settle "$j" "\\def\\stalecase{stale}\\def\\stalepriority{${c%:*}}\\def\\staleltlen{${c#*:}}"
  look "$j"
  [ "$half" = 0 ] && [ "$retired" -gt 0 ] && [ "$spills" = 0 ]
  report "$j" $?
done

# Two columns: dense, so it takes many runs, as without records retired.
settle twocol '\def\stalecase{twocol}\def\staletwocolB{16}' test/stale 14
look twocol
[ "$retired" -gt 0 ] && [ "$spills" = 0 ]
report twocol $?

# XeTeX has no \vadjust pre: the notes are carried and no page ends early.
if command -v xelatex > /dev/null; then
  for i in 1 2 3 4; do
    TEXINPUTS=".//:" xelatex -interaction=nonstopmode -output-directory="$tmp" \
      -jobname=xe '\def\stalecase{stale}\input{test/stale}' > /dev/null 2>&1
  done
  settled=yes; look xe
  [ "$yields" = 0 ] && [ "$spills" -gt 0 ] && [ "$retired" = 0 ]
  report xe $?
else
  echo "skipped:     xe (no xelatex)"
fi

# Parts of the check of what a page has room for.
settle carried '\def\stalefitcase{carried}' test/stalefit
look carried
[ "$yields" = 1 ] && [ "$retired$tries" = 00 ] \
  && [ "$(count '^marginfix-spill: .* intended$' "$log")" = 1 ] \
  && [ "$spills" = 1 ]
report carried $?

defs='\def\stalefitcase{pieces}\def\stalefitupper{1-14}'
settle pieces "$defs" test/stalefit
settle piecesref "$defs" test/stalefit
key=$(grep -o 'mfx@anchorpage{[^}]*}' "$tmp/pieces.aux" | tail -1 \
  | sed 's/.*{\(.*\)}/\1/')
printf '\\mfx@yield{%s}\n\\mfx@yieldht{%s}{40pt}\n' "$key" "$key" \
  >> "$tmp/pieces.aux"
settle pieces "$defs" test/stalefit
look pieces
[ -n "$key" ] && [ "$retired" = 1 ] && [ "$yields" = 0 ] && same pieces piecesref
report pieces $?

# A real edit: the notes of the first paragraph go, and come back, in the file
# it is in, so that the notes after it keep their keys.
defs='\def\stalecase{stale}\def\stalefront{test/stale-front-'
settle edit "${defs}a}"
settle edit "${defs}b}"
settle editref "${defs}a}"
settle edit "${defs}a}"
look edit
[ "$half" = 0 ] && [ "$spills" = 0 ] && same edit editref
report edit $?
settle edit "${defs}b}"
settle edit "${defs}a}"
look edit
warned=$(tr -d '\n' < "$log" | grep -c 'which seems to.*fit there')
[ "$warned" -gt 0 ] && [ "$half" = 1 ]
report edit-twice $? ", warned: $warned"

# A note that grows and shrinks keeps its key, and may be stale or not.
defs='\def\stalecase{stale}'
big='\def\stalegrow{\lipsum[1][1-12]\lipsum[1][1-12]}'
settle grow "$defs"
settle grow "$defs$big"
settle growref "$defs$big"
look grow
if same grow growref; then r=0; else r=1; fi
[ "$r" = 0 ]
report grow $?
settle grow "$defs"
look grow
[ "$half" = 0 ] && same grow stale
report shrink $?

# An older version reads the file without an error.
settle older '\def\stalecase{stale}'
TEXINPUTS=".//:" pdflatex -interaction=nonstopmode -output-directory="$tmp" \
  -jobname=older '\def\stalecase{stale}\def\staleolder{}\input{test/stale}' \
  > /dev/null 2>&1
look older
report older 0

# A check that is wrong in every run must not keep the runs going.
key=$(grep -o '^\\mfx@yield{[^}]*}' "$tmp/needed.aux" | tail -1 \
  | sed 's/^\\mfx@yield{\(.*\)}$/\1/')
settle lie "\\def\\stalecase{needed}\\def\\stalelie{$key}" test/stale 14
look lie
warned=$(tr -d '\n' < "$log" | grep -c 'which seems to.*fit there')
[ -n "$key" ] && [ "$spills" = 0 ] && [ "$warned" -gt 0 ] && same lie needed
report lie $? ", warned: $warned"
exit $status
