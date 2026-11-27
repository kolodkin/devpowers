---
name: vmodel
description: Use when a change alters behavior, before writing its doc, test or code; when adding or changing a test; and when adding or editing a doc of record. The generic V-model method - a project's own `vmodel` skill extends it with its layers, paths and commands.
---

# V-model

Every behavior has a statement in a doc of record, and a test that names the
statement's ID (at implementation, a test beside the module). A change walks down the
docs, writing a failing test at each layer, then up the tests. When a plan
splits the work into tasks, each task follows this skill.

```
 down: statement, then a failing test          up: run the tests

 User             statement ............................ acceptance test
  Architecture       statement ..................... system test
   Design               statement .............. integration test
    Implementation         docstring ....... unit test
                                    code
```

Each dotted line is one pairing: an ID above implementation, the file name at
implementation.

## Project skill

This skill is the method. A project extends it with its own skill, by
convention `.claude/skills/vmodel/SKILL.md`, which names this one
(`devpowers:vmodel`) and holds only what is particular to the project:

- the layer table: each layer's doc of record and "Proved in" location;
- the docs root that ID prefixes start from;
- which layers share tests, if any;
- entry-layer examples for step 1;
- the commands for step 4, and the checker if there is one;
- house style for docs and tests, usually by naming the skills that own it.

Load both. Where they differ, the project skill wins. With no project skill,
find where the repo keeps docs and tests, fill the layer table from that, and
tell the user the mapping before using it.

## Layers

| Doc layer | Test layer | Doc of record states | A test covers |
|---|---|---|---|
| User | Acceptance | what a user calls, runs, sees or configures | a journey through the public interface, end to end |
| Architecture | System | the architecture: topology, deployment modes, data model, wire contracts, security model, limits | the system through its real interfaces (HTTP, CLI, protocol), on each supported backend |
| Design | Integration | a design inside the system: how components work together | several internal modules driven together |
| Implementation | Unit | one module's logic, in its docstring or leading comment | the module, from the test file beside it, no ID |

A project may merge or drop a layer; its table says so. Docs for
developers (testing, debugging, release) sit outside the V: no IDs, no
tests.

## Markers

An ID is the page's path under the docs root without `.md`, then a kebab-case
slug. The doc defines it on the line above the statement, writing only the
slug, since the page gives the prefix:

```md
<!-- in <docs root>/user/export.md: user/export/csv-download -->
<!-- req: csv-download -->
A user can download the current result as CSV.
```

A test names the full ID in a comment directly above the test or group, in
the language's comment syntax; several IDs are comma-separated:

```py
# req: user/export/csv-download
def test_csv_download():
```

Never reword a slug a test names. A marker outside the layer's "Proved in"
location is support, not proof.

## Tests on two layers

A test has one layer, unless the project skill names a pair of layers that
share tests. A shared test lives in the higher layer's location and names
both IDs. When such a test already walks the lower statement, add that
statement's ID to its marker; do not write a second test for it.

A unit test names no ID.

## Steps

1. **Name the entry layer: the highest one the change touches.** Anything a
   user calls, runs, sees or configures (a command, a screen, an error, a
   default, a public API signature): user. Topology, a data model, a wire
   contract, the security model: architecture. How internal components
   work together: design. Logic inside one module: implementation.
2. **Go down, one layer at a time, from the entry to implementation.** At
   each layer above implementation:
   - write or edit the statement in its doc of record;
   - give it an ID, or keep its existing one. How fine an ID is, is a
     judgment: give one per behavior a reader would call a separate promise.
     Test an edge case of one behavior under the same ID, or at a lower
     layer;
   - write a test that names the ID and fails now. A changed number or
     default is a changed statement: its test asserts the new value. The
     failing test may be an existing one whose assertion changes.

   At implementation: edit the module's docstring or leading comment and the
   test beside the module; no ID, no marker.

   For a layer the change does not alter, write one line: `Skipping <layer>:
   <why>.`
3. **Build.** Write the code that makes the tests pass.
4. **Go up.** Run every layer's tests, lowest first: the touched test files
   as a quick check, then each full suite, including the top layer's when
   untouched, since a change below can break a journey. Then the project's
   checker, if it has one. Independent suites run side by side.
5. **A failure goes back down the V to where it started.** Read the failing
   test's paired statement first: is the statement wrong, or the code? A
   failure seen at one layer often starts lower. The layer where it starts is
   the one whose statement and test were missing, so walk step 2 at that
   layer:
   - state the behavior there;
   - write the test at that layer that fails for the cause, and see it fail;
   - fix the code there, then go up again from that layer.

   A test that passes on retry ("flaky") still has a cause; never retry or skip
   it away.

## Tagging grows with changes

The statement a change edits gets its ID in that change, and so does the test
that proves it. A new page or test file gets its ID in the change that adds
it. A project with a checker may go further and fail any untagged page or
test file; its skill says so.

## Not covered

A pure refactor, a comment, or a docs wording fix that changes no behavior
skips the steps above; the doc and test rules still apply.

## Where a decision goes

A design decision (why this solution or technology) carries no ID: it explains
a statement, and no test proves it. It sits beside what it explains, as a
`## Why` section on that page, at that page's layer. A choice that spans
several pages goes in that layer's `decisions.md`.

## Writing a doc

A page holds one layer's content, in the present tense, describing current
behavior: no history, no proposals. Copy the shape of the nearest page, and
end with the `shortify` checklist on the pages you touched.

## Writing a test

Put a test in the lowest layer that can observe the behavior, and start from
the nearest existing test file: it shows the call shapes and fixtures.
