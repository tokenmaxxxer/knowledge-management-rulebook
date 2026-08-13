---
axis: pattern-extraction
rule_count_floor: 10
---

# Pattern extraction from issue retrospectives

Research trail: ACM "Knowledge Management with Patterns" (patterns as generalized, self-descriptive units distinct from raw stories/anecdotes), Wikipedia "Postmortem documentation", LSA Global project-postmortem-analysis practitioner guidance, and 2601.22758 "AutoRefine: From Trajectories to Reusable Expertise" (cross-trajectory pattern extraction — recurring patterns across multiple executions signal generalizability; a single execution does not), all fetched this session.

## Rules

1. When a single issue's retrospective surfaces a lesson, do not promote it to a pattern-library entry on the strength of that one occurrence — hold it as a candidate until a second, independently-caused issue reproduces the same condition→choice shape; AutoRefine's cross-trajectory method extracts patterns from batches of trajectories specifically because a lone success/failure cannot be told apart from noise. source: https://arxiv.org/pdf/2601.22758

2. When deciding whether a retrospective finding is pattern-shaped, require it to state a condition (the recurring situation) and a choice (what a practitioner should do differently next time) — a finding that only narrates what happened, with no transferable condition→choice pair, stays in the issue's own retrospective record and is never copied into the pattern library. source: https://cacm.acm.org/research/knowledge-management-with-patterns/

3. When two or more retrospectives independently name the same root cause under different surface symptoms, extract the pattern at the root-cause level, not at each symptom's level — the ACM patterns literature frames a pattern's value as distilling the *essence* across instances, so indexing by symptom instead of cause produces duplicate near-identical entries that fragment the index built in [[taxonomy-tagging]]. source: https://cacm.acm.org/research/knowledge-management-with-patterns/

4. When a postmortem is being scheduled as a knowledge-management activity, run it while the causal chain is still fresh (immediately after resolution, not batched at a later sprint boundary) — LSA Global's postmortem-analysis guidance frames postmortems as most reliable "with little effort" when memory of the actual sequence of decisions is intact, and delay is the single largest cause of postmortems collapsing into generic "communicate better" filler. source: https://lsaglobal.com/project-management-postmortem-analysis-leveraging-insights/

5. When extracting a pattern, capture the *contrastive* evidence — not only what the successful resolution did, but what the failed first attempt(s) did that didn't work — because AutoRefine's cross-trajectory analysis treats absence-in-failures as evidence for generalizability equal in weight to presence-in-successes; a pattern entry with no failure-side contrast is only half-verified. source: https://arxiv.org/pdf/2601.22758

6. When a candidate pattern's condition can only be verified by someone who was in the original issue's thread, rewrite the condition until it is checkable by a reader with no access to that thread — patterns exist to be reused by practitioners who were not present at the original incident, so an un-rewritable, context-locked condition is not yet pattern-shaped and belongs in the source issue's own record, not the shared library. source: https://cacm.acm.org/research/knowledge-management-with-patterns/

7. **REMOVAL**: When a pattern candidate restates a language/framework default or a step already mandated by an existing gate script or CI check, drop it rather than filing it as a new pattern — a pattern's job is to capture judgment a mechanical check cannot make; duplicating an already-enforced rule only adds a second, driftable copy of the same constraint. source: https://cacm.acm.org/research/knowledge-management-with-patterns/

8. **REMOVAL**: When the retrospective's lesson is "we should have tested this," do not file it as a standalone pattern-library entry — this class of finding is symptom-level, not pattern-level (rule 3), and belongs instead as a line item on the specific test/CI gate it should have tripped; filing it generically produces a pattern-library entry no future reader can act on differently from "be more careful." source: https://cacm.acm.org/research/knowledge-management-with-patterns/

9. When more than one candidate pattern from the same batch of retrospectives share an identical condition clause, merge them into one entry with multiple linked source issues rather than filing near-duplicates — Wikipedia's postmortem-documentation norms treat the postmortem record itself as the durable source-of-truth per incident, so the pattern library should point back at (not re-narrate) each contributing issue. source: https://en.wikipedia.org/wiki/Postmortem_documentation

10. When a pattern is extracted, record which issue(s) it came from and the date, using the same evidence-trail discipline this repo already requires of record-writing sessions (a bare pattern assertion with no traceable source issue is exactly the unverifiable-claim shape the parent repo's record-claim-guard already refuses) — an untraceable pattern cannot be re-verified when the underlying system changes and the pattern needs re-testing.

11. When a pattern has been reused successfully by a second, unrelated issue after being filed, mark it as confirmed/reinforced rather than leaving it at the same confidence as a freshly-filed single-source candidate — this is the promotion counterpart to rule 1's demotion gate, and gives the [[curation-pruning]] axis's staleness review a signal to distinguish a live pattern from one nobody has used since filing.
