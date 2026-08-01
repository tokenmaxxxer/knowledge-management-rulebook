---
subject: issue-16
role: knowledge-management
loop_state: landed
---

# Record — A+ 인증 마감: 인증 감사 차단 사유 해소 (issue-16)

## Why

2026-08-01 A+ 인증 감사(issue #16)가 4개 게이트(`pattern-entry-gate.sh`,
`index-shape-gate.sh`, `index-pairing-gate.sh`,
`supersession-pairing-gate.sh`)의 unguarded `gate-lib.sh` source,
missing-core 회귀 테스트 누락, `index-shape-gate.sh`의 죽은 Bash 분기를
A+ 차단 사유로 지목했다. `docs/issue-16/proposals/knowledge-management/proposal.md`가
issue-13 선례(`docs/issue-13/reports/knowledge-management.md`, 동일 결함
클래스를 `adr-shape-gate.sh` 1건에 이미 적용하며 나머지 4개 파일을 후속
예고)를 이 4개 파일에 그대로 적용하는 Option A+C를 제시했고, 이슈 코멘트
`APPROVE issue-16/knowledge-management`(`JiwonJung94`, `approvers.md`
계정, single-account mode)로 승인됐다. 이 레코드는 그 결정을 그대로
실행한 결과다.

## What was done

1. 4개 게이트 소스 라인 전부에 same-line `||` 가드 적용
   (`adr-shape-gate.sh:17`와 동일 shape):
   - `km-pattern-entry/hooks/pattern-entry-gate.sh:2`
   - `km-cross-index/hooks/index-shape-gate.sh:2`
   - `km-cross-index/hooks/index-pairing-gate.sh:2`
   - `km-supersession/hooks/supersession-pairing-gate.sh:2`

   각각 `|| { echo "<gate>.sh: cannot source gate-lib.sh" >&2; exit 2; }`
   추가 — 코어 미해결 시 조용한 undefined-function 런타임 에러 대신
   명확한 fail-closed deny(exit 2)로 통일.
2. `km-cross-index/hooks/hooks.json`의 `index-shape-gate.sh` matcher를
   `Write|Edit|MultiEdit`에서 `Write|Edit|MultiEdit|Bash`로 확장 —
   `index-shape-gate.sh:50-69`의 이미 구현·테스트된 Bash 분기(
   `docs/patterns/index.md`에 대한 Bash 쓰기 fail-closed deny)를 실제로
   도달 가능하게 만들었다. 동일 Bash 이벤트에 `index-pairing-gate.sh`도
   걸리므로 두 게이트가 순차 실행된다(제안서에 예고된 트레이드오프).
3. missing-core 회귀 테스트를 **4개 스위트 전부**에 추가 —
   이슈 문구는 "3개"였지만 3/4 비대칭을 정당화할 리포 내 근거가
   없어(survey §3) 4개 게이트 모두 균일 처리, `adr-shape-gate.test.sh`의
   기존 패턴(코어 디렉터리를 존재하지 않는 경로로 돌려 exit 2/실패 단언)을
   재사용:
   - `km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh` — 새 케이스
     "missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere denies"
   - `km-cross-index/hooks/tests/index-shape-gate.test.sh` — 새 케이스
     "missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere denies"
   - `km-cross-index/hooks/tests/index-pairing-gate.test.sh` — 새 케이스 13
     "missing-core: CLAUDE_PLUGIN_ROOT_CORE pointed nowhere denies"
   - `km-supersession/hooks/tests/supersession-pairing-gate.test.sh` — 새
     케이스 12 "case12: missing-core denies" (기존 `run_gate_env` 헬퍼 재사용)

sales 전용 게이트는 knowledge-management 플러그인 셋에 존재하지 않아
이슈 요구사항 2번(core #78 의존)은 이 역할 범위에서 적용 대상 없음.

## Test / compliance-check output

이 diff가 건드린 4개 스위트 + 회귀 확인 목적의 `adr-shape-gate.test.sh`,
clean 배송 상태(rebase 후 origin/main 기준) clone에서 실행:

```
$ bash km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh
...
SUMMARY: 25 passed, 0 failed

$ bash km-cross-index/hooks/tests/index-shape-gate.test.sh
...
index-shape-gate.test.sh: 22 passed, 0 failed

$ bash km-cross-index/hooks/tests/index-pairing-gate.test.sh
...
index-pairing-gate.test.sh: 14 passed, 0 failed

$ bash km-supersession/hooks/tests/supersession-pairing-gate.test.sh
...
summary: 12 passed, 0 failed

$ bash km-adr-proposal/hooks/tests/adr-shape-gate.test.sh
...
26/26 passed
```

새로 추가된 missing-core 케이스는 각 스위트에서 `ok`로 통과
(`CLAUDE_PLUGIN_ROOT_CORE`를 존재하지 않는 경로로 돌려 gate-lib.sh
source 실패 → guard가 exit 2로 fail-closed 하는지 확인). 5개 스위트
합계 99/99 passed, 0 failed.

## Full-suite delivery status

이 리포의 게이트 테스트 스위트 전부 green:

```
km-supersession/hooks/tests/supersession-pairing-gate.test.sh   : 12 passed, 0 failed
km-adr-proposal/hooks/tests/adr-shape-gate.test.sh              : 26 passed, 0 failed
km-pattern-entry/hooks/tests/pattern-entry-gate.test.sh         : 25 passed, 0 failed
km-cross-index/hooks/tests/index-shape-gate.test.sh             : 22 passed, 0 failed
km-cross-index/hooks/tests/index-pairing-gate.test.sh           : 14 passed, 0 failed
```

## Open findings

없음 — 감사가 지목한 4개 게이트의 source 가드, missing-core 테스트,
`index-shape-gate.sh`의 죽은 Bash 분기가 전부 해소됐다.

## Next steps

issue-16 종결에 추가로 필요한 작업 없음: 감사 차단 사유 전부 해소,
테스트 전체 green, 레코드에 해소 확인(테스트 로그) 기록 완료.
