---
role: "Claude Code 하네스 작업 규약 (철학 + SSOT 원칙 + 운영 정책) 의 단일 권위"
kind: operational
non_goals:
  - "프로덕트 철학 (docs/PHILOSOPHY.md)"
  - "하네스 흐름도 / 라우팅 / 작성 가이드 (.claude/README.md)"
  - "릴리스 절차 (`/release` 스킬)"
---

# 하네스 규약

이 프로젝트의 Claude Code 하네스 작업 규약 — 철학, SSOT 원칙, 운영 정책의 단일 권위.

## 철학

이 하네스는 **1인 운영 (solo operation) 을 기본 전제** 로 합니다. agent / skill 설계 시 항상 다음을 의식합니다:

- 단순성 우선 — 1인이 유지관리할 수 있는 복잡도 안에서 결정
- 팀 협업 본질 패턴 (Agent Teams 등) 은 디스카운트
- 운영 부담 최소화

다른 프로젝트로 이식할 때도 이 전제는 유지됩니다. 팀 환경 적용 시에는 별도 검토 필요.

## SSOT 원칙

- 다른 권위 문서의 정보는 링크/쿼리로 참조만 — 본문에 복제하지 않는다
- `.claude/skills/` / `.claude/agents/` 안의 각 skill·agent 는 자기 파일이 단일 권위 — skill 은 `SKILL.md`, agent 는 frontmatter. 별도 목록·요약 카탈로그 파일은 만들지 않는다.
- git tag / GitHub Release / milestone 은 `/release` 가 단일 동기화 — 직접 `git tag` · `gh release create` · milestone close 금지

## 스크립트 우선 원칙

결정적(deterministic) 판정 — 개수 비교·존재 확인·형식 검사 등 답이 기계적으로 정해지는 검증 — 은 모델 추론(에이전트 규칙)이 아니라 스크립트/bash 로 처리한다.

## 디버깅 원칙

**대원칙**: 증상 패치 전에 근본원인 먼저 — 데이터 흐름 추적 없이 fix 를 제안하거나, 검증 없이 원인을 단정하거나, 동시 다발 변경으로 좁혀가는 것은 red flag.

- 같은 증상에 fix 가 3회 이상 실패하면 증상 때우기를 멈추고 아키텍처 자체를 의심한다.
- `docs/troubleshooting.md` 는 해결한 이슈의 사후 카탈로그, 이 원칙은 작업 중 행동 규범 — 역할이 다르므로 참조 방향은 단방향(규범 → 카탈로그).

## 운영 정책

- 항상 존댓말로 응답
- 한국어 커밋 메시지 사용 가능
- 이슈 트래킹: GitHub Issues. 라벨은 세 축으로 구성:
  - **type 축** (변경 종류): `type:feat` / `type:fix` / `type:chore` / `type:refactor`
  - **상태 축**: `next` / `blocked`
  - **area 축** (영역): `area:meta` = 비-코드 작업 (`.claude/` 하네스 + `docs/` 문서). **미부착 = 제품 코드** (기본).
  - 혼합 작업(코드 + 하네스/문서 동시 변경)은 **핵심 산출물 기준**으로 `area:meta` 부착 여부를 판단한다.
- UI 변경 요청 인입 시 오케스트레이터가 **developer 위임 직전** 목업 우선 여부를 판정한다:
  - **트리거**: 명백히 가치 큰 경우만 — 새 화면/영역/패널 생성 또는 큰 레이아웃 재구성
  - **기본값**: skip — under-trigger 편향(놓침 허용, noise 최소화). 사용자 '목업 먼저' pull 로 양방향 오버라이드 가능. 게이트락 아님.
  - **흐름**: 목업 합의 후 **(필요 시)** `architect` → `developer` 순으로 이어진다
  - **상수·절차**: 컴포넌트 영역 `CLAUDE.md` 권위
- 대형 UI 변경(새 화면·레이아웃 재구성 등) 시 `architect` 에이전트 호출
- **architect 권고문 DeepSeek 추론검증 (opt-in)**: architect 권고문 수신 후, 메인 세션은 opt-in 으로 DeepSeek 추론모드 교차검증 패스를 사용자에게 제안한다. 기본 skip, 게이트락 아님 (외부 LLM 은 opt-in 이 원칙). architect 는 Bash tool 없음 → 메인 세션이 curl 실행.
  - **메커니즘**: `.claude/skills/qa/SKILL.md` Step 3a 의 deepseek curl+jq 블록과 동일 패턴 (`DEEPSEEK_API_KEY` 필요). 아래 deltas 만 적용:
    - 입력 = architect **권고문 전문** (git diff 아님)
    - JSON body 에 추론모드 추가: `"reasoning_effort":"high"` + `"thinking":{"type":"enabled"}` (순추론 검증이므로). 응답 추출은 동일 (`.choices[0].message.content`; `reasoning_content` 는 무시)
    - 검증 프롬프트 골자: "다음은 architect 권고문이다. 이미 채택된 권장 옵션에 대해서만 critical/suggestion/nice 로: (1) architect 가 기각하지 않았으나 더 단순한 대안 (2) 본문에 안 드러난 트레이드오프·운영부담 (3) SSOT/Out-of-Scope 충돌 (4) Decision 후보 누락. 동의 코멘트·요약 금지. 1인 운영 단순성을 판단축으로. 한국어 평이체."
  - findings 는 critical/suggestion/nice 로 분류 (파일:line 불필요 — 설계 단계라 권고문 항목 인용, 한국어 평이체). 메인 세션이 사용자에게 제시 → 결정 반영.
- 브랜치 네이밍 컨벤션:
  - **git 브랜치명 = worktree 통일 키** (정의·환경 매핑 권위: `docs/architecture.md`). 키는 **첫 push 전에** 최종 이름으로 확정하고, **push 후 리네임 금지** (preview 인프라 리소스 고아화 — 스택별 상세: `.claude/references/infra-gotchas.md`). 한 worktree = 한 브랜치.
  - 단발 이슈: `(feat|fix|chore)/issue-N-<slug>` (예: `chore/issue-56-branch-naming`). 연관 이슈 동시 처리 시 `(feat|fix|chore)/issue-N-M-<slug>` 허용.
  - 마일스톤 사이클 (`/plan` 단위): `cycle/<slug>` (예: `cycle/order-panel-revamp`). **버전 숫자를 브랜치명에 박지 않는다** — 슬러그가 유일성을 담당하고, 버전 번호는 `/release` 시점에 계산된다 (버전 SSOT = git tag max). type-free prefix — 사이클은 feat/fix/chore 가 섞이는 묶음이므로 type 미부착. 사이클 시작 시 **첫 push 전** 리네임.
  - `<slug>` 규칙: 작업/마일스톤 주제를 **kebab-case** (소문자 + 하이픈) 로. 통일 키 안정성을 위해 일관 표기 — `cycle/order-panel-revamp` (O), `cycle/OrderPanel` (X).
  - 자동 워크트리 (`claude/*`): isolation:worktree 로 생성되는 랜덤 브랜치. push 전 위 두 패턴 중 하나로 `git branch -m` 으로 rename 필수 (상세 절차: `.claude/skills/pr/SKILL.md` Step 0).
- 머지 명령 (워크트리 전제): 워크트리에서 PR 머지는 `gh pr merge <N> --squash` 만 — `--delete-branch` **금지** (워크트리 `main` 점유와 충돌 `fatal: 'main' is already used by worktree`; remote 브랜치는 repo 설정 `delete_branch_on_merge` 가 자동 삭제하므로 불필요).
