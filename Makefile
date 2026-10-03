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

test:margintest.pdf tufte.pdf ragged.pdf defer.pdf phantom.pdf float.pdf stretch.pdf issue-15.pdf columnwidth.pdf

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

# Two runs: the first saves where the note ends up, the second checks it.
columnwidth.pdf:marginfix.sty test/columnwidth.tex
	pdflatex -interaction=nonstopmode test/columnwidth.tex >/dev/null || true
	pdflatex -interaction=nonstopmode test/columnwidth.tex >/dev/null \
	  || { grep -A3 '^!' columnwidth.log; exit 1; }
	@grep 'columnwidth test:' columnwidth.log

clean:
	rm *.log *.aux *.pdf tufte.out marginfix.sty
