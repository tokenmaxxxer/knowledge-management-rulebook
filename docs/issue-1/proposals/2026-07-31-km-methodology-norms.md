---
proposal: docs/issue-1/proposals/2026-07-31-km-methodology-norms.md
loop_state: proposed
upstream: []
---

# Proposal — knowledge-management 방법론·산출물 규범 (issue #1)

Subject: issue-1. Phase 1 output — proposal only, no execution. Approve is
required before phase 2 (plugin reflection) begins. Grounded in
`docs/issue-1/reports/knowledge-management/survey.md` (current-state gaps)
and `docs/issue-1/reports/knowledge-management/scout-brief.md` (field
sweep: ISO 30401, PMI/NASA lessons-learned & AAR, Alexander pattern
language, ADR).

## (a) Phase 1 제안서 규범

**방법론**: ADR (Architecture Decision Record) 형식을 채택한다. 이유는
[근거](#c-채택-근거) 참조.

**필수 섹션** (매 phase-1 proposal이 반드시 포함):

1. **Context** — 가치중립적 서술로 현재 상태와 문제를 기술 (이 role은
   survey.md를 그대로 인용/요약).
2. **Options considered** — 검토한 대안을 복수로 나열 (단일안만 제시하고
   "이것뿐" 이라 쓰는 것은 금지 — 최소 2안 비교, 기각 이유 포함).
3. **Decision & rationale** — 채택안과, 그 선택이 이 role의 의도된 가치와
   "맞아떨어질 수밖에 없는" 논리 (필드 조사 근거 인용 포함).
4. **Consequences** — 이 결정으로 쉬워지는 것과 어려워지는 것을 모두 기재
   (긍정적 결과만 쓰는 것 금지).
5. **Sources** — 조사에서 실제로 참조한 근거 목록 (스카우트가 돌았다면
   scout-brief.md 경로도 포함).

**근거 형식**: 모든 주장에 출처를 단다 — 웹 조사 결과는 URL, 저장소 내부
사실은 파일 경로:라인. 출처 없는 주장은 "가정(assumption)"으로 명시.

## (b) Phase 2 산출물 규범

`directive.sh`의 PRODUCES 세 가지(pattern-library entry, cross-issue
index, supersession note) 각각에 대해:

### 1. Pattern-library entry (`docs/patterns/<slug>.md`)

**방법론**: Alexander 패턴 언어의 Context → Problem → Solution →
Consequences 구조에, PMI 교훈 템플릿의 키워드 필드와 NASA AAR의 "왜
간극이 발생했는가" 인과 질문을 결합.

**필수 구성요소**:
- `title`, `keywords` (검색/색인용, front-matter)
- `source_issues` — 이 패턴을 추출한 원본 이슈 번호 목록 (재현/추적성)
- **Context** — 이 패턴이 나타나는 상황
- **Problem** — 반복되는 문제 (AAR의 "무엇이 일어났고, 무엇이 일어났어야
  했는가"에서 추출)
- **Why** — 간극의 원인 (AAR 4번째 질문: 왜 그 일이 일어났는가)
- **Solution** — 재사용 가능한 해법
- **Consequences** — 이 해법 적용 시 트레이드오프
- `supersedes` / `superseded_by` (있다면, front-matter 링크)

### 2. Cross-issue index (`docs/patterns/index.md`)

**방법론**: PMI의 키워드 기반 검색성 원칙.

**필수 구성요소**: 패턴명, keywords, source_issues, 현재 상태
(active/superseded)를 표로 나열 — 신규 entry 추가 시 이 표에도 반드시
한 행 추가.

### 3. Supersession note

**방법론**: ADR의 status 필드(superseded) 관행을 패턴 항목에 적용.

**필수 구성요소**: 대체되는 entry 경로, 대체 사유, 대체 entry 경로 —
구 entry의 front-matter에 `superseded_by`, 신 entry에 `supersedes`로
상호 링크 (한쪽만 링크하는 것 금지).

## (c) 채택 근거

- **ADR → phase 1 제안서**: 이슈 #1의 요구 (b)는 "채택 이유가 role의
  의도된 가치와 맞아떨어질 수밖에 없는 논리"를 요구한다. ADR은 정확히
  이 목적으로 수렴된 업계 표준 형식이다 — Options considered +
  Rationale + Consequences 삼조가 "왜 이것이 유일한 합리적 선택인가"를
  강제로 서술하게 만든다. 이 role의 다른 산출물(코드가 아닌 지식
  산출물)에도 자연스럽게 확장되는 범용 결정기록 형식이라 별도 방법론을
  새로 배울 필요가 없다 (issue-2 proposal도 이미 유사 구조를 자연발생적
  으로 쓰고 있었음 — `docs/issue-2/proposals/2026-07-31-core-canon-reference-conversion.md`
  참조, Request/Constraints/What will be done/Out of scope/Open findings).
- **Pattern language → pattern-library entry**: `directive.sh`가 이미
  이 산출물을 "pattern-library entry"라 명명하고 있다 — 이름 자체가
  Alexander의 형식을 가리킨다. Context/Problem/Solution 삼조는 재사용
  가능성(reusability)을 최적화하도록 설계된 유일한 검증된 형식이며, 이
  role의 존재 이유(여러 이슈의 교훈을 조직 차원에서 재사용 가능한 형태로
  축적)와 직접 일치한다.
- **PMI 키워드 필드 → 색인성**: PMI 조사는 키워드를 "재사용 성공의
  결정 요인 중 하나"로 명시한다. cross-issue index가 실제로 검색 가능
  하려면 entry마다 키워드가 있어야 한다 — 없으면 index는 목록일 뿐
  검색 가능한 자산이 아니다.
- **NASA AAR 인과 질문 → Why 필드**: 패턴이 원인 없이 해법만 담으면
  다른 이슈에 오적용될 위험이 크다. AAR의 "왜 그 일이 일어났는가"
  질문을 필수 필드로 강제하면 해법의 적용 범위를 재확인할 수 있다.
- **ISO 30401의 관리체계(리더십/감사 등)는 채택하지 않음**: 조직
  전체의 인증형 관리체계이며, 단일 저장소 role의 규모에 맞지 않는다
  (scout-brief.md "Skip" 참조). 다만 "지식은 관리되어야 할 자산이며
  캡처만으로 끝나지 않는다"는 핵심 must-be는 이미 (a)(b) 전체 설계에
  반영되어 있다 (index + supersession으로 자산의 생애주기를 관리).

## (d) 플러그인 반영 계획 (phase 2에서 실행)

- **directive.sh**: 현재 PRODUCES 줄의 세 artifact 이름은 이미
  정확 — core-canon 참조 형태(issue #2에서 stub화됨)를 그대로 유지하고
  값 자체는 변경하지 않는다 (스텁 형식이 `you_decide/use_when/produces/
  hand_off` 네 값 외 추가 파라미터를 받지 않으므로, 템플릿 세부사항은
  directive.sh가 아니라 handbook에 둔다).
- **`docs/handbooks/knowledge-management.md`**: (b)의 세 템플릿
  (pattern entry front-matter 필드, index 표 형식, supersession 상호
  링크 규칙)을 `write_scope` 아래 구체 섹션으로 추가한다. 이슈 #2에서
  이미 이 handbook이 role-unique 콘텐츠(핸드오프 텍스트)의 정착지로
  쓰였으므로 동일 패턴을 따른다 — 새 vendored 스크립트를 만들지 않는다.
- **record 필수 필드**: core canon `record-fields-gate.sh`는 이미
  일반 §20 필드(what-was-done/why/upstream-basis/loop_state/
  open-findings)를 강제한다 (issue #2에서 확인). 이 role만의 추가
  게이트 스크립트는 만들지 않는다 — survey.md의 constraint대로,
  core가 이미 제공하는 것을 재구현하지 않는다. 대신 phase-2
  record(`docs/issue-<n>/reports/knowledge-management.md`)의
  "what-was-done" 서술에 "이번에 추가/변경한 pattern entry가 (b)의
  필수 구성요소를 모두 채웠는가"를 self-check 항목으로 handbook에
  명시한다 (수동 체크리스트 — 새 코드 게이트 아님).
- **게이트**: 신규 코드 게이트를 추가하지 않는다. 이유: (1) 이슈 #2의
  결정으로 core-canon 참조만 허용되고 로컬 벤더 카피는 금지된 상태이며,
  이런 세부 필드 체크는 core에 아직 없는 role-specific 검증이라 core에
  일반화해 넣기 전에는 로컬 스크립트를 새로 만드는 것이 issue #2 결정과
  충돌한다; (2) handbook에 명시한 self-check 체크리스트로 충분히
  phase-2 산출 시점에 발견 가능하다. 향후 이 role의 패턴이 core로
  일반화될 경우(다른 role도 pattern-library를 쓰게 될 경우) core 쪽에
  일반 게이트 추가를 core 이슈로 제안하는 것을 남겨둔다 (out of scope,
  이 proposal의 범위 밖).

## Out of scope

- warrant-hunter, 세 gate 스크립트, directive.sh stub 형태 자체 —
  이미 issue #2에서 core-canon 참조로 전환 완료.
- 신규 core 이슈 제기 (§(d) 마지막 항목) — 이 저장소 범위 밖.
- phase 2 실제 실행(handbook 수정, pattern entry 작성) — Approve 이후.

## Open findings

없음 — scout 단계에서 발견된 두 스킵 결정(ISO 30401 관리체계, NASA
LLC 승인 단계)은 모두 (c)/(d)에 명시적 결정으로 반영했다.
