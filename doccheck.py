#!/usr/bin/env python3
"""Prueft die Projektdokumentation auf die Fehler, die still bleiben.

Kaputte Links und tote Anker faellt niemandem auf, solange niemand klickt.
Doppelte Punktnummern entstehen, wenn zwei Sitzungen parallel schreiben. Das
sind Fehler, weil etwas nachweislich kaputt ist. Verweise auf geloeschte Punkte
und zu lang gewordene Dateien sind Hinweise -- dort entscheidet das Urteil, ob
der Verweis Geschichte ist oder Verfall.

    python doccheck.py [verzeichnis] [--max-lines 600]
    python doccheck.py --selftest

Exit 1, sobald ein Fehler gefunden wurde. Nur Standardbibliothek.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import unquote

LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
#: Inline-Code: was darin wie ein Link aussieht, ist keiner
CODE_SPAN = re.compile(r"`[^`\n]*`")
HEADING = re.compile(r"^#{1,6}\s+(.*?)\s*$", re.M)
#: `**B7.`, `**A4b.` am Zeilenanfang -- ein Punkt der Absichtsdatei
POINT = re.compile(r"^\*\*([A-Z]\d+[a-z]?)\.", re.M)
#: ein Verweis, der eindeutig als Verweis gemeint ist
POINT_REF = re.compile(r"(?:ROADMAP|siehe|Siehe|Punkt)\s+\[?([A-Z]\d+[a-z]?)\b")


def slug(text: str) -> str:
    """GitHubs Ankerform: klein, Sonderzeichen weg, Leerzeichen zu Bindestrich."""
    text = re.sub(r"[`*_\[\]()]", "", text).lower()
    text = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE)
    return re.sub(r"\s", "-", text.strip())


def sammle(basis: Path) -> dict[Path, str]:
    dateien = (sorted(basis.glob("*.md")) + sorted(basis.glob("docs/*.md"))
               + sorted(basis.glob("specs/*.md")))
    return {p: p.read_text(encoding="utf-8", errors="replace") for p in dateien}


def pruefe(basis: Path, max_lines: int) -> tuple[list[str], list[str]]:
    docs = sammle(basis)
    fehler: list[str] = []
    hinweise: list[str] = []
    if not docs:
        return ["keine .md-Dateien gefunden"], []

    anker = {p: {slug(h) for h in HEADING.findall(t)} for p, t in docs.items()}
    punkte: dict[str, list[str]] = {}
    for p, t in docs.items():
        for pid in POINT.findall(t):
            punkte.setdefault(pid, []).append(p.name)

    for pid, orte in sorted(punkte.items()):
        if len(orte) > 1:
            fehler.append(f"Punkt {pid} ist {len(orte)}-mal vergeben: {', '.join(orte)}")

    for p, t in docs.items():
        for ziel in LINK.findall(CODE_SPAN.sub("", t)):
            if ziel.startswith(("http://", "https://", "mailto:")):
                continue
            pfad, _, frag = ziel.partition("#")
            # relativ zur verlinkenden Datei, nicht zur Basis; %20 usw. dekodieren
            zieldatei = p if not pfad else (p.parent / unquote(pfad)).resolve()
            if pfad and not zieldatei.exists():
                fehler.append(f"{p.name}: Link ins Leere -> {pfad}")
                continue
            if frag and zieldatei in anker and slug(frag) not in anker[zieldatei]:
                fehler.append(f"{p.name}: toter Anker -> {ziel}")

        # Kein Fehler, sondern ein Hinweis: in einer Befunddatei darf ein
        # seither erledigter Punkt genannt sein -- sie haelt Geschichte fest.
        # In einer Absichtsdatei ist derselbe Verweis dagegen Verfall.
        for ref in sorted(set(POINT_REF.findall(t))):
            if ref not in punkte:
                hinweise.append(f"{p.name}: Verweis auf {ref}, den es nicht (mehr) gibt")

        zeilen = t.count("\n") + 1
        if zeilen > max_lines:
            hinweise.append(f"{p.name}: {zeilen} Zeilen (Richtwert {max_lines})"
                            " -- kopiert es Befunde?")

    # Besitztabelle: jede Datei sollte irgendwo benannt sein
    genannt = " ".join(docs.values())
    for p in docs:
        if p.name.lower() in ("readme.md",):
            continue
        if p.name not in genannt.replace(p.read_text(encoding="utf-8", errors="replace"), "", 1):
            hinweise.append(f"{p.name}: nirgends verlinkt -- fehlt der Besitzeintrag?")

    return fehler, hinweise


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
        fehler, hinweise = pruefe(b, 600)
        text = " | ".join(fehler)
        assert any("B1 ist 2-mal" in f for f in fehler), text
        assert any("Link ins Leere" in f for f in fehler), text
        assert any("toter Anker" in f for f in fehler), text
        assert not any("Verweis auf B9" in f for f in fehler), text
        assert not any("#titel" in f for f in fehler), text
        assert not any("S.md" in f for f in fehler), text  # Links aus docs/ relativ aufgeloest
        assert not any("-> x" in f for f in fehler), text  # Link im Code-Span ignoriert
        assert any("Verweis auf B9" in h for h in hinweise), " | ".join(hinweise)
    print("selftest ok -- Fehler und Hinweise getrennt, gueltiger Anker nicht gemeldet")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("verzeichnis", nargs="?", default=".")
    ap.add_argument("--max-lines", type=int, default=600)
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()

    basis = Path(a.verzeichnis).resolve()
    fehler, hinweise = pruefe(basis, a.max_lines)
    for f in fehler:
        print(f"FEHLER   {f}")
    for h in hinweise:
        print(f"hinweis  {h}")
    print(f"--- {len(fehler)} Fehler, {len(hinweise)} Hinweise")
    return 1 if fehler else 0


if __name__ == "__main__":
    sys.exit(main())
