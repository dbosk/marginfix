marginfix.zip:marginfix.dtx marginfix.pdf marginfix.ins README
	mkdir marginfix
	cp $^ marginfix/
	zip -r $@ marginfix
	rm -rf marginfix

marginfix.sty:marginfix.dtx marginfix.ins
	yes | latex marginfix.ins

marginfix.pdf:marginfix.dtx
	pdflatex marginfix.dtx

.PHONY: test clean

test:margintest.pdf tufte.pdf ragged.pdf defer.pdf phantom.pdf float.pdf stretch.pdf issue-15.pdf anchorpage.pdf priority-test

margintest.pdf:marginfix.sty test/margintest.tex
	pdflatex test/margintest.tex

tufte.pdf:marginfix.sty test/tufte.tex
	pdflatex test/tufte.tex

ragged.pdf:marginfix.sty test/ragged.tex
	pdflatex test/ragged.tex

defer.pdf:marginfix.sty test/defer.tex
	pdflatex test/defer.tex

phantom.pdf:marginfix.sty test/phantom.tex
	pdflatex test/phantom.tex

float.pdf:marginfix.sty test/float.tex
	pdflatex test/float.tex

stretch.pdf:marginfix.sty test/stretch.tex
	pdflatex test/stretch.tex

issue-15.pdf:marginfix.sty test/issue-15.tex
	pdflatex test/issue-15.tex

# Two passes: the first records anchor pages, the second fixes placement.
anchorpage.pdf:marginfix.sty test/anchorpage.tex
	pdflatex test/anchorpage.tex
	pdflatex test/anchorpage.tex

# Deferrable notes: each test in each mode, three passes, since the checks
# (see test/prioritycheck.tex) read the pages from the previous run.  A
# failed check is a LaTeX error, so make stops.
PRIORITY_TESTS=priority stress-3 stress-8b
PRIORITY_MODES=warn defer split
PRIORITY_JOBS=$(foreach t,$(PRIORITY_TESTS),$(foreach m,$(PRIORITY_MODES),$(t)-$(m)))

.PHONY: priority-test
priority-test:$(PRIORITY_JOBS:=.pdf)

$(PRIORITY_JOBS:=.pdf): %.pdf: marginfix.sty test/prioritycheck.tex \
	$(PRIORITY_TESTS:%=test/%.tex)
	t=$*; for i in 1 2; do \
	  pdflatex -interaction=nonstopmode -jobname=$* \
	    "\\def\\prioritymode{$${t##*-}}\\input{test/$${t%-*}}" >/dev/null \
	  || true; done
	t=$*; pdflatex -interaction=nonstopmode -jobname=$* \
	  "\\def\\prioritymode{$${t##*-}}\\input{test/$${t%-*}}" >/dev/null \
	  || { grep -A3 '^!' $*.log; exit 1; }
	@grep 'prioritytest (' $*.log

clean:
	rm *.log *.aux *.pdf tufte.out marginfix.sty
