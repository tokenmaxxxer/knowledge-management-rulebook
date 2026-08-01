---
subject: issue-16
role: knowledge-management
loop_state: proposed
---

# Proposal — A+ 인증 마감: 인증 감사 차단 사유 해소 (issue-16)

## Context

2026-08-01 인증 감사(issue #16)가 4개 게이트(pattern-entry,
index-shape, index-pairing, supersession-pairing)에 unguarded
`gate-lib.sh` source, 3개 스위트 missing-core 테스트 누락,
`index-shape-gate.sh`의 죽은 Bash 분기를 A+ 차단 사유로 지목했다.
issue-13이 동일 결함 클래스를 `km-adr-proposal/hooks/adr-shape-gate.sh`
1건에 대해 이미 고쳤고, 그 기록
(`docs/issue-13/reports/knowledge-management.md`)에서 나머지 4개 파일을
"same diff shape, no new design work needed"로 명시 예고했다 — issue-16이
그 후속.

## Options considered

**A.** issue-13 shape를 4개 파일에 그대로 적용, missing-core 테스트는 4개
스위트 전부에 추가 — 균일 처리, 회귀 방지 최대.

**B.** 이슈 문구 그대로 3개 스위트에만 missing-core 테스트 추가 — 어느
게이트를 뺄지 판단할 근거가 리포 안에 없음(survey §3), 재감사에서
비대칭이 다시 지적될 위험.

**C.** `index-shape-gate.sh`의 죽은 Bash 분기를 matcher 확장으로 살리기
— 이미 구현·테스트된 분기를 도달 가능하게 만듦, issue-13이
`adr-shape-gate.sh`에 쓴 것과 동일 패턴.

**D.** 죽은 Bash 분기를 삭제 — 코드는 줄어들지만 이미 맞게 짜여 테스트된
fail-closed 보호(`docs/patterns/index.md`로의 Bash 쓰기 차단)를 버리는
것이라 방어 범위가 좁아짐.

## Decision

Option A + Option C 채택, Option B/D 기각.

- 4개 게이트 소스 라인 전부에 same-line `||` 가드 적용:
  ```
  . "${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/gate-lib.sh" || { echo "<gate>.sh: cannot source gate-lib.sh" >&2; exit 2; }
  ```
  대상: `km-pattern-entry/hooks/pattern-entry-gate.sh:2`,
  `km-cross-index/hooks/index-shape-gate.sh:2`,
  `km-cross-index/hooks/index-pairing-gate.sh:2`,
  `km-supersession/hooks/supersession-pairing-gate.sh:2`.
- missing-core 테스트는 **4개 스위트 전부**에 추가한다(이슈 문구는
  "3개"지만 3/4 비대칭을 정당화할 근거가 리포에 없다 — survey §3). 4개
  게이트 모두 동일 결함·동일 수정을 받으므로 회귀 방지 테스트도 균일하게
  두는 편이 안전하고, `adr-shape-gate.test.sh:431`의 기존 패턴(코어
  디렉터리를 존재하지 않는 경로로 돌려 exit 2 단언)을 그대로 재사용하므로
  추가 비용은 무시할 수준이다. record에 "이슈 문구는 3, 실제로는 4 적용,
  사유"를 명시해 감사 시 편차를 설명한다.
- `index-shape-gate.sh`의 죽은 Bash 분기는 matcher 확장으로 해소한다:
  `km-cross-index/hooks/hooks.json`에 `index-shape-gate.sh`용 `Bash`
  matcher 항목을 추가한다 — 기존 `index-pairing-gate.sh`의 `Bash`
  매칭과 공존(동일 이벤트에 여러 matcher가 걸리면 각각 실행됨,
  `adr-shape-gate.sh`가 이미 `Write|Edit|MultiEdit|NotebookEdit|Bash`
  단일 matcher로 이 패턴을 씀). 분기가 이미 정확히 구현·테스트되어
  있으므로 코드를 버리기보다 도달 가능하게 만드는 쪽이 issue-13 선례와
  일치하고, `docs/patterns/index.md`에 대한 Bash 쓰기를 fail-closed
  deny하는 보호를 실제로 켠다.

sales 전용 게이트는 knowledge-management 플러그인 셋에 존재하지 않아
이슈 요구사항 2번(core #78 의존)은 이 역할 범위에서 적용 대상 없음.

## Consequences

Easier: 4개 게이트 모두 코어 미해결 시 조용한 undefined-function
런타임 에러 대신 명확한 fail-closed deny(exit 2)로 통일되고,
`index-shape-gate.sh`의 Bash 경로 보호가 실제로 작동해 감사 대상 결함이
모두 사라진다. Harder: `index-shape-gate.sh` matcher 확장으로 동일
Bash 이벤트에 두 게이트(`index-shape-gate.sh`, `index-pairing-gate.sh`)가
순차 실행되어 훅 실행 비용이 소폭 늘고, 향후 두 게이트 중 하나만 수정할
때 실행 순서/중복 검사 여부를 함께 검토해야 한다.

## Sources

- `docs/issue-13/reports/knowledge-management.md` (issue-13 record, 동일
  결함 클래스의 기존 수정 및 후속 예고).
- `km-adr-proposal/hooks/adr-shape-gate.sh:17`,
  `km-adr-proposal/hooks/hooks.json:5` (기 적용된 가드/matcher 패턴).
- `km-cross-index/hooks/hooks.json`,
  `km-cross-index/hooks/index-shape-gate.sh:50-69` (죽은 Bash 분기
  현황, 이 리포 안의 1차 코드 조사).
