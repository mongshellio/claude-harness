# business-name-review

제품·브랜드·서비스 **이름 후보**를 받아서 다음 5가지를 한 번에 검토하는 Claude Code 플러그인입니다.

1. **도메인 가용성** — `.com`, `.co`, `.app`, `.io`, `.ai`, `.co.kr`, `.kr` 등 주요 TLD
2. **글로벌·국내 SaaS 키워드 충돌** — 같은 이름의 기존 서비스/제품 검색
3. **SNS 핸들 점유** — Instagram, X(Twitter), YouTube, Threads + 네이버 카페·블로그, 카카오톡 채널
4. **상표 출원 조회** — 한국특허정보원(KIPRIS) 검색
5. **한국 상호·법인명 중복** — bizno.net, 대법원 인터넷등기소 (한국 시장 진출 시)

## 설치

이 폴더를 Claude Code 플러그인 마켓플레이스 디렉토리에 넣고 `marketplace.json`에 등록하면 됩니다. 마켓플레이스 루트에서:

```bash
cp -r business-name-review/ ./
# 그리고 .claude-plugin/marketplace.json 에 아래 entry 추가:
```

```json
{
  "name": "business-name-review",
  "source": "./business-name-review",
  "description": "이름 후보의 도메인·SaaS·SNS·상표 충돌 검토",
  "version": "0.2.0"
}
```

설치 후 Claude Code에서:

```
/plugin marketplace add <your-marketplace-repo>
/plugin install business-name-review
```

## 사용법

설치되면 다음과 같은 트리거로 자동 발동합니다:

- "북담 이름 검토해줘"
- "이 이름 쓸 수 있을까?"
- "Foobar 도메인 살 수 있어?"
- "이 이름으로 사업할 수 있는지 봐줘"

또는 Claude 에게 직접 "business-name-review 로 북담 검토해줘" 같이 skill 이름을 명시해 호출할 수도 있습니다. (Claude Code 의 skill 은 자동 invocation 또는 자연어 요청으로 동작하며, `/skill` 슬래시 명령 문법은 지원되지 않습니다.)

## 출력

검토 결과는 `templates/report-template.md` 양식의 마크다운 리포트로 정리됩니다:

```markdown
# 이름 검토: 북담 (Bookdam)

## 종합 평가
🟢 사용 가능 / 🟡 일부 제약 / 🔴 충돌 위험 큼

## 1. 도메인 가용성
| TLD | 상태 | 비고 |
| ... |

## 2. SaaS 키워드 충돌
...

## 3. SNS 핸들 점유
...

## 4. KIPRIS 상표 출원
...
```

## 예시 출력

실제 완성된 검토 보고서는 `skills/business-name-review/examples/bookdam-report.md` 참조.

## 한계

- **도메인 점유 100% 확정은 후이즈/도메인 등록업체에서 직접 조회 필수**. 이 skill은 검색 인덱싱·DNS 신호 기반 추정.
- **KIPRIS는 웹 검색 결과로 1차 스크리닝**만. 실제 출원/등록 여부는 [kipris.or.kr](https://www.kipris.or.kr) 직접 검색 권장.
- **SNS 핸들 활동성**(팔로워 수, 상업성)은 사용자가 시각 확인 필요.
- **법인 등기 중복**은 대법원 인터넷등기소 직접 조회 필요 — 자동화 어려움.

## 변경 이력

- **v0.2.0** — 한국 시장 특화 검토 추가 (네이버·카카오·bizno·등기소), Phase 5 신설, `examples/bookdam-report.md` 추가, `domain-check.sh`에 `--format md/json` 옵션 추가
- **v0.1.0** — 초기 버전 (4 phase: 도메인·SaaS·SNS·KIPRIS)

## 라이선스

MIT
