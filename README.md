# claude-harness

Mongshell 의 개인용 Claude Code 개발 하네스 SSOT.

`harness/` 아래의 agent·skill 이 단일 원본이고, `./sync-harness.sh sync` 로 각 프로젝트의 `.claude/` 에 배포됩니다. 배포본은 그 프로젝트 repo 에 커밋되므로 **clone 하는 모든 사람이 하네스를 함께 받습니다.**

## 왜 플러그인이 아닌가

Claude Code 플러그인으로 배포할 수도 있지만, 세 가지 이유로 파일 배포(vendoring)를 택했습니다.

- **협업자에게 설치를 요구하지 않는다.** 하네스 파일이 프로젝트 repo 안에 커밋되므로, 함께 개발하는 사람은 `git clone` 만 하면 됩니다. 이 저장소 접근 권한도 필요 없습니다.
- **이름이 일관된다.** 플러그인으로 배포하면 skill 이 `dev-harness:qa` 로 네임스페이스가 붙습니다. 하네스 본문에는 `/qa`·`/plan` 같은 자기참조가 150곳 넘게 있어서, 플러그인 프로젝트와 vendoring 프로젝트에서 호출 이름이 갈리면 본문을 두 벌로 유지해야 합니다.
- **하네스 버전이 repo 커밋에 고정된다.** 과거 커밋을 체크아웃하면 그 시절 하네스가 함께 딸려옵니다. 플러그인은 항상 최신이라 과거 재현이 어긋납니다.

## harness/ 사용법

```bash
./sync-harness.sh sync  ~/mongshell/git/<프로젝트>   # 배포 (프로젝트 .claude/ 에 씀)
./sync-harness.sh check ~/mongshell/git/<프로젝트>   # 검사만 (드리프트 있으면 exit 1)
```

`sync` 는 배포본 상단에 "직접 수정 금지" 배너를 붙입니다. 배너는 렌더 시점에 생성되므로 `check` 는 별도 해시를 들고 다니지 않고 **같은 입력으로 다시 렌더해 비교**합니다.

배포 후에는 프로젝트에서 `git diff` 로 확인하고 커밋하세요 — 협업자는 그 커밋으로 하네스를 받습니다. `check` 를 프로젝트의 검증 스킬에 편입하면 배포본을 직접 고친 드리프트가 잡힙니다.

## 파일 분류

하네스 작업에서 파일이 어디에 속하는지는 네 갈래입니다. `harness/` 에 들어가는 건 첫 번째뿐입니다.

| 분류 | 무엇 | 어디에 |
|---|---|---|
| **공유 하네스** | agent·skill 본체, 이식 계약, 공통 레퍼런스 | `harness/` → 프로젝트 `.claude/` |
| **프로젝트 문서** | 도메인 지식, 결정 기록, 아키텍처 | 프로젝트 `docs/` (직접 소유) |
| **프로젝트 주입값** | `.claude/` 안이지만 프로젝트 고유값 | `browser-scenarios.md`, `launch.json`, `settings*.json` (sync 가 건드리지 않음) |
| **공유 인프라 스크립트** | 빌드 가드 등 — agent·skill 이 읽지 않고 빌드가 부르는 것 | 스크립트 본체는 공유, 배선(`vercel.json`·`package.json`)은 프로젝트 소유 |

## 하네스 본문 작성 규칙

`harness/` 아래를 편집할 때 지켜야 이식성이 유지됩니다.

- **프로젝트 고유 이슈·Decision 번호를 권위로 인용하지 않는다.** 다른 프로젝트에서는 존재하지 않는 참조가 되어 `adr-content-mismatch` 로 잡힙니다. 형식 예시로 쓰는 건 괜찮고, 상위 저장소 이슈(예: 도구 자체의 버그 리포트) 인용도 괜찮습니다.
- **빌드 명령을 하드코딩하지 않는다.** `<typecheck-cmd>`·`<test-cmd>`·`<lint-cmd>` 등 placeholder 를 쓰고, 실제 값은 프로젝트 `docs/development.md` 가 권위입니다. 그래서 pnpm/npm/bun 이 섞여도 배포본은 프로젝트마다 동일합니다.
- **프로젝트 종속값은 프로젝트 소유 파일로 위임한다.** 라우트·셀렉터·계정 같은 값은 본문에 적지 않고 `browser-scenarios.md` 처럼 프로젝트가 소유하는 파일을 참조합니다.
- **`docs/` 참조는 `required-docs.md` 의 계약 안에서만.** 새로운 문서 의존성을 추가한다면 `required-docs.md` 에 그 contract 를 함께 추가해야 이식이 깨지지 않습니다.

## 이식 가이드

새 프로젝트에 하네스를 처음 도입할 때 준비할 것.

### 전제 — 하네스가 요구하는 권위 문서 목록

이 하네스의 agent / skill 이 참조하는 권위 문서들의 경로·kind·역할·본문 구조 contract 는 [required-docs.md](./harness/required-docs.md) 가 단일 권위. 이식 대상 프로젝트에서도 그 명세에 맞춰 작성해야 agent/skill 이 올바르게 작동한다.

### 영역별 `CLAUDE.md` 작성

각 디렉토리(API, 컴포넌트, DB, 라이브러리 등)의 운영 규약. agent/skill 본문이 "영역별 `CLAUDE.md`" 라고 표현한 부분이 이걸 참조한다. 이식 대상 프로젝트의 디렉토리 구조에 맞게 신규 작성.

### 빌드 도구 명령 확정

agent / skill 본문의 placeholder(`<typecheck-cmd>`, `<test-cmd>`, `<md-lint-cmd>` 등)는 런타임에 프로젝트 `docs/development.md` 에서 해석된다. 배포본을 고치는 게 아니라 **그 문서에 실제 명령을 적는다.**

### 스크립트 배선

`harness/scripts/` 의 검증 스크립트는 `.claude/scripts/` 로 배포된다. 프로젝트 `package.json` 에 alias 를 건다:

```json
"check:decisions": "node .claude/scripts/check-decision-versions.mjs",
"check:decisions-index": "node .claude/scripts/check-decisions-index.mjs"
```

### 라벨 도입

GitHub Issues backlog 모델 채택 시 다음 라벨을 생성한다. 라벨 축 정의·의미는 [harness-rules.md](./harness/harness-rules.md) § "운영 정책" 이 SSOT.

```bash
# type 축
gh label create type:feat    --color 0075ca
gh label create type:fix     --color d73a4a
gh label create type:chore   --color e4e669
gh label create type:refactor --color cfd3d7

# 상태 축
gh label create next    --color 0e8a16
gh label create blocked --color b60205

# area 축
gh label create area:meta --color f9d0c4 --description "비-코드 작업 (.claude/ 하네스 + docs/ 문서)"
```

### `gh` CLI 인증 + GitHub Issues backlog

이 하네스는 `gh` CLI 인증과 GitHub Issues 를 backlog SSOT 로 전제한다.

```bash
gh auth login
```

## 구조

```
claude-harness/
├── sync-harness.sh              # 하네스 배포 / 드리프트 검사
├── harness/                     # 공유 하네스 → 프로젝트 .claude/
│   ├── README.md                #   흐름도·라우팅·본문 작성 가이드
│   ├── harness-rules.md         #   철학·SSOT 원칙·운영 정책
│   ├── required-docs.md         #   프로젝트 docs/ 에 요구하는 contract
│   ├── agents/                  #   architect·developer·*-reviewer
│   ├── skills/                  #   create-issue·plan·pr·qa·release·review-comments
│   ├── references/              #   infra-gotchas (Neon·Vercel·drizzle 함정)
│   └── scripts/                 #   Decision 인덱스·버전 검증
└── README.md
```
