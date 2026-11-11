#!/usr/bin/env python3
"""Build test/fuzz.py's documents and check that marginfix ends and keeps its notes.

Usage: test/fuzzcheck.py [--base DIR] [--timeout S] [--work DIR] SEED...

Each seed's document is built with the marginfix.sty in the current directory
(and, with --base, with the one in DIR as well), pdflatex run after run until
the .aux file stops changing (at most 6 runs), each run under a timeout
(--timeout, 120 s).  Then one more run.  A build passes if:
- every run ends within the timeout and before page 150 (test/fuzz.py stops
  it there), and the .aux file settles;
- the run after it gives the same text (pdftotext) and pages;
- there is no LaTeX error but marginfix's "lost some margin notes";
- every note is set (its label n-k is in the .aux file) or named by a warning
  that it will be lost, at least as many warnings as notes not set;
- with --base, where the base set every note: no more pages than the base's
  build plus 2.
Prints a line per build, and a summary of counts; exit status 1 on a failure.
"""
import argparse
import json
import os
import resource
import re
import shutil
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument("--base")
ap.add_argument("--timeout", type=int, default=120)
ap.add_argument("--work", default="fuzz-work")
ap.add_argument("--keep", action="store_true", help="keep the builds")
ap.add_argument("seeds", nargs="+", type=int)
a = ap.parse_args()
sty = os.getcwd()


def limit():
    """No file of a run over 20 MB: a runaway stops there, not at the disk's end."""
    resource.setrlimit(resource.RLIMIT_FSIZE, (20 << 20, 20 << 20))


def build(seed, tag, stydir):
    d = os.path.join(a.work, f"{seed}-{tag}")
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)
    subprocess.run([sys.executable, os.path.join(here, "fuzz.py"), str(seed), os.path.join(d, "d.tex")],
                   check=True)
    env = dict(os.environ, TEXINPUTS=f"{os.path.abspath(stydir)}//:")
    res = dict(seed=seed, tag=tag, ended=True, settled=False, runs=0)

    def run():
        try:
            subprocess.run(["pdflatex", "-interaction=nonstopmode", "d.tex"], cwd=d, env=env,
                           capture_output=True, timeout=a.timeout, preexec_fn=limit)
            return True
        except subprocess.TimeoutExpired:
            return False
    def runaway():
        p = os.path.join(d, "d.log")
        return os.path.exists(p) and "fuzz: runaway" in open(p, errors="replace").read()
    prev = None
    for i in range(1, 7):
        res["runs"] = i
        if not run() or runaway():
            res["ended"] = False
            return res, d
        aux = open(os.path.join(d, "d.aux"), errors="replace").read()
        if aux == prev:
            res["settled"] = True
            break
        prev = aux
    text1 = subprocess.run(["pdftotext", "-layout", "d.pdf", "-"], cwd=d, capture_output=True,
                           errors="replace").stdout
    if not run():
        res["ended"] = False
        return res, d
    text2 = subprocess.run(["pdftotext", "-layout", "d.pdf", "-"], cwd=d, capture_output=True,
                           errors="replace").stdout
    res["stable"] = text1 == text2

    log = open(os.path.join(d, "d.log"), errors="replace").read()
    aux = open(os.path.join(d, "d.aux"), errors="replace").read()
    m = re.search(r"Output written on d\.pdf \((\d+) page", log)
    res["pages"] = int(m[1]) if m else 0
    res["notes"] = int(re.search(r"fuzz notes=(\d+)", log)[1]) if "fuzz notes=" in log else -1
    res["set"] = len(set(re.findall(r"\\newlabel\{n-(\d+)\}", aux)))
    res["warnedlost"] = len(re.findall(r"it will be lost", log.replace("\n", "")))
    errs = re.findall(r"^! (.*)", log, re.M)
    res["lostall"] = sum("lost some margin notes" in e for e in errs)
    res["errors"] = [e for e in errs if "lost some margin notes" not in e]
    return res, d


def verdict(res, base):
    why = []
    if not res["ended"]:
        why.append("never ends")
    elif not res["settled"]:
        why.append("doesn't settle")
    else:
        if not res["stable"]:
            why.append("a run from the settled .aux changes the text")
        if res["errors"]:
            why.append("errors: " + "; ".join(res["errors"][:2]))
        if res["notes"] < 0 or res["set"] + res["warnedlost"] < res["notes"]:
            why.append(f"{res['notes'] - res['set']} notes not set, {res['warnedlost']} named")
        if base and base.get("pages") and base.get("set") == base.get("notes") \
                and res["pages"] > base["pages"] + 2:
            why.append(f"{res['pages']} pages, base {base['pages']}")
    return why


os.makedirs(a.work, exist_ok=True)
failed = 0
counts = {}
for seed in a.seeds:
    base = None
    if a.base:
        base, bd = build(seed, "base", a.base)
        bw = verdict(base, None)
        counts["base " + ("pass" if not bw else bw[0].split(":")[0])] = \
            counts.get("base " + ("pass" if not bw else bw[0].split(":")[0]), 0) + 1
        print(json.dumps(dict(base, why=bw, errors=base.get("errors", [])[:2])))
        if not a.keep:
            shutil.rmtree(bd, ignore_errors=True)
    res, d = build(seed, "new", sty)
    why = verdict(res, base)
    key = "new " + ("pass" if not why else why[0].split(":")[0])
    counts[key] = counts.get(key, 0) + 1
    print(json.dumps(dict(res, why=why, errors=res.get("errors", [])[:2])))
    if why:
        failed += 1
    elif not a.keep:
        shutil.rmtree(d, ignore_errors=True)
print("fuzz summary:", json.dumps(counts, sort_keys=True))
sys.exit(1 if failed else 0)
