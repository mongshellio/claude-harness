# claude-marketplace

Mongshell 의 개인용 Claude Code 플러그인 마켓플레이스.

## 설치

```
/plugin marketplace add mongshellio/claude-marketplace
/plugin install tech-analyst@mongshell-marketplace
/plugin install task-spec@mongshell-marketplace
/plugin install business-name-review@mongshell-marketplace
```

## 수록 플러그인

### tech-analyst

기술 선택 분석 전문가 agent. npm·GitHub star 정량 시계열 + WebSearch 보조 신호 + 출처 신뢰도 등급(A/B/C) 으로 라이브러리·인프라 후보를 분석하고, 7개 축 (안정성 / 점유율 / 모멘텀 / 현 프로젝트 스택 호환성 / 마이그레이션 비용 / 백커 / 라이선스) 으로 권고를 냅니다.

**호출 예**

- "X vs Y 분석해줘"
- "Redis 대안 뭐 있어?"
- "Drizzle 계속 써도 돼?"
- "ORM 골라줘"
- "메시지 큐 비교"

사용자 명시 호출 전용 (자동 위임 X).

### task-spec

`/task <요청>` 슬래시 커맨드. 인라인 요청을 4단계 절차로 구조화합니다:

1. **Spec 자동 작성** — Goal / Done / Non-goals / 보호 영역 / 참고 / 영향 파일 을 Claude 가 추론해 채움 (사용자에게 캐묻지 않음)
2. **프로젝트 특수 룰 적용** — CLAUDE.md / AGENTS.md 에서 발동되는 규약 자동 첨부
3. **사용자 review** — 승인 또는 수정 지시 받기 전까지 정지
4. **구현** — 확인된 spec 범위 안에서만 작업, 벗어나야 하면 일시 정지 후 재확인

핑퐁 / scope creep / 추측 시작을 차단합니다.

### business-name-review

제품·브랜드·서비스 이름 후보의 사용 가능성을 5개 축으로 일괄 검토하는 skill. 결과는 🟢🟡🔴 종합 평가와 다음 액션 체크리스트가 포함된 마크다운 리포트.

1. **도메인 가용성** — `.com / .co / .app / .io / .ai / .co.kr / .kr` 등 7종. `scripts/domain-check.sh` 로 dig·whois 일괄 조회 (`--format md/json` 지원)
2. **글로벌·국내 SaaS 키워드 충돌** — 영문·한글·카테고리 결합 다각도 WebSearch
3. **SNS 핸들 점유** — 글로벌(인스타·X·YouTube·Threads) + 한국(네이버 카페·블로그·카카오톡 채널)
4. **KIPRIS 상표 출원** — 한국특허정보원 검색 + 클래스 9·35·41·42 안내
5. **한국 상호·법인명 중복** — bizno.net·국세청·대법원 인터넷등기소 (한국 시장 진출 시)

**호출 예**

- "북담 이름 검토해줘"
- "이 이름 쓸 수 있을까?"
- "Foobar 도메인 살 수 있어?"
- "이 이름으로 사업할 수 있는지 봐줘"

실제 완성된 보고서 예시: `plugins/business-name-review/skills/business-name-review/examples/bookdam-report.md`

## 구조

```
claude-marketplace/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   ├── tech-analyst/
│   │   ├── .claude-plugin/plugin.json
│   │   └── agents/tech-analyst.md
│   ├── task-spec/
│   │   ├── .claude-plugin/plugin.json
│   │   └── commands/task.md
│   └── business-name-review/
│       ├── .claude-plugin/plugin.json
│       ├── README.md
│       └── skills/business-name-review/
│           ├── SKILL.md
│           ├── references/  (kipris·domain-tlds·korea-market)
│           ├── scripts/     (domain-check.sh)
│           ├── templates/   (report-template.md)
│           └── examples/    (bookdam-report.md)
└── README.md
```
