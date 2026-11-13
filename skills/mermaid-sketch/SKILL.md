---
name: mermaid-sketch
description: Use when a doc page, design note or chat answer needs a sequence, flow or state diagram - writes a Mermaid block, renders it in headless Chromium to validate the syntax, and shows the user the rendered image.
---

# Mermaid sketch

Write the diagram, render it, look at it, then show it. Never commit or
present a Mermaid block that has not been rendered once.

## 1. Write

- One diagram per idea, at most about 12 messages or nodes. A second diagram
  is for a different scenario, not more detail.
- Short participant aliases (`participant D as Dispatcher`); labels in plain
  words, as the surrounding text names things.
- No `;` in labels. Avoid `#`, `<`, `>` and quotes; reword instead.
- In a doc: one sentence above the block says what it shows. No prose inside
  the diagram beyond short `Note over` lines.

## 2. Render and validate

Put the Mermaid source in a file in the scratchpad (or extract it from the
doc), then render it:

```bash
node scripts/render.js diagram.mmd out.png
```

- `OK` means the syntax parsed. `ERR ...` is the parser message: fix the
  block and render again.
- Needs Node with Playwright and Chromium. Use the pre-installed ones; do
  not install another.
- The script pins Mermaid 10.9.1, older than GitHub's: diagram types newer
  than that fail here even if GitHub renders them.
- If the CDN is unreachable or the script cannot run, say the diagram is
  unrendered instead of claiming it works.

## 3. Look, then show

- Read the PNG yourself first: check for overlapping labels, clipped text
  and arrows pointing the wrong way. Fix and re-render before showing it.
- Send the PNG to the user as a rendered file, with a one-line caption.
- In chat, also include the Mermaid source in a fenced block so it can be
  copied.

## 4. Where it goes

- Docs rendered by GitHub or a Mermaid-enabled site: a ```` ```mermaid ````
  fenced block.
- If the target does not render Mermaid (plain terminals, some wikis), use
  the `ascii-sketch` skill instead.
