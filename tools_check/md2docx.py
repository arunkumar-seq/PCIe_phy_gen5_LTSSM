#!/usr/bin/env python3
"""Minimal, dependency-light Markdown -> .docx converter for docs/RTL_CHANGELOG.md.

Handles exactly the constructs used in that document: ATX headings (h1-h4),
pipe tables, fenced code blocks, blockquotes, bullet/numbered lists, horizontal
rules, and inline **bold**, `code` and *italic*. Anything unrecognised is emitted
as a plain paragraph, so the conversion never silently drops content.

    python3 tools_check/md2docx.py docs/RTL_CHANGELOG.md docs/RTL_CHANGELOG.docx
"""
import re
import sys

from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.shared import Pt, RGBColor

MONO = "Consolas"
BODY = "Calibri"


def add_runs(par, text):
    """Emit inline markup: **bold**, `code`, *italic*."""
    # split on the three inline constructs, keeping the delimiters
    for tok in re.split(r"(\*\*.+?\*\*|`[^`]+`|\*[^*]+\*)", text):
        if not tok:
            continue
        if tok.startswith("**") and tok.endswith("**") and len(tok) > 4:
            par.add_run(tok[2:-2]).bold = True
        elif tok.startswith("`") and tok.endswith("`") and len(tok) > 2:
            r = par.add_run(tok[1:-1])
            r.font.name = MONO
            r.font.size = Pt(9)
            r.font.color.rgb = RGBColor(0xA3, 0x1D, 0x1D)
        elif tok.startswith("*") and tok.endswith("*") and len(tok) > 2:
            par.add_run(tok[1:-1]).italic = True
        else:
            par.add_run(tok)


def split_row(line):
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [c.strip() for c in line.split("|")]


def is_sep(line):
    return bool(re.fullmatch(r"\|?[\s:|-]+\|?", line.strip())) and "-" in line


def convert(md_path, docx_path):
    lines = open(md_path, encoding="utf-8").read().split("\n")
    doc = Document()
    style = doc.styles["Normal"]
    style.font.name = BODY
    style.font.size = Pt(10.5)

    i = 0
    while i < len(lines):
        line = lines[i]

        # fenced code block
        if line.strip().startswith("```"):
            i += 1
            buf = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                buf.append(lines[i])
                i += 1
            i += 1  # closing fence
            for cl in buf:
                p = doc.add_paragraph()
                p.paragraph_format.space_after = Pt(0)
                p.paragraph_format.left_indent = Pt(14)
                r = p.add_run(cl if cl else " ")
                r.font.name = MONO
                r.font.size = Pt(8.5)
            doc.add_paragraph()
            continue

        # table
        if line.strip().startswith("|") and i + 1 < len(lines) and is_sep(lines[i + 1]):
            header = split_row(line)
            i += 2
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(split_row(lines[i]))
                i += 1
            ncols = len(header)
            t = doc.add_table(rows=1, cols=ncols)
            t.style = "Light Grid Accent 1"
            t.alignment = WD_TABLE_ALIGNMENT.LEFT
            for c, txt in enumerate(header):
                cell = t.rows[0].cells[c]
                cell.text = ""
                add_runs(cell.paragraphs[0], txt.replace("**", ""))
                for r in cell.paragraphs[0].runs:
                    r.bold = True
                    r.font.size = Pt(9)
            for row in rows:
                cells = t.add_row().cells
                for c in range(ncols):
                    txt = row[c] if c < len(row) else ""
                    cells[c].text = ""
                    add_runs(cells[c].paragraphs[0], txt)
                    for r in cells[c].paragraphs[0].runs:
                        r.font.size = Pt(9)
            doc.add_paragraph()
            continue

        # heading
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            lvl = len(m.group(1))
            h = doc.add_heading(level=min(lvl, 4))
            add_runs(h, m.group(2).replace("**", ""))
            i += 1
            continue

        # horizontal rule
        if re.fullmatch(r"\s*(-{3,}|\*{3,}|_{3,})\s*", line):
            p = doc.add_paragraph()
            p.paragraph_format.space_before = Pt(4)
            pPr = p._p.get_or_add_pPr()
            from docx.oxml import OxmlElement
            from docx.oxml.ns import qn
            bdr = OxmlElement("w:pBdr")
            bot = OxmlElement("w:bottom")
            bot.set(qn("w:val"), "single")
            bot.set(qn("w:sz"), "6")
            bot.set(qn("w:space"), "1")
            bot.set(qn("w:color"), "AAAAAA")
            bdr.append(bot)
            pPr.append(bdr)
            i += 1
            continue

        # blockquote (may span lines)
        if line.strip().startswith(">"):
            buf = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                buf.append(re.sub(r"^\s*>\s?", "", lines[i]))
                i += 1
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Pt(20)
            add_runs(p, " ".join(b for b in buf if b))
            for r in p.runs:
                r.font.color.rgb = RGBColor(0x44, 0x44, 0x44)
                r.italic = True
            continue

        # bullet list
        m = re.match(r"^(\s*)[-*+]\s+(.*)$", line)
        if m:
            depth = len(m.group(1)) // 2
            p = doc.add_paragraph(style="List Bullet" if depth == 0 else "List Bullet 2")
            add_runs(p, m.group(2))
            i += 1
            continue

        # numbered list
        m = re.match(r"^(\s*)(\d+)[.)]\s+(.*)$", line)
        if m:
            p = doc.add_paragraph(style="List Number")
            add_runs(p, m.group(3))
            i += 1
            continue

        # blank
        if not line.strip():
            i += 1
            continue

        # ordinary paragraph, joining wrapped continuation lines
        buf = [line.strip()]
        i += 1
        while i < len(lines) and lines[i].strip() and not re.match(
            r"^\s*(#{1,6}\s|[-*+]\s|\d+[.)]\s|>|`{3}|\||-{3,}\s*$)", lines[i]
        ):
            buf.append(lines[i].strip())
            i += 1
        p = doc.add_paragraph()
        add_runs(p, " ".join(buf))

    doc.save(docx_path)
    print(f"wrote {docx_path}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    convert(sys.argv[1], sys.argv[2])
