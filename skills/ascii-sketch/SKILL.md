---
name: ascii-sketch
description: Use when a doc page, design note or chat answer needs to show a screen, panel, layout or architecture/network diagram — draws a plain-ASCII sketch that renders the same in any font.
---

# ASCII sketch

IMPORTANT!!! Only ASCII: `+ - |` for boxes, `<-` for arrows, `...` for
ellipsis. No box-drawing characters, Unicode arrows or emoji: fonts render
them at different widths and the box falls apart. Every line of a box has the
same length; count before you commit.

## UI layout

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

## Architecture diagram

One box per component (network, service, host), side by side or stacked;
`<------>` or `-->` between boxes for links, with the link name above the
arrow. Inside a box: name, address range or role, then the parts that matter.
Pad every box to the same width. Example: hub-and-spoke network.

```
+---------------------------------+        +---------------------------------+        +---------------------------------+
| vnet-stg                        |        | vnet-hub                        |        | vnet-prod                       |
| 10.30.0.0/16   (stg spoke)      |        | 10.0.0.0/16    (hub)            |        | 10.20.0.0/16   (prod spoke)     |
|                                 |        |                                 |        |                                 |
| snet-aks-sys     10.30.0.0/26   |  peer  | +-------------------------+     |  peer  | snet-data      10.20.4.0/24     |
|   controller pod, LB .60        |<------>| | fw-hub       10.0.4.4   |     |<------>|   pg-prod      10.20.4.4        |
| snet-aks-workers 10.30.0.128/26 |        | | fwpolicy-hub            |     |        |   delegated, no NSG             |
| snet-pe          10.30.0.64/27  |        | +-------------------------+     |        | snet-app, snet-platform         |
|                                 |        | VPN gateway, DNS resolver       |        |   -> rt-prod 0/0 -> fw          |
| rt-stg                          |        |                                 |        | k8s, mgmt, AppGW, ...           |
|   0.0.0.0/0 -> 10.0.4.4         |        |                                 |        |                                 |
+---------------------------------+        +---------------------------------+        +---------------------------------+
```

- Indent two spaces for what belongs to the line above (a pod in a subnet, a
  route in a route table).
- Anonymize: generic names (`vnet-prod`, `pg-prod`) and private ranges, never
  real tenant, product or region names.
