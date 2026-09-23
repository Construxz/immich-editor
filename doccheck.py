#!/usr/bin/env python3
"""Checks the project documentation for the errors that stay silent.

Broken links and dead anchors go unnoticed as long as nobody clicks.
Duplicate point numbers appear when two sessions write in parallel. Those
are errors, because something is demonstrably broken. References to deleted
points and files grown too long are hints -- there judgment decides whether
the reference is history or decay.

    python doccheck.py [directory] [--max-lines 600]
    python doccheck.py --selftest

Exit 1 as soon as an error was found. Standard library only.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import unquote

LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
#: inline code: what looks like a link in it is none
CODE_SPAN = re.compile(r"`[^`\n]*`")
HEADING = re.compile(r"^#{1,6}\s+(.*?)\s*$", re.M)
#: `**B7.`, `**A4b.` at line start -- a point of the intent file
POINT = re.compile(r"^\*\*([A-Z]\d+[a-z]?)\.", re.M)
#: a reference that is unambiguously meant as one
POINT_REF = re.compile(r"(?:ROADMAP|siehe|Siehe|Punkt)\s+\[?([A-Z]\d+[a-z]?)\b")


def slug(text: str) -> str:
    """GitHub's anchor form: lowercase, special characters removed, spaces to hyphens."""
    text = re.sub(r"[`*_\[\]()]", "", text).lower()
    text = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE)
    return re.sub(r"\s", "-", text.strip())


def collect(base: Path) -> dict[Path, str]:
    files = (sorted(base.glob("*.md")) + sorted(base.glob("docs/*.md"))
               + sorted(base.glob("specs/*.md")))
    return {p: p.read_text(encoding="utf-8", errors="replace") for p in files}


def check(base: Path, max_lines: int) -> tuple[list[str], list[str]]:
    docs = collect(base)
    errors: list[str] = []
    hints: list[str] = []
    if not docs:
        return ["keine .md-Dateien gefunden"], []

    anchors = {p: {slug(h) for h in HEADING.findall(t)} for p, t in docs.items()}
    points: dict[str, list[str]] = {}
    for p, t in docs.items():
        for pid in POINT.findall(t):
            points.setdefault(pid, []).append(p.name)

    for pid, places in sorted(points.items()):
        if len(places) > 1:
            errors.append(f"Punkt {pid} ist {len(places)}-mal vergeben: {', '.join(places)}")

    for p, t in docs.items():
        for target in LINK.findall(CODE_SPAN.sub("", t)):
            if target.startswith(("http://", "https://", "mailto:")):
                continue
            path, _, frag = target.partition("#")
            # relative to the linking file, not the base; decode %20 etc.
            target_file = p if not path else (p.parent / unquote(path)).resolve()
            if path and not target_file.exists():
                errors.append(f"{p.name}: Link ins Leere -> {path}")
                continue
            if frag and target_file in anchors and slug(frag) not in anchors[target_file]:
                errors.append(f"{p.name}: toter Anker -> {target}")

        # Not an error but a hint: a findings file may name a point done
        # since -- it records history. In an intent file the same reference
        # is decay.
        for ref in sorted(set(POINT_REF.findall(t))):
            if ref not in points:
                hints.append(f"{p.name}: Verweis auf {ref}, den es nicht (mehr) gibt")

        lines = t.count("\n") + 1
        if lines > max_lines:
            hints.append(f"{p.name}: {lines} Zeilen (Richtwert {max_lines})"
                            " -- kopiert es Befunde?")

    # ownership table: every file should be named somewhere
    named = " ".join(docs.values())
    for p in docs:
        if p.name.lower() in ("readme.md",):
            continue
        if p.name not in named.replace(p.read_text(encoding="utf-8", errors="replace"), "", 1):
            hints.append(f"{p.name}: nirgends verlinkt -- fehlt der Besitzeintrag?")

    return errors, hints


def selftest() -> int:
    import tempfile

    with tempfile.TemporaryDirectory() as tmp:
        b = Path(tmp)
        (b / "docs").mkdir()
        (b / "docs" / "S.md").write_text("# S\n\n[a](../A.md#titel)\n[r](../R%20%28x%29.md)\n", encoding="utf-8")
        (b / "R (x).md").write_text("# R\n", encoding="utf-8")
        (b / "A.md").write_text(
            "# Titel\n\n**B1.** offen\n**B1.** auch offen\n\n"
            "`![](x)` [weg](FEHLT.md)\n[tot](A.md#gibtesnicht)\n[gut](A.md#titel)\n"
            "siehe B9\n",
            encoding="utf-8",
        )
        errors, hints = check(b, 600)
        text = " | ".join(errors)
        assert any("B1 ist 2-mal" in f for f in errors), text
        assert any("Link ins Leere" in f for f in errors), text
        assert any("toter Anker" in f for f in errors), text
        assert not any("Verweis auf B9" in f for f in errors), text
        assert not any("#titel" in f for f in errors), text
        assert not any("S.md" in f for f in errors), text  # links from docs/ resolved relatively
        assert not any("-> x" in f for f in errors), text  # link in code span ignored
        assert any("Verweis auf B9" in h for h in hints), " | ".join(hints)
    print("selftest ok -- Fehler und Hinweise getrennt, gueltiger Anker nicht gemeldet")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("directory", nargs="?", default=".")
    ap.add_argument("--max-lines", type=int, default=600)
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()

    base = Path(a.directory).resolve()
    errors, hints = check(base, a.max_lines)
    for f in errors:
        print(f"FEHLER   {f}")
    for h in hints:
        print(f"hinweis  {h}")
    print(f"--- {len(errors)} Fehler, {len(hints)} Hinweise")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
