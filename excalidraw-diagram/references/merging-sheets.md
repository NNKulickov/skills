# Merging Multiple Sheets Into One

A C4 set, or any multi-sheet diagram, sometimes needs a single merged `.excalidraw` for
review or handoff. This is not the same as the section-by-section build in SKILL.md - here
you are combining several **already-complete** files, each with its own id space.

## Mechanics, in order

1. **Prefix every element id by sheet.** `l1_rect1`, `l2m2_arrow3` - so ids from
   different sheets can never collide once merged.
2. **Rewrite every reference to those ids**, not just the elements themselves:
   `containerId` on text elements, `startBinding.elementId` and `endBinding.elementId` on
   arrows, every `boundElements[].id`, `groupIds`, and `frameId`. A reference left
   pointing at the old id produces a label with no box, or an arrow bound to nothing.
3. **Compute each sheet's bounding box and shift its coordinates** so sheets don't
   overlap - translate `x`/`y`, never rescale `width`/`height`.
4. **Drop duplicate titles and legends.** A merged file keeps one legend, not one per
   source sheet.
5. **Check that elements from different sheets don't overlap geometrically** after the
   shift - a bounding-box check, not a visual guess.

## How to run it

Do this by parsing the JSON in one `python3 - <<'EOF' ... EOF` command, not by writing a
script file to disk - the same rule as the ban on generator scripts in SKILL.md, for the
same reason: an intermediate file nobody asked for.
