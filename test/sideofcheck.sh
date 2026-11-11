#!/bin/sh
# Check \marginparsideof (test/sideof.tex) for memoir and article, one- and
# two-sided, with \marginparmargin and \reversemarginpar.
#
# Usage (from the repository root, after make marginfix.sty):
#   test/sideofcheck.sh
# cases: class|opts|margin|reverse|want
status=0
for c in "memoir|twoside|outer||rl" "memoir|twoside|right||rr" "memoir|twoside|left||ll" "memoir|oneside|inner||rr" "memoir|oneside|left||ll" "article|twoside|||rl" "article|oneside|||rr" "article|twoside||y|lr" "article|oneside||y|ll"; do
  IFS='|' read cls opts mar rev want <<E
$c
E
  d="\\def\\sideofclass{$cls}\\def\\sideofopts{$opts}\\def\\sideofwant{$want}"
  [ -n "$mar" ] && d="$d\\def\\sideofmargin{$mar}"
  [ -n "$rev" ] && d="$d\\def\\sideofreverse{}"
  pdflatex -interaction=nonstopmode -jobname=sideof "$d\\input{test/sideof}" >/dev/null 2>&1 \
    || { echo "FAILED: $c"; grep -A2 '^!' sideof.log | head -3; status=1; continue; }
  grep 'sideof test' sideof.log
done
exit $status
