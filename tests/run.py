#!/usr/bin/env python3
"""Render the test documents and assert the position of the notes
relative to the caption and the figure image in each output format.

Usage: python3 tests/run.py  (from the repository root or from tests/)
"""

import re
import subprocess
import sys
import zipfile
from pathlib import Path

TESTS_DIR = Path(__file__).resolve().parent

FAILURES = []


def check(label, ok, detail=""):
    status = "ok" if ok else "FAIL"
    print(f"  [{status}] {label}" + (f" ({detail})" if detail and not ok else ""))
    if not ok:
        FAILURES.append(label)


def render(doc, fmt):
    print(f"rendering {doc}.qmd --to {fmt} ...")
    res = subprocess.run(
        ["quarto", "render", f"{doc}.qmd", "--to", fmt],
        cwd=TESTS_DIR, capture_output=True, text=True,
    )
    check(f"{doc} renders to {fmt}", res.returncode == 0, res.stderr[-500:])
    return res.returncode == 0


def html_order(doc, figid):
    """Return the order of caption / image / notes markers inside a figure."""
    html = (TESTS_DIR / f"{doc}.html").read_text()
    i = html.find(f'id="{figid}"')
    if i < 0:
        return None
    seg = html[i:i + 3000]
    events = [(m.start(), m.group(0))
              for m in re.finditer(r"<figcaption|<img|quarto-figure-notes", seg)]
    names = {"<figcaption": "caption", "<img": "img",
             "quarto-figure-notes": "notes"}
    return [names[e[1]] for e in sorted(events)][:3]


def text_order(path, markers):
    """True if every marker appears in `path` in the given order."""
    text = (TESTS_DIR / path).read_text()
    pos = -1
    for m in markers:
        i = text.find(m, pos + 1)
        if i < 0:
            return False
        pos = i
    return True


def docx_order(doc, markers):
    """True if every marker appears in word/document.xml in order.

    Use "<w:drawing" as a marker for the figure image.
    """
    with zipfile.ZipFile(TESTS_DIR / f"{doc}.docx") as z:
        xml = z.read("word/document.xml").decode("utf8")
    pos = -1
    for m in markers:
        i = xml.find(m, pos + 1)
        if i < 0:
            return False
        pos = i
    return True


# --- basic.qmd: default locations (caption bottom, notes bottom) -----------

if render("basic", "html"):
    for figid in ["fig-md", "fig-chunk"]:
        got = html_order("basic", figid)
        check(f"basic/{figid}: img, caption, notes",
              got == ["img", "caption", "notes"], str(got))
    html = (TESTS_DIR / "basic.html").read_text()
    check("basic/tbl-fruit: notes in table footer",
          "quarto-table-notes" in html)

if render("basic", "latex"):
    check("basic/fig-md latex: image, caption+notes",
          text_order("basic.tex", [
              "scatter.png",
              "\\caption{\\label{fig-md}",
              "Markdown-figure",
          ]))

if render("basic", "typst"):
    check("basic/fig-md typst: image then caption(notes)",
          text_order("basic.typ", [
              "scatter.png",
              "Markdown-figure",
          ]))

if render("basic", "docx"):
    check("basic/fig-md docx: image, caption, notes",
          docx_order("basic", [
              "<w:drawing",
              "A caption at the bottom",
              "Markdown-figure",
          ]))

# --- cap-location.qmd: document-level fig-cap-location: top ----------------

if render("cap-location", "html"):
    for figid in ["fig-md", "fig-chunk"]:
        got = html_order("cap-location", figid)
        check(f"cap-location/{figid}: caption, img, notes",
              got == ["caption", "img", "notes"], str(got))
    got = html_order("cap-location", "fig-top")
    check("cap-location/fig-top: caption, notes, img",
          got == ["caption", "notes", "img"], str(got))

if render("cap-location", "latex"):
    check("cap-location/fig-md latex: caption, image, notes",
          text_order("cap-location.tex", [
              "\\caption{\\label{fig-md}",
              "scatter.png",
              "Markdown-figure",
          ]))
    check("cap-location/fig-chunk latex: caption, image, notes",
          text_order("cap-location.tex", [
              "\\caption{\\label{fig-chunk}",
              "fig-chunk-1.pdf",
              "\\emph{Notes:} Chunk",
          ]))

if render("cap-location", "typst"):
    check("cap-location/fig-md typst: image then notes in body",
          text_order("cap-location.typ", [
              "scatter.png",
              "Markdown-figure",
          ]))

if render("cap-location", "docx"):
    check("cap-location/fig-md docx: caption, image, notes",
          docx_order("cap-location", [
              "A caption on top",
              "<w:drawing",
              "Markdown-figure",
          ]))
    check("cap-location/fig-top docx: caption, notes, image",
          docx_order("cap-location", [
              "Caption on top, notes on top too",
              "ride with the top caption",
              "<w:drawing",
          ]))

# --- chunk-cap-location.qmd: chunk-level fig-cap-location: top -------------

if render("chunk-cap-location", "html"):
    got = html_order("chunk-cap-location", "fig-chunk")
    check("chunk-cap-location/fig-chunk: caption, img, notes",
          got == ["caption", "img", "notes"], str(got))

# ---------------------------------------------------------------------------

print()
if FAILURES:
    print(f"{len(FAILURES)} check(s) FAILED:")
    for f in FAILURES:
        print(f"  - {f}")
    sys.exit(1)
print("All checks passed.")
