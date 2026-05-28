#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["playwright>=1.40"]
# ///
"""
e2e-screenshots-report capture template (Python + Playwright).

Drives the project's e2e UI flows in a headless browser, captures labeled
full-page screenshots at each step, and bundles them into a self-contained
index.html (images embedded as base64).

The FLOWS block below must mirror the project's e2e test specs. When the specs
change (new data-testids, new steps, reorderings), update FLOWS to match —
otherwise the report drifts from what's actually tested.

Usage:
    uv run capture.py [--out-dir DIR]
    python capture.py [--out-dir DIR]

The base URL is set in the customize block below (override via the
`PLAYWRIGHT_BASE_URL` env var). Flow steps use relative paths
(`page.goto("/login")`) — the URL is resolved against the context's `base_url`,
matching how Playwright tests are written.

Prereq:
    playwright install chromium
"""
from __future__ import annotations

import argparse
import base64
import os
import re
from html import escape
from pathlib import Path

from playwright.sync_api import Page, sync_playwright


# --- customize per project ---------------------------------------------------

BASE_URL = os.environ.get("PLAYWRIGHT_BASE_URL", "http://localhost:8000")
OUT_DIR = Path("/tmp/e2e-report")


def flow_landing(page: Page, shot) -> None:
    """Placeholder flow — replace with steps mirrored from your e2e tests."""
    page.goto("/")
    shot("landing page")
    # Example:
    # page.click('[data-testid="login-button"]')
    # page.fill('[data-testid="email"]', "user@example.com")
    # shot("login form filled")


FLOWS = [
    ("landing", flow_landing),
    # ("query", flow_query),
    # ("settings", flow_settings),
]

# --- end customize ----------------------------------------------------------


def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-") or "shot"


def capture(out_dir: Path) -> list[tuple[str, Path]]:
    out_dir.mkdir(parents=True, exist_ok=True)
    shots: list[tuple[str, Path]] = []

    with sync_playwright() as pw:
        browser = pw.chromium.launch()
        try:
            for flow_name, flow_fn in FLOWS:
                context = browser.new_context(
                    base_url=BASE_URL,
                    viewport={"width": 1440, "height": 900},
                )
                page = context.new_page()

                def shot(label: str, _flow=flow_name, _page=page) -> None:
                    idx = len(shots) + 1
                    path = out_dir / f"{idx:03d}-{_flow}-{slug(label)}.png"
                    _page.screenshot(path=str(path), full_page=True)
                    shots.append((f"{_flow}: {label}", path))

                flow_fn(page, shot)
                context.close()
        finally:
            browser.close()

    return shots


def build_report(shots: list[tuple[str, Path]], out_dir: Path) -> Path:
    nav_links = []
    sections = []
    for i, (label, path) in enumerate(shots, 1):
        data = base64.b64encode(path.read_bytes()).decode("ascii")
        anchor = f"shot-{i}"
        nav_links.append(
            f'<a href="#{anchor}">{i:02d}. {escape(label)}</a>'
        )
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
         display: grid; grid-template-columns: 260px 1fr; }}
  nav {{ position: sticky; top: 0; height: 100vh; overflow: auto;
         padding: 16px; border-right: 1px solid #30363d; }}
  nav a {{ display: block; color: #58a6ff; text-decoration: none; padding: 4px 0; font-size: 13px; }}
  nav a:hover {{ text-decoration: underline; }}
  main {{ padding: 24px; max-width: 1400px; }}
  section {{ margin-bottom: 40px; }}
  h2 {{ margin: 0 0 12px; font-size: 16px; color: #f0f6fc; }}
  img {{ max-width: 100%; border: 1px solid #30363d; border-radius: 6px; display: block; }}
</style></head><body>
<nav>{"".join(nav_links)}</nav>
<main>{"".join(sections)}</main>
</body></html>"""

    report = out_dir / "index.html"
    report.write_text(html, encoding="utf-8")
    return report


def main() -> None:
    ap = argparse.ArgumentParser(description="capture labeled e2e screenshots into a self-contained HTML report")
    ap.add_argument("--out-dir", type=Path, default=OUT_DIR, help=f"output directory (default {OUT_DIR})")
    args = ap.parse_args()

    shots = capture(args.out_dir)
    if not shots:
        raise SystemExit("no screenshots captured — check your FLOWS definition")
    report = build_report(shots, args.out_dir)
    print(f"report: {report}  ({len(shots)} screenshots, base_url={BASE_URL})")


if __name__ == "__main__":
    main()
