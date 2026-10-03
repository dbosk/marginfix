#!/bin/sh
# Check \marginnotebesidefloats on test/floats.tex: a bottom float that
# extends into the margin (lines wider than the column on either side, an
# overfull table, also where the page breaks in a group with a wider
# \columnwidth, a side caption, or \marginnotereservefloat) must keep the
# margin beside it empty, and so must a margin blocked across the end of
# the page, so mode use must typeset these byte for byte as mode reserve;
# a plain table must not.  A float whose caption marginfix can't take
# apart must say so in the log, and \captionof outside a float must
# typeset the same in both modes.
#
# Usage (from the repository root, after make marginfix.sty):
#   test/floatsmode.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export SOURCE_DATE_EPOCH=0 FORCE_SOURCE_DATE=1
status=0
for c in wide overfull group nested left verso side marker block lost plain; do
  for m in reserve use; do
    mkdir -p "$tmp/$m"
    for i in 1 2 3; do
      TEXINPUTS=".//:" pdflatex -interaction=nonstopmode \
        -output-directory="$tmp/$m" -jobname="floats-$c" \
        "\\pdftrailerid{}\\def\\floatcase{$c}\\def\\besidemode{$m}\\input{test/floats}" \
        > /dev/null 2>&1
    done
  done
  if cmp -s "$tmp/reserve/floats-$c.pdf" "$tmp/use/floats-$c.pdf"; then
    same=yes
  else
    same=no
  fi
  case $c,$same in
    plain,no|wide,yes|overfull,yes|group,yes|nested,yes|left,yes|verso,yes|\
    side,yes|marker,yes|block,yes|lost,yes)
      echo "as expected: $c (same: $same)";;
    *) echo "UNEXPECTED:  $c (same: $same)"; status=1;;
  esac
done
# A float that is wide because marginfix couldn't take it apart says so.
grep -q "can't take apart" "$tmp/use/floats-lost.log" \
  && echo "as expected: lost (message in the log)" \
  || { echo "UNEXPECTED:  lost (no message in the log)"; status=1; }
# \captionof outside a float gets no penalties: both modes the same.
for m in reserve use; do
  for i in 1 2 3; do
    TEXINPUTS=".//:" pdflatex -interaction=nonstopmode \
      -output-directory="$tmp/$m" -jobname=captionof \
      "\\pdftrailerid{}\\def\\besidemode{$m}\\input{test/floats-captionof}" \
      > /dev/null 2>&1
  done
done
if cmp -s "$tmp/reserve/captionof.pdf" "$tmp/use/captionof.pdf"; then
  echo "as expected: captionof (same: yes)"
else
  echo "UNEXPECTED:  captionof (same: no)"; status=1
fi
exit $status
