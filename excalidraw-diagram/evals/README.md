# Evals

Four scenarios in `scenarios.json`, each `{id, skills, query, files, expected_behavior}`.
They target the behaviours that are easy to get wrong and cheap to check by reading the
transcript:

| Scenario | What it catches |
|---|---|
| `simple-conceptual-no-overreach` | Research Mandate and evidence artifacts leaking into diagrams that don't need them; skipping the mandatory render loop on "easy" requests |
| `technical-evidence-and-sections` | One-shot JSON generation instead of section-by-section; placeholder labels instead of researched ones; never opening `json-schema.md` |
| `resume-half-built` | Starting over instead of resuming; missing the dangling `boundElements` reference; seed-namespace collisions |
| `offline-render` | Any regression that reintroduces a CDN fetch into the render path |

`fixtures/half-built.excalidraw` is section 1 of a two-section diagram, with a deliberate
dangling arrow reference (`arrow_to_section2` listed in `ingress_rect.boundElements` but
absent from `elements`) - the resume scenario expects it to be found and repaired.

There is no runner: run a scenario by starting a session with the query, then grade the
transcript against `expected_behavior`.
