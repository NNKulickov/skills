# Quality Checklist

Read this once the render-view-fix loop has converged, before telling the user the diagram
is done. Items 21-27 can only be answered from the rendered PNG, not from the JSON.

## Severity and Acceptance Threshold

Score findings against this checklist as **critical / major / minor**, not a bare
pass/fail, and report a percentage rather than "done / not done" - a percentage shows the
distance to the goal and forces ranking instead of a binary shrug.

- **Critical**: a lost node or connection, two abstraction levels mixed on one sheet, an
  unreadable render, a binding or id reference pointing at nothing.
- **Major**: everything else in items 1-20 and 22-27 that meaningfully hurts the argument
  the diagram is making.
- **Minor**: cosmetic - spacing a few pixels off, a label that could be tighter.

**Acceptance threshold: zero critical findings and a score of 90 or higher.** While even
one critical finding stands, the score cannot be raised above the threshold regardless of
how good everything else looks - a diagram with one lost node is not "92% done", it is
not done.

## Depth & Evidence (Check First for Technical Diagrams)
1. **Research done**: Did you look up actual specs, formats, event names?
2. **Evidence artifacts**: Are there code snippets, JSON examples, or real data?
3. **Multi-zoom**: Does it have summary flow + section boundaries + detail?
4. **Concrete over abstract**: Real content shown, not just labeled boxes?
5. **Educational value**: Could someone learn something concrete from this?

## Conceptual
6. **Isomorphism**: Does each visual structure mirror its concept's behavior?
7. **Argument**: Does the diagram SHOW something text alone couldn't?
8. **Variety**: Does each major concept use a different visual pattern?
9. **No uniform containers**: Avoided card grids and equal boxes?

## Container Discipline
10. **Minimal containers**: Could any boxed element work as free-floating text instead?
11. **Lines as structure**: Are tree/timeline patterns using lines + text rather than boxes?
12. **Typography hierarchy**: Are font size and color creating visual hierarchy (reducing need for boxes)?

## Structural
13. **Connections**: Every relationship has an arrow or line
14. **Flow**: Clear visual path for the eye to follow
15. **Hierarchy**: Important elements are larger/more isolated

## Technical
16. **Text clean**: `text` contains only readable words
17. **Font**: `fontFamily: 3`
18. **Roughness**: `roughness: 0` for clean/modern (unless hand-drawn style requested)
19. **Opacity**: `opacity: 100` for all elements (no transparency)
20. **Container ratio**: <30% of text elements should be inside containers

## Visual Validation (Render Required)
21. **Rendered to PNG**: Diagram has been rendered and visually inspected
22. **No text overflow**: All text fits within its container
23. **No overlapping elements**: Shapes and text don't overlap unintentionally
24. **Even spacing**: Similar elements have consistent spacing
25. **Arrows land correctly**: Arrows connect to intended elements without crossing others
26. **Readable at export size**: Text is legible in the rendered PNG
27. **Balanced composition**: No large empty voids or overcrowded regions
