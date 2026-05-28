#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""
e2e-screenshots-report — post-process Playwright screenshots into a
self-contained HTML report.

Walks a Playwright test-results directory, collects every PNG produced by
`screenshot: 'on'` (Playwright JS) or `--screenshot on` (pytest-playwright),
groups them by test, and emits a single `index.html` with the images
base64-embedded — no external assets.

Usage:
    uv run report.py --in test-results [--out /tmp/e2e-report/index.html]
    python report.py --in test-results [--out /tmp/e2e-report/index.html]
"""
from __future__ import annotations

import argparse
import base64
import re
from html import escape
from pathlib import Path


def collect(in_dir: Path) -> list[tuple[str, Path]]:
    """Return [(label, png_path)] in stable order.

    Playwright writes screenshots under `test-results/<test-id>/<name>.png`.
    Use the test-id directory name as the human label.
    """
    shots: list[tuple[str, Path]] = []
    for png in sorted(in_dir.rglob("*.png")):
        rel = png.relative_to(in_dir)
        parts = rel.parts
        if len(parts) >= 2:
            test_label = humanize(parts[0])
            shot_label = png.stem
            shots.append((f"{test_label} — {shot_label}", png))
        else:
            shots.append((png.stem, png))
    return shots


def humanize(test_id: str) -> str:
    """Clean a Playwright test-id directory name into something readable.

    Examples:
        specs-login-Login-flow-chromium  ->  specs/login Login flow (chromium)
        test_login_py_test_signin        ->  test_login.py test_signin
    """
    # JS: hyphen-joined. Python pytest-playwright: underscore-joined.
    # Heuristic: split on runs of '-' or '_', restore '/' between top dirs.
    parts = re.split(r"[-_]+", test_id)
    # Pull off a trailing browser-engine token if present.
    browsers = {"chromium", "firefox", "webkit"}
    suffix = ""
    if parts and parts[-1].lower() in browsers:
        suffix = f" ({parts.pop().lower()})"
    return " ".join(parts) + suffix


def build_report(shots: list[tuple[str, Path]], out_path: Path) -> Path:
    out_path.parent.mkdir(parents=True, exist_ok=True)

    nav: list[str] = []
    sections: list[str] = []
    for i, (label, png) in enumerate(shots, 1):
        data = base64.b64encode(png.read_bytes()).decode("ascii")
        anchor = f"shot-{i}"
        nav.append(f'<a href="#{anchor}">{i:02d}. {escape(label)}</a>')
        sections.append(
            f'<section id="{anchor}">'
            f'<h2>{i:02d}. {escape(label)}</h2>'
            f'<img src="data:image/png;base64,{data}" alt="{escape(label)}">'
            f'</section>'
        )

    html = f"""<!doctype html>
<html><head><meta charset="utf-8"><title>e2e screenshot report</title>
<style>
  :root {{ color-scheme: dark; }}
  body {{ margin: 0; background: #0d1117; color: #c9d1d9;
         font: 14px/1.5 system-ui, -apple-system, sans-serif;
         display: grid; grid-template-columns: 280px 1fr; }}
  nav {{ position: sticky; top: 0; height: 100vh; overflow: auto;
         padding: 16px; border-right: 1px solid #30363d; }}
  nav a {{ display: block; color: #58a6ff; text-decoration: none;
          padding: 4px 0; font-size: 13px; }}
  nav a:hover {{ text-decoration: underline; }}
  main {{ padding: 24px; max-width: 1400px; }}
  section {{ margin-bottom: 40px; }}
  h2 {{ margin: 0 0 12px; font-size: 16px; color: #f0f6fc; }}
  img {{ max-width: 100%; border: 1px solid #30363d; border-radius: 6px;
         display: block; }}
</style></head><body>
<nav>{"".join(nav)}</nav>
<main>{"".join(sections)}</main>
</body></html>"""

    out_path.write_text(html, encoding="utf-8")
    return out_path


def main() -> None:
    ap = argparse.ArgumentParser(description="post-process Playwright screenshots into a self-contained HTML report")
    ap.add_argument("--in", dest="in_dir", required=True, type=Path,
                    help="Playwright test-results directory")
    ap.add_argument("--out", type=Path, default=Path("/tmp/e2e-report/index.html"),
                    help="output HTML path (default /tmp/e2e-report/index.html)")
    args = ap.parse_args()

    if not args.in_dir.is_dir():
        raise SystemExit(f"input directory not found: {args.in_dir}")

    shots = collect(args.in_dir)
    if not shots:
        raise SystemExit(
            f"no PNGs found under {args.in_dir} — did Playwright run with "
            "screenshot=on (JS) or --screenshot on (Python)?"
        )

    out = build_report(shots, args.out)
    print(f"report: {out}  ({len(shots)} screenshots)")


if __name__ == "__main__":
    main()
