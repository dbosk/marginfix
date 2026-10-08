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

SIDE_CASES=mem2-right mem2-left mem2-outer mem2-inner mem2-default \
	mem1-right mem1-left mem1-inner mem1-reverse \
	art2-default art2-reverse art1-reverse

test:margintest.pdf tufte.pdf ragged.pdf defer.pdf phantom.pdf float.pdf stretch.pdf issue-15.pdf \
	$(SIDE_CASES:%=side-%.pdf)

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

# Which margin the notes go in (test/side.tex), for each class and setting.
# Two runs: the first saves where the notes end up, the second checks it.
$(SIDE_CASES:%=side-%.pdf): side-%.pdf: marginfix.sty test/side.tex
	for i in 1 2; do \
	  pdflatex -interaction=nonstopmode -jobname=side-$* \
	    "\\def\\sidecase{$*}\\input{test/side}" >/dev/null \
	  || { [ $$i = 1 ] || { grep -A3 '^!' side-$*.log; exit 1; }; }; done
	@grep 'sidetest (' side-$*.log

clean:
	rm *.log *.aux *.pdf tufte.out marginfix.sty
