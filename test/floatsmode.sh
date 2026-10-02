#!/bin/sh
# Check \marginnotebesidefloats on test/floats.tex: a bottom float that
# extends into the margin (wider than the column, a side caption, or
# \marginnotereservefloat) must keep the margin beside it empty, so mode
# use must typeset it byte for byte as mode reserve; a plain one must not.
#
# Usage (from the repository root, after make marginfix.sty):
#   test/floatsmode.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export SOURCE_DATE_EPOCH=0 FORCE_SOURCE_DATE=1
status=0
for c in wide side marker plain; do
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
    plain,no|wide,yes|side,yes|marker,yes) echo "as expected: $c (same: $same)";;
    *) echo "UNEXPECTED:  $c (same: $same)"; status=1;;
  esac
done
exit $status
