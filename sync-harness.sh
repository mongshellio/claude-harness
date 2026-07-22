#!/usr/bin/env bash
#
# sync-harness.sh — 공유 하네스를 프로젝트 `.claude/` 로 배포하고 드리프트를 검출한다.
#
#   ./sync-harness.sh sync  <프로젝트경로>   harness/ 를 <프로젝트>/.claude/ 로 렌더링해 쓴다
#   ./sync-harness.sh check <프로젝트경로>   쓰지 않고 차이만 보고한다 (exit 1 = 드리프트 있음)
#
# 배포된 파일은 상단에 "직접 수정 금지" 배너가 붙는다. 배너는 렌더 시점에 생성되므로
# check 는 저장된 해시를 들고 다니지 않는다 — 같은 입력으로 다시 렌더해 비교할 뿐이다.
#
# 프로젝트 소유 파일(아래 PROJECT_OWNED)은 sync 가 절대 건드리지 않는다.
#
set -euo pipefail

SSOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_DIR="$SSOT_DIR/harness"
SSOT_NAME="mongshellio/claude-harness"

# `.claude/` 안에 있지만 프로젝트가 소유하는 것 — sync 대상도, 고아 후보도 아니다.
PROJECT_OWNED="skills/qa/browser-scenarios.md launch.json settings.json settings.local.json"

die() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*"; }

usage() {
	sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
	exit 2
}

# 배포본 상단에 붙일 배너. 파일 종류에 따라 주석 문법이 다르다.
banner_for() {
	local rel="$1"
	case "$rel" in
	*.md)
		printf '<!-- 생성물 — 직접 수정하지 마세요.\n'
		printf '     SSOT: %s → harness/%s\n' "$SSOT_NAME" "$rel"
		printf '     수정은 SSOT 에서 하고 `./sync-harness.sh sync <프로젝트>` 로 반영합니다. -->\n'
		;;
	*)
		printf '// 생성물 — 직접 수정하지 마세요.\n'
		printf '// SSOT: %s → harness/%s\n' "$SSOT_NAME" "$rel"
		printf '// 수정은 SSOT 에서 하고 `./sync-harness.sh sync <프로젝트>` 로 반영합니다.\n'
		;;
	esac
}

# 배너를 삽입한 최종 내용을 stdout 으로. frontmatter 가 있으면 그 뒤에 넣는다
# (frontmatter 는 반드시 1번째 줄에서 시작해야 파서가 인식하므로 앞에 붙일 수 없다).
render() {
	local src="$1" rel="$2" fm_end
	if [ "$(head -1 "$src")" = "---" ]; then
		fm_end="$(awk 'NR>1 && $0=="---" {print NR; exit}' "$src")"
		[ -n "$fm_end" ] || die "frontmatter 가 닫히지 않았습니다: harness/$rel"
		head -n "$fm_end" "$src"
		printf '\n'
		banner_for "$rel"
		tail -n "+$((fm_end + 1))" "$src"
	else
		banner_for "$rel"
		printf '\n'
		cat "$src"
	fi
}

harness_files() {
	(cd "$HARNESS_DIR" && find . -type f ! -name '.DS_Store' | sed 's|^\./||' | sort)
}

is_project_owned() {
	local rel="$1" owned
	for owned in $PROJECT_OWNED; do
		[ "$rel" = "$owned" ] && return 0
	done
	return 1
}

resolve_target() {
	local proj="$1"
	[ -d "$proj" ] || die "프로젝트 경로가 없습니다: $proj"
	[ -d "$proj/.git" ] || die "git repo 가 아닙니다: $proj"
	(cd "$proj" && pwd)
}

cmd_sync() {
	local proj rel src dst tmp written=0 skipped=0
	proj="$(resolve_target "$1")"
	info "SSOT   : $HARNESS_DIR"
	info "대상   : $proj/.claude/"
	info ""

	tmp="$(mktemp)"
	trap 'rm -f "$tmp"' RETURN

	for rel in $(harness_files); do
		if is_project_owned "$rel"; then
			skipped=$((skipped + 1))
			continue
		fi
		src="$HARNESS_DIR/$rel"
		dst="$proj/.claude/$rel"
		render "$src" "$rel" >"$tmp"
		if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then
			continue
		fi
		mkdir -p "$(dirname "$dst")"
		cp "$tmp" "$dst"
		info "  갱신  .claude/$rel"
		written=$((written + 1))
	done

	info ""
	if [ "$written" -eq 0 ]; then
		info "이미 최신입니다 (변경 0건)."
	else
		info "$written 개 파일을 갱신했습니다."
	fi
	[ "$skipped" -eq 0 ] || info "프로젝트 소유 $skipped 개는 건드리지 않았습니다."
	info ""
	info "다음: 프로젝트에서 git diff 로 확인 후 커밋하세요 — 협업자는 이 커밋으로 하네스를 받습니다."
}

cmd_check() {
	local proj rel src dst tmp drift=0 missing=0
	proj="$(resolve_target "$1")"
	tmp="$(mktemp)"
	trap 'rm -f "$tmp"' RETURN

	for rel in $(harness_files); do
		is_project_owned "$rel" && continue
		src="$HARNESS_DIR/$rel"
		dst="$proj/.claude/$rel"
		if [ ! -f "$dst" ]; then
			info "  없음  .claude/$rel"
			missing=$((missing + 1))
			continue
		fi
		render "$src" "$rel" >"$tmp"
		if ! cmp -s "$tmp" "$dst"; then
			info "  드리프트  .claude/$rel"
			diff -u "$tmp" "$dst" | sed -n '3,12p' | sed 's/^/      /' || true
			drift=$((drift + 1))
		fi
	done

	if [ "$drift" -eq 0 ] && [ "$missing" -eq 0 ]; then
		info "정합합니다 — 공유 하네스와 차이가 없습니다."
		return 0
	fi
	info ""
	info "드리프트 $drift 건, 미배포 $missing 건."
	info "배포본을 직접 고쳤다면 그 변경을 SSOT($SSOT_NAME) 로 옮긴 뒤 sync 하세요."
	return 1
}

[ $# -eq 2 ] || usage
case "$1" in
sync) cmd_sync "$2" ;;
check) cmd_check "$2" ;;
*) usage ;;
esac
