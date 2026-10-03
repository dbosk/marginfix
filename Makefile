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

SPLITRULES_JOBS=splitrules-within splitrules-beyond splitrules-write
FLOATS_CASES=plain ragged wide overfull group nested left verso side marker two topbot block split deferred lost
FLOATS_JOBS=$(foreach c,$(FLOATS_CASES),$(foreach m,reserve use,floats-$(c)-$(m)))
ARTICLE_FLOATS_JOBS=article-floats-reserve article-floats-use

test:margintest.pdf tufte.pdf ragged.pdf defer.pdf phantom.pdf float.pdf stretch.pdf issue-15.pdf anchorpage.pdf priority-test \
	$(SPLITRULES_JOBS:=.pdf) modechange.pdf modechange-warn.pdf off-test \
	$(FLOATS_JOBS:=.pdf) floats-test $(ARTICLE_FLOATS_JOBS:=.pdf) beamer-floats.pdf

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
# failed check is a LaTeX error, so make stops.  We also check that the
# reproducers give the warnings of their mode.
PRIORITY_TESTS=priority fill split stress-3 stress-8b
PRIORITY_MODES=warn defer split
PRIORITY_JOBS=$(foreach t,$(PRIORITY_TESTS),$(foreach m,$(PRIORITY_MODES),$(t)-$(m)))

.PHONY: priority-test regress
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
	@case $* in \
	  priority-warn|fill-warn) grep -q 'to a later page;' $*.log;; \
	  priority-defer) grep -q 'to the next, to keep' $*.log;; \
	  priority-split|fill-split|split-split) grep -q 'split at the end' $*.log;; \
	esac || { echo "$*: expected warning missing"; exit 1; }
	@case $* in fill-warn) grep -q 'did not fit and' $*.log;; \
	  split-split) grep -q 'between paragraphs (LT1)' $*.log;; esac \
	  || { echo "$*: expected warning missing"; exit 1; }

# Where notes are split (test/splitrules.tex): around the slack, and when
# a \write stops the scan.
$(SPLITRULES_JOBS:=.pdf): %.pdf: marginfix.sty test/splitrules.tex
	t=$*; for i in 1 2 3; do \
	  pdflatex -interaction=nonstopmode -jobname=$* \
	    "\\def\\prioritymode{split}\\def\\splitcase{$${t#*-}}\\input{test/splitrules}" \
	    >/dev/null || { grep -A3 '^!' $*.log; exit 1; }; done
	@grep 'splitrules (' $*.log

# Changing the mode in the document, and the file names of notes in
# included files (test/modechange.tex): first in mode defer after the
# change, then in mode warn throughout, where both inclusions warn.
modechange.pdf modechange-warn.pdf: marginfix.sty test/modechange.tex \
	test/modechange-part.tex test/prioritycheck.tex
	m=$(if $(findstring warn,$@),warn,defer); for i in 1 2 3; do \
	  pdflatex -interaction=nonstopmode -jobname=$(basename $@) \
	    "\\def\\modeB{$$m}\\input{test/modechange}" >/dev/null \
	  || { grep -A3 '^!' $(basename $@).log; exit 1; }; done
	@grep 'prioritytest (' $(basename $@).log
	@n=$$(grep -c 'Margin note from test/modechange-part.tex:' \
	  $(basename $@).log); \
	case $@ in modechange-warn.pdf) test $$n -eq 2;; *) test $$n -eq 1;; esac \
	  || { echo "$@: expected warnings naming the included file"; exit 1; }

.PHONY: off-test
off-test:marginfix.sty
	test/offmode.sh

# Notes beside bottom floats (test/floats.tex): each kind of table in each
# mode, with the checks of the test, and then test/floatsmode.sh, which
# checks that the tables that extend into the margin keep it empty.
$(FLOATS_JOBS:=.pdf): %.pdf: marginfix.sty test/floats.tex
	t=$*; t=$${t#floats-}; for i in 1 2 3; do \
	  pdflatex -interaction=nonstopmode -jobname=$* \
	    "\\def\\floatcase{$${t%-*}}\\def\\besidemode{$${t##*-}}\\input{test/floats}" \
	    >/dev/null || { grep -A3 '^!' $*.log; exit 1; }; done
	@grep 'floatstest (' $*.log

.PHONY: floats-test
floats-test:marginfix.sty
	test/floatsmode.sh

# The same in the article class (footnotes at the foot), and in beamer
# (which only has to load it).
$(ARTICLE_FLOATS_JOBS:=.pdf): %.pdf: marginfix.sty test/floats-article.tex
	t=$*; for i in 1 2; do \
	  pdflatex -interaction=nonstopmode -jobname=$* \
	    "\\def\\besidemode{$${t##*-}}\\input{test/floats-article}" \
	    >/dev/null || { grep -A3 '^!' $*.log; exit 1; }; done

beamer-floats.pdf: marginfix.sty test/floats-beamer.tex
	pdflatex -interaction=nonstopmode -jobname=beamer-floats \
	  test/floats-beamer.tex >/dev/null || { grep -A3 "^!" beamer-floats.log; exit 1; }

# The default mode must typeset every test exactly as the version before
# deferrable notes did.
regress:marginfix.sty
	test/regress.sh $(BASE)

clean:
	rm *.log *.aux *.pdf tufte.out marginfix.sty
