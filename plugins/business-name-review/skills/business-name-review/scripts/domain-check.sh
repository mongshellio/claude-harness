#!/usr/bin/env bash
# domain-check.sh
# 주어진 이름에 대해 주요 TLD에서 도메인 등록 여부를 일괄 확인.
#
# 사용법:
#   bash scripts/domain-check.sh <name> [--format human|md|json] [tld1 tld2 ...]
#
# 예시:
#   bash scripts/domain-check.sh bookdam
#   bash scripts/domain-check.sh bookdam com app io ai
#   bash scripts/domain-check.sh bookdam --format md
#   bash scripts/domain-check.sh bookdam --format json > result.json
#
# 동작 원리:
#   1. dig으로 NS 레코드 조회 — 응답이 있으면 등록됨
#   2. 가능하면 whois CLI로 추가 확인 — 더 정확한 신호
#
# 출력 포맷:
#   human (default) — ANSI 컬러 + 표 (터미널 인간용)
#   md              — 마크다운 표 (Claude가 리포트에 그대로 붙여넣기 좋음)
#   json            — 배열 (스크립트로 후처리)

set -uo pipefail

# --- 인자 파싱 ---
FORMAT="human"
NAME=""
TLDS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)
      FORMAT="${2:-human}"
      shift 2
      ;;
    --format=*)
      FORMAT="${1#*=}"
      shift
      ;;
    -h|--help)
      cat <<'HELP'
domain-check.sh — 주어진 이름에 대해 주요 TLD에서 도메인 등록 여부를 일괄 확인.

사용법:
  bash scripts/domain-check.sh <name> [--format human|md|json] [tld1 tld2 ...]

예시:
  bash scripts/domain-check.sh bookdam
  bash scripts/domain-check.sh bookdam com app io ai
  bash scripts/domain-check.sh bookdam --format md
  bash scripts/domain-check.sh bookdam --format json > result.json

동작 원리:
  1. dig으로 NS 레코드 조회 — 응답이 있으면 등록됨
  2. 가능하면 whois CLI로 추가 확인 — 더 정확한 신호

출력 포맷:
  human (default) — ANSI 컬러 + 표 (터미널 인간용)
  md              — 마크다운 표 (Claude가 리포트에 그대로 붙여넣기 좋음)
  json            — 배열 (스크립트로 후처리)

도메인 이름 제약:
  영문 대소문자·숫자·하이픈만 허용. 한글·공백·점·특수문자는 거부.
HELP
      exit 0
      ;;
    *)
      if [[ -z "$NAME" ]]; then
        NAME="$1"
      else
        TLDS+=("$1")
      fi
      shift
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "사용법: $0 <name> [--format human|md|json] [tld1 tld2 ...]" >&2
  exit 1
fi

if [[ ! "$NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
  echo "오류: 도메인 이름은 영문·숫자·하이픈만 허용합니다 (현재: '$NAME'). 한글·공백·점·특수문자는 사용 불가." >&2
  exit 1
fi

if [[ ! "$FORMAT" =~ ^(human|md|json)$ ]]; then
  echo "오류: --format은 human, md, json 중 하나여야 합니다 (현재: $FORMAT)" >&2
  exit 1
fi

DEFAULT_TLDS=(com co app io ai co.kr kr)
if [[ ${#TLDS[@]} -eq 0 ]]; then
  TLDS=("${DEFAULT_TLDS[@]}")
fi

# --- 의존성 확인 ---
if ! command -v dig >/dev/null 2>&1; then
  if [[ "$FORMAT" == "json" ]]; then
    echo '{"error":"dig command not found. macOS는 기본 설치, Linux는 dnsutils 설치 필요."}'
  else
    echo "⚠️  'dig' 명령이 없습니다. macOS는 보통 기본 설치, Linux는 'apt install dnsutils' 필요." >&2
  fi
  exit 1
fi

HAS_WHOIS=0
if command -v whois >/dev/null 2>&1; then
  HAS_WHOIS=1
fi

# --- 도메인별 상태 결정 ---
# 결과를 임시 변수에 모은 다음 포맷별 출력
declare -a STATUSES   # AVAILABLE | REGISTERED | UNKNOWN
declare -a DOMAINS
declare -a EVIDENCES

for tld in "${TLDS[@]}"; do
  domain="${NAME}.${tld}"

  # 1차: dig NS
  ns=$(dig +short +time=3 +tries=1 "$domain" NS 2>/dev/null | head -3 | tr '\n' ',' | sed 's/,$//')
  if [[ -z "$ns" ]]; then
    soa=$(dig +short +time=3 +tries=1 "$domain" SOA 2>/dev/null | head -1)
    [[ -n "$soa" ]] && ns="$soa"
  fi

  if [[ -n "$ns" ]]; then
    if [[ $HAS_WHOIS -eq 1 ]]; then
      whois_status=$(whois "$domain" 2>/dev/null \
        | grep -iE '^(status|domain status|registry expiry)' \
        | head -2 \
        | tr '\n' ';' \
        | sed 's/;$//' \
        | sed 's/  */ /g')
      STATUSES+=("REGISTERED")
      DOMAINS+=("$domain")
      EVIDENCES+=("NS: ${ns:0:60} | $whois_status")
    else
      STATUSES+=("REGISTERED")
      DOMAINS+=("$domain")
      EVIDENCES+=("NS: ${ns:0:80}")
    fi
  else
    if [[ $HAS_WHOIS -eq 1 ]]; then
      whois_out=$(whois "$domain" 2>/dev/null || true)
      if echo "$whois_out" | grep -qiE '(no match|not found|no data found|status: ?available|no entries found|no such domain)'; then
        STATUSES+=("AVAILABLE")
        DOMAINS+=("$domain")
        EVIDENCES+=("WHOIS: no match")
      elif [[ -z "$whois_out" ]]; then
        STATUSES+=("UNKNOWN")
        DOMAINS+=("$domain")
        EVIDENCES+=("no DNS, no whois response")
      else
        STATUSES+=("UNKNOWN")
        DOMAINS+=("$domain")
        EVIDENCES+=("no NS, whois output unclear (manual check needed)")
      fi
    else
      STATUSES+=("AVAILABLE")
      DOMAINS+=("$domain")
      EVIDENCES+=("no NS records (DNS-only check)")
    fi
  fi
done

# --- 포맷별 출력 ---

emoji_for() {
  case "$1" in
    AVAILABLE)  echo "✅" ;;
    REGISTERED) echo "🔴" ;;
    UNKNOWN)    echo "⚠️" ;;
  esac
}

# 마크다운 escape — 표 안에서 `|` 깨지지 않게
md_escape() {
  echo "$1" | sed 's/|/\\|/g'
}

# JSON escape
json_escape() {
  echo "$1" | python3 -c 'import sys,json;print(json.dumps(sys.stdin.read().rstrip("\n")))' 2>/dev/null \
    || echo "\"$(echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g')\""
}

case "$FORMAT" in
  human)
    echo "▶ 검사 대상: $NAME"
    echo "▶ TLD: ${TLDS[*]}"
    echo "▶ whois CLI 사용 가능: $([[ $HAS_WHOIS -eq 1 ]] && echo 'yes' || echo 'no (DNS만 사용)')"
    echo
    printf "%-3s %-12s %-22s %s\n" "  " "STATUS" "DOMAIN" "EVIDENCE"
    printf "%-3s %-12s %-22s %s\n" "--" "------" "------" "--------"
    for i in "${!DOMAINS[@]}"; do
      st="${STATUSES[$i]}"
      em=$(emoji_for "$st")
      case "$st" in
        AVAILABLE)  color="\033[32m" ;;
        REGISTERED) color="\033[31m" ;;
        UNKNOWN)    color="\033[33m" ;;
      esac
      printf "%-3s ${color}%-12s\033[0m %-22s %s\n" "$em" "$st" "${DOMAINS[$i]}" "${EVIDENCES[$i]}"
    done
    echo
    echo "📌 최종 구매 가능 여부는 후이즈/가비아/Namecheap에서 직접 검색하세요:"
    echo "   - 후이즈:    https://domain.whois.co.kr"
    echo "   - 가비아:    https://domain.gabia.com"
    echo "   - Namecheap: https://www.namecheap.com"
    ;;

  md)
    echo "| 상태 | 도메인 | 근거 |"
    echo "|---|---|---|"
    for i in "${!DOMAINS[@]}"; do
      st="${STATUSES[$i]}"
      em=$(emoji_for "$st")
      label=""
      case "$st" in
        AVAILABLE)  label="$em 가용성 후보" ;;
        REGISTERED) label="$em 등록됨" ;;
        UNKNOWN)    label="$em 확인 필요" ;;
      esac
      printf "| %s | \`%s\` | %s |\n" "$label" "$(md_escape "${DOMAINS[$i]}")" "$(md_escape "${EVIDENCES[$i]}")"
    done
    echo
    echo "_최종 구매 가능 여부는 [후이즈](https://domain.whois.co.kr) / [가비아](https://domain.gabia.com) / [Namecheap](https://www.namecheap.com) 직접 조회 필요._"
    ;;

  json)
    echo "{"
    echo "  \"name\": $(json_escape "$NAME"),"
    echo "  \"checked_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"whois_available\": $([[ $HAS_WHOIS -eq 1 ]] && echo 'true' || echo 'false'),"
    echo "  \"results\": ["
    last_idx=$((${#DOMAINS[@]} - 1))
    for i in "${!DOMAINS[@]}"; do
      sep=","
      [[ $i -eq $last_idx ]] && sep=""
      printf "    {\"domain\": %s, \"status\": %s, \"evidence\": %s}%s\n" \
        "$(json_escape "${DOMAINS[$i]}")" \
        "$(json_escape "${STATUSES[$i]}")" \
        "$(json_escape "${EVIDENCES[$i]}")" \
        "$sep"
    done
    echo "  ]"
    echo "}"
    ;;
esac
