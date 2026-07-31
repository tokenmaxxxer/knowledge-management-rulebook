# Scout brief — issue #1 (phase 1)

Mode: parallel fan-out, 4 angles in one turn (WebSearch x4) — genuine
concurrent dispatch, not batched-sequential. Stages used: 1 (sweep only;
judge point 1 found no cross-angle mismatch worth a deepening round —
saturation reached, stopped at stage 1 of the 5-stage budget).

## Angles run

1. ISO 30401:2018 (KM systems standard — the org-level KM norm)
2. PMI / NASA lessons-learned & After Action Review process (the
   issue-retrospective-to-lesson pipeline norm)
3. Christopher Alexander pattern-language format (the reusable-solution
   entry-format norm)
4. Architecture Decision Record (ADR) format (the decision-proposal norm)

## Must-bes (Kano) extracted

- A KM system (ISO 30401) requires knowledge treated as a managed asset:
  captured, contextualized, and made retrievable — not just written once.
- A lessons-learned entry (PMI) is retrieval-dead without: category,
  root cause, action taken, and **keywords** for search — PMI explicitly
  calls keywords "one of the determinants of success" for reuse.
- AAR / NASA Pause-and-Learn answers four fixed questions: what happened,
  what was supposed to happen, why the gap, what's the learning — asked
  *throughout* a lifecycle, not only at close-out.
- A pattern-language entry (Alexander) is always Context → Problem →
  Solution → Consequences, in that order, self-referential to other
  patterns.
- An ADR is never accepted without: Context (value-neutral), Considered
  Options (plural), Decision, Rationale, and Consequences including
  negative ones — one AD per record.

## Performance axes (where strong exemplars visibly compete)

1. **Retrievability** — keyword/index discipline (PMI) vs. none.
2. **Traceability of the decision itself** — ADR's options-considered +
   rationale vs. a bare conclusion.
3. **Reusability shape** — pattern language's context/problem/solution
   triple vs. a narrative retrospective that doesn't decompose cleanly.

## Adopt / skip

- **Adopt**: ADR's five-part shape (Context, Options Considered, Decision,
  Rationale, Consequences) for this role's own phase-1 proposals — it is
  the field's converged answer to "how do you make a decision defensible
  and re-checkable later," which is exactly what issue #1 asks for (b):
  "그 방법론이 이 역할의 의도된 가치와 맞아떨어질 수밖에 없는 논리적 이유".
- **Adopt**: pattern-language's Context/Problem/Solution/Consequences
  shape + PMI's keyword field, merged, for phase-2 pattern-library
  entries — matches `directive.sh`'s existing PRODUCES line exactly
  (pattern-library entry) and gives it the field list it currently lacks.
- **Adopt**: AAR's "why the gap" causal question as the required
  extraction step feeding a pattern entry's Problem/Solution — without it
  entries risk being solution-only with no traceable cause.
- **Skip**: full ISO 30401 management-system apparatus (leadership,
  planning, audit cadence) — org-scale governance out of proportion to a
  single-repo role; only its "knowledge as a retrievable asset" must-be is
  load-bearing here, not the certification machinery.
- **Skip**: NASA's Lessons Learned Committee review/approval step — this
  repo already has its own approval mechanism (contract v3 s19 Approve
  gate); a second parallel review body would duplicate it.

## Gap line (survey vs. field)

Survey found: `directive.sh` PRODUCES already names the right artifact
kinds (pattern-library entry, cross-issue index, supersession note) —
the field's "must-be" of naming reusable-knowledge outputs is already met.
Survey found missing: no required-field list for any of the three kinds,
no proposal template, no index/keyword mechanism, no supersession-note
required fields. All four gaps are addressed by (a) and (b) in the
proposal below.

## Segment fit

This role sits one layer above `issue-retrospective` (single-issue
lessons) — it curates across issues, so the closest field analogue is not
a single AAR but a **pattern library fed by AARs**, which is the adopt
list above.

Sources:
- https://www.iso.org/standard/68683.html
- https://realkm.com/2022/02/02/the-essence-of-the-iso-30401-knowledge-management-standard/
- https://www.pmi.org/learning/library/applying-lessons-learned-implement-project-8344
- https://www.nasa.gov/wp-content/uploads/2025/09/after-action-review-v3.pdf
- https://maggieappleton.com/pattern-languages
- https://en.wikipedia.org/wiki/Pattern_(architecture)
- https://adr.github.io/
- https://github.com/joelparkerhenderson/architecture-decision-record
