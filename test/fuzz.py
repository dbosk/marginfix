#!/usr/bin/env python3
"""Write a random small document with margin material, for test/fuzzcheck.py.

Usage: test/fuzz.py SEED OUT.tex

The same seed gives the same document.  Article or memoir, one- or two-sided,
sometimes two columns; \\marginparpush varied; a priority mode; paragraphs with
plain and deferrable margin notes from one line to one and a half margins,
among them unsplittable ones (a rule, a box), several notes in a row, notes at
the top and at the foot of pages; floats that keep the margin beside them
empty; \\blockmargin and \\marginphantom; \\clearpage and \\newpage.  Note k
has a label m-k at its callout and n-k in the note; the number of notes is
written to the log as "fuzz notes=N", so that the check can tell a note that
was never set.
"""
import random
import sys

seed, out = int(sys.argv[1]), sys.argv[2]
r = random.Random(seed)
cls = r.choice(["article", "article", "memoir", "memoir", "memoir"])
opts = ["a4paper"]
if r.random() < .4:
    opts.append("twoside")
if r.random() < .15:
    opts.append("twocolumn")
push = r.choice(["0pt", "3pt", "7pt", "15pt"])
mode = r.choice(["warn", "defer", "split", "off"])
n = 0


def note():
    """One margin note, of a kind and height drawn at random."""
    global n
    n += 1
    k = n
    deferrable = r.random() < .3
    d = "\\marginnotedeferrable " if deferrable else ""
    kind = r.random()
    if kind < .45:
        body = f"N{k} \\lipsum[1][1-{r.randint(1, 4)}]"
    elif kind < .65:
        body = f"N{k} \\lipsum[{r.randint(1, 5)}-{r.randint(5, 9)}]"
    elif kind < .85:
        body = f"N{k}\\par\\rule{{1pt}}{{{r.uniform(.05, 1.5):.3f}\\textheight}}"
    else:
        body = f"\\rule{{1pt}}{{{r.uniform(.05, 1.5):.3f}\\textheight}}"
    return f"\\label{{m-{k}}}\\marginpar{{\\footnotesize{d}\\label{{n-{k}}}{body}}}"


pars = []
blocked = False
for p in range(r.randint(12, 35)):
    x = r.random()
    if x < .06:
        pars.append("\\clearpage")
    elif x < .12:
        pars.append("\\newpage")
    if r.random() < .08:
        res = "\\marginnotereservefloat" if r.random() < .6 else ""
        pars.append(f"\\begin{{figure}}[{r.choice(['t', 'b', 'h', 'tb', 'htbp'])}]{res}"
                    f"\\centering\\rule{{3cm}}{{{r.choice([3, 6, 10, 20])}\\baselineskip}}"
                    "\\caption{F}\\end{figure}")
    if blocked:
        pars.append("\\unblockmargin")
        blocked = False
    elif r.random() < .05:
        pars.append(f"\\blockmargin[{r.choice(['0pt', '20pt'])}]")
        blocked = True
    elif r.random() < .05:
        pars.append(f"\\marginphantom{{{r.choice([20, 60, 200])}pt}}")
    s = []
    if r.random() < .15:
        s.append(note())  # at the start of a paragraph, often a page's top
    for j in range(r.randint(1, 6)):
        s.append(f"\\lipsum[{r.randint(2, 30)}][1-{r.randint(1, 4)}]")
        y = r.random()
        if y < .35:
            s.append(note())
        if y < .07:
            s.append(note())  # notes in a row
            if r.random() < .5:
                s.append(note())
    pars.append(" ".join(s))
if blocked:
    pars.append("\\unblockmargin")
body = "\n\n".join(pars)
open(out, "w").write(f"""% fuzz seed {seed}: {cls} [{','.join(opts)}], push {push}, mode {mode}
\\documentclass[{','.join(opts)}]{{{cls}}}
\\usepackage{{lipsum}}
\\usepackage{{marginfix}}
\\marginnotepriority{{{mode}}}
\\setlength\\marginparpush{{{push}}}
\\extrafloats{{100}}
\\AtEndDocument{{\\typeout{{fuzz notes={n}}}}}
% a document of a few dozen pages that runs past 150 never ends: say so (the
% check stops it by the size of its files and by time)
\\makeatletter
\\AddToHook{{shipout/after}}{{\\ifnum\\c@page=151 \\typeout{{fuzz: runaway}}\\fi}}
\\makeatother
\\begin{{document}}
{body}
\\end{{document}}
""")
