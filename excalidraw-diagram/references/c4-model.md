# C4 Model - notation for architecture split across abstraction levels

Use when the user picked **C4** in the Design Process Step 0 notation question (see
SKILL.md). C4 splits one system into a small set of abstraction levels, each drawn as its
own sheet, so a change to one module doesn't force a redraw of the whole set.

## Contents

- [The Four Levels](#the-four-levels) - Context, Container, Component, Code
- [One Sheet, One Level, One Container](#one-sheet-one-level-one-container) - the rule that keeps levels from bleeding together
- [Sheet Layout for a Set](#sheet-layout-for-a-set) - overview sheet plus one sheet per module
- [Notation Conventions](#notation-conventions) - shapes for person, container, component, external system, store, port
- [Legend Lives Once](#legend-lives-once) - overview sheet only
- [Boundary Connections Are Drawn Twice](#boundary-connections-are-drawn-twice) - exit on one sheet, entry on the other
- [Coverage Table](#coverage-table) - proving every connection landed somewhere

---

## The Four Levels

1. **Context** - the system as one box, with the people and external systems around it.
   For internal architecture work this is rarely a separate sheet - it's usually folded
   into the Container overview.
2. **Container** - the system's modules, services, or deployable units, still without
   internals. This is the **overview sheet** and is always drawn.
3. **Component** - what's inside one container: its components and what they call. One
   sheet **per container that needs the detail** - not one sheet trying to hold every
   container's internals at once.
4. **Code** - class/function level. Almost never drawn by hand for an architecture
   conversation; skip it unless the user explicitly asks for it.

In practice most sets draw two levels, not four: Container as the overview sheet, plus
Component as one sheet per module.

---

## One Sheet, One Level, One Container

Hard rule: a Component-level sheet expands **exactly one** container. Neighboring
containers appear on that sheet only as dashed ports referencing their own sheet - never
as expanded internals. A component that leaks onto another container's sheet as a full
block breaks the whole point of levels: the reader loses track of which zoom they're
looking at.

---

## Sheet Layout for a Set

- One overview sheet at Container level: every container as a single block (no
  internals), plus people, external systems, and shared stores.
- One sheet per container that needs Component-level detail.
- File naming pattern: `<System> - C4 L1 overview.excalidraw`,
  `<System> - C4 L2-<n> <container name>.excalidraw`.
- Render each file to a PNG next to it, same name.

---

## Notation Conventions

- **Person** - a stick figure, label under the shape.
- **Container** - a box, 2px frame, two-line label: the name plus a small `[Container]`.
- **Component** - a box inside the container's frame, small `[Component]` label.
- **External system** - transparent box, gray frame, small `[External]` label.
- **Store** - a cylinder: two ellipses plus two vertical lines.
- **Port to a neighboring container** - a dashed box labeled `→ <Container> · <name>`,
  naming the target sheet's file, standing in for that container's internals on this
  sheet.
- Fill color and `fillStyle` follow the project's status legend - see the `fillStyle`
  rule in `color-palette.md`, it applies here unchanged.
- Each sheet opens with a title and a breadcrumb line:
  `<System> › <Container> · <name>`.

---

## Legend Lives Once

The color legend belongs on the overview sheet only. Every other sheet gets one line:
"color key on the L1 overview sheet." Duplicating the legend on every sheet guarantees
the copies drift on the first edit to either one.

---

## Boundary Connections Are Drawn Twice

A connection that crosses a container boundary is drawn on **both** sheets it touches -
as an outgoing port on the sheet it leaves, and an incoming port on the sheet it enters.
This is not a duplicate to remove: the coverage table below must mark it as one
connection shown on two sheets, or a reviewer will flag it as an error that isn't one.

---

## Coverage Table

Before rendering, build a table: one row per sheet, listing which numbered connections
from the source registry (SKILL.md Design Process, the registry step) appear on it. Every
connection number from 1..N must appear on at least one row. Boundary-crossing
connections appear on two rows and are marked as such. This is what lets a reviewer say
"connection 27 isn't drawn anywhere" instead of discovering the gap by squinting at every
sheet in turn.

Write this table into a file next to the sheets (e.g. appended to the source registry
file, or its own `coverage.md`) - not just stated in the conversation. A table that only
ever existed in chat output is unavailable to whoever reviews the sheets later or resumes
the build in a fresh session.

