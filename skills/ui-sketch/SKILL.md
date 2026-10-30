---
name: ui-sketch
description: Use when a doc page, design note or chat answer needs to show a screen, panel or layout — draws a plain-ASCII layout sketch that renders the same in any font.
---

# UI sketch

IMPORTANT!!! Only ASCII: `+ - |` for boxes, `<-` for arrows, `...` for
ellipsis. No box-drawing characters, Unicode arrows or emoji: fonts render
them at different widths and the box falls apart. Every line of a box has the
same length; count before you commit.

One box per screen or panel, followed by a bullet per control. Show structure,
not pixels: a reader should see what is where and what it is called. Example:
a query panel.

```
+-------------------------------------------------+
| (o) default               <- connection status  |
| [ query ]  [ Predefined queries... v ]  [ Save ]|
| +---------------------------------------------+ |
| | SELECT ...                                  | |  <- SQL textarea
| +---------------------------------------------+ |
| [Execute] [Fields]  Limit [100]  Offset [0]     |
+-------------------------------------------------+
```

- `[Label]` is a button, `[ value ]` an input, `v` a dropdown, `...` content
  cut short.
- A nested box is a region: textarea, table, card, sidebar.
- Annotate with `<- note` to the right, outside or at the edge of the box;
  no prose inside the drawing.
- Labels read exactly as the screen shows them, and the bullets below use the
  same labels in **bold**.
- Keep it under 15 lines; a second sketch is for a different state (a
  modal, an empty state), not more detail.
