---
proposal: docs/issue-21/proposals/implementation.md
---

# Hunt record — issue-21-implementation

## after-proposal — stance 3: assume the rule as written cannot hold — find the state nothing maintains

Verdict: FINDING — the proposal's constraint "capture_point: retroactive must surface as a refusal loop_state (not-captured-at-resolution), never a silent pass" names an enforcement path that no hook maintains: capture_point lives in pattern-entry front matter (docs/patterns/*.md, checked only by km-pattern-entry/hooks/pattern-entry-gate.sh) while loop_state lives in the issue record's own front matter (docs/issue-<n>/reports/knowledge-management.md, checked only by core's out-of-repo record-fields-gate.sh, which per the proposal's own survey.md only matches loop_state against RECORD_FIELDS_TERMINAL_STATES for terminal-state purposes, not a full progress/refusal/error vocabulary or any cross-field mapping). No gate, hook, or script anywhere in this repo (or the vendored core repo referenced) reads capture_point and writes/validates loop_state, or vice versa; the plan section only proposes an enum check on capture_point in isolation ("add enum-value validation for capture_point ... mirroring the existing key-presence pattern"). The "surfaces as a refusal loop_state" guarantee is asserted only in prose, in two different documents (handbook text and this proposal), never in code that ties the two fields together.
Kind: design-error
Seed: git diff HEAD~1 HEAD (docs/issue-21/proposals/implementation.md, docs/issue-21/reports/implementation/survey.md; 2 new files, ~219 lines, docs-only)
cap_seconds: 120
tier: default
diff_stat_lines: 219
started_at: 2026-08-09T00:00:00Z
ended_at: 2026-08-09T00:02:00Z

### Reproduce
```
grep -rn "loop_state" --include=*.sh -r /home/jwjung/.tokenmaxxxer/work/knowledge-management-rulebook-issue-21-implementation
grep -rn "capture_point" -r /home/jwjung/.tokenmaxxxer/work/knowledge-management-rulebook-issue-21-implementation
find /home/jwjung/.tokenmaxxxer/work/knowledge-management-rulebook-issue-21-implementation -iname "record-fields-gate*"
```

### Observed
`loop_state` and `capture_point` occur in zero `.sh` files anywhere in the repo (only in the two new docs added by this diff); `record-fields-gate.sh` does not exist locally at all (it is a vendored core script referenced only by name). Nothing computes or checks the mapping capture_point=retroactive -> loop_state=not-captured-at-resolution.

### Expected
If the constraint "must surface as a refusal loop_state, never a silent pass" is to hold mechanically (as the proposal's own acceptance framing implies via `bash km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh` and `compliance-check.sh`), some gate must read both fields together and refuse the write when they diverge (capture_point: retroactive present without loop_state: not-captured-at-resolution in the corresponding record). No such gate is planned; the phase-2 "What will be done" section adds capture_point enum validation to pattern-entry-gate.sh only, with no code touching loop_state or cross-referencing the record file at all.
