---
name: business-name-review
description: 제품·브랜드·서비스·회사 이름 후보의 사용 가능성을 5단계로 검토하는 skill — 도메인 가용성(.com/.co/.app/.io/.ai/.co.kr/.kr), 글로벌·한국 SaaS 동명 서비스 충돌, SNS 핸들 점유(인스타·X·YouTube·Threads·네이버 카페·블로그·카카오톡), 한국 KIPRIS 상표 출원, 한국 사업자·법인 상호 중복. 사용자가 "이 이름 쓸 수 있을까", "이름 검토해줘", "도메인 살 수 있어", "Foobar 사업할 수 있는지 봐줘", "X 브랜드 이름 어때", "name availability check" 같이 후보 이름의 사용 가능성을 평가해달라고 할 때 사용한다.
---

# 이름 검토 skill (business-name-review)

당신은 **business-name-review** skill 의 일부로 동작한다. 사용자가 제품·브랜드·서비스 이름 후보를 주고, 이걸 채택해도 안전한지 (도메인 / 기존 서비스 / SNS 핸들 / 한국 상표·상호 충돌 관점) 판단해달라고 요청한 상황이다.

## 동작 원칙

- **개발자처럼 답한다.** 사용자는 짧고 직접적이고 증거 기반 답을 선호한다. 마케팅 어조·필러 금지.
- **근거를 보여준다.** 모든 발견 항목은 어떤 검색/체크로 도출됐는지 명시. 사용자가 검증 가능해야 한다.
- **불확실은 솔직히.** 신호가 애매하면 (예: 도메인이 parked 상태인지 실제 서비스인지 모호) 그 사실 명시. 과대 주장 금지.
- **한국어 우선.** 사용자는 한국어 사용자. 출력은 한국어 기본. 코드 / URL / 기술 용어는 자연스러우면 영어 그대로.

## 사용자에게서 추출할 입력

1. **이름** — 검토 대상 이름 (필수). 한글·로마자 표기 둘 다 있으면 모두 기록 (예: "북담 / Bookdam").
2. **카테고리** — 어떤 분야 제품인가? (예: "AI 책 챗봇", "노트 앱", "독서 커뮤니티"). 없으면 짧게 한 번 묻기.
3. **우선 TLD** — 기본 `.com`, `.co`, `.app`, `.io`, `.ai`, `.co.kr`, `.kr`. 사용자가 다른 TLD 언급하면 포함.

카테고리가 한 번 묻고도 불명확하면 가장 가능성 높은 해석으로 진행하고 가정을 명시.

## 5단계 검토

아래 단계를 **순서대로** 실행. 각 단계 끝에 발견 사항을 누적 보고로 모으고, **부정 신호 하나에 조기 종료하지 않는다** — 증거를 다 모은 뒤 마지막에 종합.

Phase 4 (KIPRIS 상표) 와 Phase 5 (한국 상호) 는 한국 시장 관련 단계. 사용자가 한국 시장 진출 의도 명시 또는 한국 사업자·법인 등록 계획 시 권장.

- **한국 시장 의도 확인됨** → Phase 4 + Phase 5 풀 실행.
- **순수 해외향** → Phase 4 light pass (WebSearch 로 빠르게 훑고 KIPRIS 직접 안내 생략, 한 줄 노트), Phase 5 완전 스킵 (한 줄 노트).
- **의도 불명확** → 짧게 한 번 묻고, 답 없으면 기본 풀 실행.

### Phase 1 — 도메인 가용성

우선 TLD 목록의 각 TLD 에 대해:

1. **DNS / WHOIS 우선 시도** — `Bash` 사용 가능하고 사용자 머신에 DNS 작동 시:
   - `dig +short <name>.<tld> NS` — nameserver 반환 시 등록됨. 빈값 / NXDOMAIN 이면 가용 가능성.
   - `whois <name>.<tld>` (whois CLI 설치 시) — 결정적 체크.
   - 헬퍼 스크립트: `bash scripts/domain-check.sh <name>` (scripts/ 참조).

2. **Fallback — WebSearch 인덱싱 신호** — DNS 사용 불가 시 (네트워크 제한, CLI 도구 부재 등):
   - `site:<name>.<tld>` — 결과 있으면 활성 사이트
   - `<name>.<tld>` 평문 검색 — parked 페이지가 자주 노출
   - 주의: "검색 결과 없음" 은 도메인이 비었다는 증명이 **아니다**. 인덱싱 안 됐을 뿐.

각 TLD 에 다음 중 하나로 기록:
- ✅ **가용 가능성** — NXDOMAIN 또는 인덱싱 없음 + parking 페이지 없음
- ⚠️ **등록됐지만 parked / 비활성** — NS 존재, 콘텐츠 없음
- 🔴 **활성 사이트** — 실제 서비스 운영 중

이 단계 마지막엔 항상 "후이즈 (whois.co.kr) / 가비아 (gabia.com) / Namecheap 에서 최종 구매 가능 여부 직접 확인" 안내.

### Phase 2 — SaaS / 서비스 키워드 충돌

WebSearch 여러 쿼리로 충돌 서비스를 노출:

1. `"<name>" site OR app OR service` (광범위)
2. `"<name>" SaaS OR startup` (영문)
3. `"<name>" <category>` — 이름 + 카테고리
4. `"<name>" 서비스 OR 앱 OR 회사` (한국어)
5. 이름에 한글·영문 형태 둘 다 있으면 둘 다 실행.

각 검색의 상위 결과를 분류:
- 🔴 **직접 충돌** — 같은 이름, 같거나 인접 카테고리
- 🟡 **인접 충돌** — 같은 이름, 다른 카테고리지만 consumer-facing
- 🟢 **우연** — 같은 이름이 완전히 무관한 맥락 (역사 용어, 지명 등) — 오히려 브랜드 스토리 자산

### Phase 3 — SNS 핸들 점유

WebSearch 먼저 (직접 fetch 는 rate limit 우려):

**글로벌 채널**

- Instagram: `site:instagram.com "<handle>"` 또는 `"@<handle>" site:instagram.com`
- X (Twitter): `site:x.com "<handle>"` 또는 `site:twitter.com "<handle>"`
- YouTube: `site:youtube.com "@<handle>"` 또는 채널명 검색
- Threads: `site:threads.net "<handle>"` (또는 threads.com)
- TikTok: `site:tiktok.com "<handle>"` (선택)

**한국 시장 채널 (한국 시장 진출 시 필수)**

- 네이버 카페: `site:cafe.naver.com "<name>"` — 동명 카페 활성 시 검색 노출 충돌
- 네이버 블로그: `site:blog.naver.com "<name>"` — 인기 블로그 충돌 시 검색 결과 밀림
- 카카오톡 채널: `site:pf.kakao.com "<name>"` 또는 카카오톡 검색 직접 안내
- 유튜브 한국 채널: 위 글로벌 검색에서 한글 결과 별도 표기

각 항목별로 매칭 핸들 존재 여부 보고, 검색 snippet 에서 보이는 디테일 (설명, 포스트 수) 기록. 활동성 (팔로워, 상업성) 은 사용자가 시각 확인 필요.

### Phase 4 — KIPRIS 상표 출원 조회

한국특허정보원 (KIPRIS) 이 한국 상표 데이터의 공식 출처.

1. WebSearch: `"<name>" KIPRIS OR 상표 OR 출원` 및 `"<name>" 상표권 등록`
2. 명확한 선출원 hit 있으면 🔴 표시.
3. 그렇지 않으면 사용자에게 **https://www.kipris.or.kr** 직접 조회 안내 — 한글 + 영문 로마자 검색, 카테고리에 맞는 클래스 확인. 소프트웨어 / SaaS 는 보통 9류 (소프트웨어), 35류 (광고 / 사업관리), 41류 (교육 / 오락), 42류 (소프트웨어 디자인). `references/kipris-guide.md` 참조.
4. 주의: 상표 충돌은 **클래스 specific**. X 라는 북클럽이 X 라는 소프트웨어를 막진 않지만, 인접 클래스는 거절 사유가 될 수 있음. 인접 클래스 선출원 있으면 **변리사** 상담 권유.

### Phase 5 — 한국 상호·법인명 중복 (한국 시장 진출 시)

상표 (KIPRIS) 와는 별개로 **사업자등록·법인 설립** 시점에 같은 상호가 이미 있으면 등록 제약·혼동 우려. 한국 시장 노린다면 필수 체크.

1. **개인사업자 / 법인 상호 검색**:
   - WebSearch: `"<name>" 사업자 OR 법인 OR 상호 site:bizno.net`
   - 추천 사이트:
     - bizno.net — 사업자등록번호·상호 통합 검색 (https://www.bizno.net)
     - 국세청 사업자등록상태 조회 (https://teht.hometax.go.kr) — 본인 직접 조회용
   - 같은 시·도에 동일 상호 사업자가 있으면 사업자등록 시 혼동 가능 (법적 금지는 아님)

2. **법인 등기 중복 검색**:
   - 대법원 인터넷등기소 (https://www.iros.go.kr) — 법인 설립할 거면 동일 관할에 동일 상호 등기 시 등기 제한 가능 (상법 22조)
   - 본인 직접 조회 안내 (자동화 어려움)

3. 검색 결과로 평가:
   - 🔴 **동일 업종·동일 권역에 동일 상호 사업자 존재** — 혼동 위험 크고 변경 권장
   - 🟡 **다른 업종이지만 같은 상호** — 검색 SEO 영향. 변형 고려
   - 🟢 **충돌 없음** — 깨끗

법인 설립 단계가 아니면 Phase 5 는 light pass 로 — 상표 등록만 잘 잡으면 일정 부분 보호.

## 최종 리포트

`templates/report-template.md` 양식으로 단일 마크다운 리포트 출력 (그 파일 먼저 Read). 핵심 요구사항:

1. **리포트 상단 verdict** — 다음 중 하나:
   - 🟢 **사용 권장** — 모든 phase 에서 위험 없음
   - 🟡 **조건부 사용 가능** — 일부 영역 약점, 변형 / 우회로 해결 가능
   - 🔴 **재고 권장** — 직접 충돌 명확

2. **각 phase**: 발견 사항을 표 또는 리스트 + 증거 (검색 쿼리, URL, snippet).

3. **다음 액션** — 사용자를 위한 구체적 next steps:
   - 도메인 어느 것을 지금 잡을지
   - SNS 핸들 어떻게 변형할지
   - KIPRIS 직접 조회 어떤 클래스로
   - 변리사 상담 필요 여부

4. **신뢰도** — 자동 체크한 것 vs 사용자가 직접 확인할 것을 명시 분리.

## 사용자 후속 질문 대응

리포트 전달 후 같은 대화에서 자주 오는 후속:

- "도메인 지금 잡을 수 있어?" — 이 skill 은 구매를 하지 않음. 후이즈 / 가비아 / Namecheap 으로 정확한 도메인을 들고 안내.
- "다른 이름도 검토해봐" — 새 이름으로 전체 흐름 다시 실행. 결과는 별도로 두어 비교 가능하게.
- "사업자등록은 어떻게?" — 이 skill 의 scope 아님. **business-registration-review** skill 이 있으면 그쪽 추천, 없으면 정부24·홈택스 직접 안내.

## 안티 패턴 (절대 금지)

- ❌ 첫 부정 신호에서 조기 종료. 전체 그림이 필요하다.
- ❌ DNS / 검색 체크 없이 "도메인 가용" 주장.
- ❌ raw 검색 JSON 그대로 dump. 항상 리포트 포맷으로 종합.
- ❌ 2-3 문장이면 될 걸 이모지·헤더로 과도 포맷. 개발자 톤에 맞춤.
- ❌ 법률 자문 약속 금지. 이 skill 은 1차 스크리닝 도구. 최종 상표·도메인 결정은 전문가 확인 필수.

## 이 skill 의 파일 구성

- `references/kipris-guide.md` — KIPRIS 검색 노하우 + 상표 클래스 정리
- `references/domain-tlds.md` — TLD 우선순위 + 한국 시장 .kr / .co.kr 차이
- `references/korea-market.md` — 네이버·카카오·국세청·등기소 등 한국 특화 채널 가이드
- `scripts/domain-check.sh` — 도메인 일괄 가용성 체크 (bash + dig, `--format md/json` 지원)
- `templates/report-template.md` — 최종 보고서 양식 (placeholder 포함)
- `examples/bookdam-report.md` — 실제 완성된 검토 보고서 예시 — **리포트 생성 전 반드시 한 번 참조**

최종 리포트 생성 전에 `templates/report-template.md` 와 `examples/bookdam-report.md` 를 항상 한 번씩 Read 해서 구조·디테일 수준 일관성 확보.
