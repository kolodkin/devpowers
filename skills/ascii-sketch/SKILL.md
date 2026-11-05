---
name: ascii-sketch
description: Use when a doc page, design note or chat answer needs to show a screen, panel, layout or architecture/network diagram — draws a plain-ASCII sketch that renders the same in any font.
---

# ASCII sketch

IMPORTANT!!! Only ASCII: `+ - |` boxes, `<-` arrows, `...` ellipsis. No
box-drawing characters, Unicode arrows or emoji: fonts render them at
different widths and boxes break. Every line of a box has the same length;
count before you commit.

## UI layout

One box per screen or panel, then a bullet per control. Show structure, not
pixels: what is where and what it is called. Example: a query panel.

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

## Architecture diagram

One box per component (network, service, host), side by side or stacked, all
the same width. Link boxes with `<------>` or `-->`, link name above the arrow.
Inside: name, address range or role, then the parts that matter. Example:
hub-and-spoke network.

```
+---------------------------------+        +---------------------------------+        +---------------------------------+
| vnet-web                        |        | vnet-hub                        |        | vnet-analytics                  |
| 10.110.0.0/16  (web spoke)      |        | 10.100.0.0/16  (hub)            |        | 10.120.0.0/16  (data spoke)     |
|                                 |        |                                 |        |                                 |
| snet-frontend  10.110.1.0/24    |  peer  | +-------------------------+     |  peer  | snet-warehouse 10.120.1.0/24    |
|   app service, PE .10           |<------>| | fw-hub     10.100.1.4   |     |<------>|   sql-dw       10.120.1.5       |
| snet-api       10.110.2.0/24    |        | | fwpolicy-hub            |     |        |   private endpoint only         |
|   api scale set                 |        | +-------------------------+     |        | snet-etl       10.120.2.0/24    |
| snet-pe        10.110.3.0/27    |        | VPN gateway, DNS resolver       |        |   -> rt-analytics 0/0 -> fw     |
| rt-web                          |        | Bastion                         |        | databricks, storage, ...        |
|   0.0.0.0/0 -> 10.100.1.4       |        |                                 |        |                                 |
+---------------------------------+        +---------------------------------+        +---------------------------------+
```

- Indent two spaces for what belongs to the line above (a database in a
  subnet, a route in a route table).
- Anonymize: generic names (`vnet-web`, `sql-dw`) and private ranges, never
  real tenant, product or region names.
