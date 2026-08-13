# knowledge-management-rulebook

Rulebook for the `knowledge-management` role (contract v3 role-handoff protocol).

- **decides**: 개별 이슈의 교훈이 조직 차원에서 재사용 가능한 형태로 축적·색인되는가
- **use_when**: 여러 이슈의 회고가 쌓여 지식 큐레이션이 필요할 때
- **produces**: curated pattern-library entry, cross-issue index, supersession note
- **hand-off**: 단일 이슈 회고 자체는 → issue-retrospective

## Install

```
claude plugin marketplace add tokenmaxxxer/knowledge-management-rulebook
claude plugin install knowledge-management
```

## Layout

- `playbook/<axis>.md` — operational decision-rule playbook (issue #1174):
  condition→choice→source rules, one file per decision axis
  (`pattern-extraction`, `taxonomy-tagging`, `supersession-lifecycle`,
  `structure-findability`, `curation-pruning`), each with a
  `rule_count_floor:`/`axis:` front-matter pair and at least one
  `**REMOVAL**`-marked subtractive rule per axis.
- `knowledge-management/.claude-plugin/plugin.json` — plugin manifest
- `knowledge-management/hooks/hooks.json` — SessionStart wiring
- `knowledge-management/hooks/directive.sh` — SessionStart role directive
