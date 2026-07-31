#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
you_decide="YOU DECIDE: 개별 이슈의 교훈이 조직 차원에서 재사용 가능한 형태로 축적·색인되는가"
use_when="USE WHEN: 여러 이슈의 회고가 쌓여 지식 큐레이션이 필요할 때"
produces="PRODUCES (required record fields): curated pattern-library entry, cross-issue index, supersession note (if replacing an older pattern) — mechanically enforced by plugins km-adr-proposal (phase-1 norm) and km-pattern-entry + km-cross-index + km-supersession (phase-2 norm, jointly necessary); see docs/handbooks/knowledge-management.md for the composition table"
hand_off="HAND-OFF: 단일 이슈 회고 자체는 → issue-retrospective"
core_role_directive "$you_decide" "$use_when" "$produces" "$hand_off"
