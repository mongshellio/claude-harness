#!/usr/bin/env node
/**
 * 결정 문서(docs/architecture-decisions.md · docs/harness-decisions.md)의 `**도입**: vX.Y.Z (#N)` 라인 중 (대시 유무 무관)
 * 버전이 아직 placeholder(concrete `vX.Y.Z` 아님 — 예: `v3.x.x`, "확정")인 것을 검출한다.
 *
 * 각 placeholder 의 `(#N)` PR/이슈를 커밋 그래프(first-parent)에서 찾아 판정한다:
 *   - 이미 릴리스 태그에 포함     → STALE   (릴리스됐는데 미확정 — 채웠어야 함). 정확한 버전 리포트.
 *   - origin/main 엔 있으나 미태그 → PENDING (이번 릴리스에 나감 — 태깅할 버전으로 채울 것).
 *   - 어디에도 없음(미머지)        → OK      (placeholder 정상, 조용히 통과).
 *
 * `(#N)` 은 squash 커밋 subject 에 박히는 **PR 번호**와 매칭되는데, 도입 라인이 **이슈 번호**를
 * 적는 경우(이슈≠PR, 예: 이슈 #970 → PR #972) subject 맵에서 못 찾는다. 이때만 `gh issue view <N>
 * --json closedByPullRequestsReferences` 로 이슈를 닫은 PR 번호를 역조회해 재시도한다 — 네트워크
 * 의존은 이 폴백 경로에 한정된다. gh 호출 자체가 실패(미설치/미인증/네트워크)하거나, 닫은 PR 은
 * 있는데 first-parent 로그에 없는 비정상이면 조용한 OK 로 넘기지 않고 UNRESOLVED 로 표면화한다.
 *
 * STALE 또는 PENDING 가 하나라도 있으면 exit 1 (채울 게 있다는 신호).
 *
 * 배경: `/release` 는 파일을 수정하지 않으므로(Decision 14) 도입 버전 placeholder 가
 *   릴리스마다 안 채워지고 누적되는 드리프트가 있었다. 결정론 판정은 스크립트로 처리한다
 *   (하네스 스크립트 우선 원칙). 이 스크립트는 "채울 목록" 만 제시하고, 실제 수정은 운영자가 doc 으로 반영.
 *
 * 사용: `node .claude/scripts/check-decision-versions.mjs` 또는 `pnpm check:decisions`. `/release` Step 2 가 호출.
 * cwd 무관 — 스크립트 위치 기준으로 repo 루트를 해석하고 git 도 그 루트에서 실행한다.
 */
import { execFileSync, execSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// 스크립트 위치 기준 repo 루트 — cwd 와 무관하게 동작(다른 cwd 실행 시 false-green 방지).
// sibling check-journal-monotonic.mjs 와 동일 패턴.
const ROOT = dirname(dirname(fileURLToPath(import.meta.url)));
const FILES = ["docs/architecture-decisions.md", "docs/harness-decisions.md"];

/** git 명령 실행 — 항상 repo 루트에서. 실패(non-zero)는 빈 문자열로 흡수. */
function sh(cmd) {
	try {
		return execSync(cmd, { encoding: "utf8", cwd: ROOT }).trim();
	} catch {
		return "";
	}
}

/**
 * 실패와 "성공했지만 결과 없음"을 구분해야 하는 호출(gh 폴백)용 실행 헬퍼.
 * sh() 처럼 실패를 빈 문자열로 흡수하면 "gh 실패"와 "닫은 PR 없음"을 구분할 수 없다.
 * 셸을 거치지 않고 인자 배열을 그대로 넘긴다 — 문서에서 파싱한 값이 셸 문법으로 재해석될 여지가 없다.
 */
function runResult(file, args) {
	try {
		return { ok: true, out: execFileSync(file, args, { encoding: "utf8", cwd: ROOT }).trim() };
	} catch {
		return { ok: false, out: "" };
	}
}

// 이슈 번호 → gh 조회 결과 캐시. 같은 이슈 번호가 여러 도입 라인에서 재참조돼도 gh 는 한 번만 호출한다.
const ghClosedPrCache = new Map();

/** 이슈 `num` 을 닫은 PR 번호 목록을 gh 로 조회한다(캐시됨). */
function closedPrsForIssue(num) {
	if (ghClosedPrCache.has(num)) return ghClosedPrCache.get(num);
	const result = runResult("gh", [
		"issue",
		"view",
		num,
		"--json",
		"closedByPullRequestsReferences",
		"--jq",
		".closedByPullRequestsReferences[].number",
	]);
	const entry = result.ok
		? { ok: true, prNumbers: result.out.split("\n").filter(Boolean) }
		: { ok: false, prNumbers: [] };
	ghClosedPrCache.set(num, entry);
	return entry;
}

/**
 * `(#N)` 에 대응하는 도입 커밋 sha 를 찾는다. subject 맵(prToSha)에 없으면 N 을 이슈 번호로 보고
 * gh 로 닫은 PR 번호를 역조회해 재시도한다(이슈≠PR 폴백).
 *
 * 반환:
 *   - { status: "found", sha }   — 판정(STALE/PENDING) 진행
 *   - { status: "ok" }           — 미머지로 간주, placeholder 정상 (조용히 통과)
 *   - { status: "unresolved", reason } — gh 실패 또는 닫은 PR 이 로그에 없음, 수동 확인 필요
 */
function resolveSha(num) {
	const direct = prToSha.get(num);
	if (direct) return { status: "found", sha: direct };

	const gh = closedPrsForIssue(num);
	if (!gh.ok) return { status: "unresolved", reason: `gh 조회 실패 (이슈 #${num}), 수동 확인` };
	if (gh.prNumbers.length === 0) return { status: "ok" }; // PR 없이 닫혔거나 아직 open

	const matchedPr = gh.prNumbers.find((pr) => prToSha.has(pr));
	if (!matchedPr) {
		return {
			status: "unresolved",
			reason: `이슈 #${num} 닫은 PR(${gh.prNumbers.join(", ")}) 이 first-parent 로그에 없음, 수동 확인`,
		};
	}
	return { status: "found", sha: prToSha.get(matchedPr) };
}

const CONCRETE_RE = /v\d+\.\d+\.\d+/; // 이미 확정된 도입 버전
// 실제 도입 메타 라인만 (리스트 항목 `- **도입**:` 또는 standalone `**도입**:`). `> ...` 포맷 설명
// prose 는 제외 — 라인이 `>` 로 시작하므로 `^\s*(?:-\s+)?\*\*도입\*\*` 에 걸리지 않는다.
// 대시 선택적: architecture-decisions 는 대시 형식, harness-decisions 는 standalone 형식이 다수 (#994).
const ADOPT_RE = /^\s*(?:-\s+)?\*\*도입\*\*\s*:/;
const PR_RE = /\(#(\d+)\)/; // (#123)

// 결정 문서를 하나도 못 찾으면 루트 해석 실패 — 조용한 false-green 방지 위해 명시 fail.
if (!FILES.some((f) => existsSync(join(ROOT, f)))) {
	console.error(`[error] 결정 문서를 찾을 수 없습니다 (ROOT=${ROOT}). repo 루트 해석 실패.`);
	process.exit(1);
}

const hasOriginMain = sh("git rev-parse --verify --quiet origin/main") !== "";
const logBase = hasOriginMain ? "origin/main" : "HEAD";
if (!hasOriginMain) console.error("[warn] origin/main 없음 — PENDING 검출 생략, HEAD 기준 STALE 만 판정.");

// first-parent 커밋 subject 의 모든 `(#N)` → 머지 커밋 sha.
// squash subject 는 이슈+PR 둘 다 병기하기도 한다(예: "... (#930) (#938)"). 문서 도입 라인은
// 이슈번호를 참조하므로 트레일링 하나만 잡으면 놓친다 — subject 내 모든 (#N) 을 매핑한다.
// git log 는 최신→과거 순이므로 덮어쓰기로 **가장 오래된(=최초 도입)** 커밋이 남는다
// — 같은 #N 이 후속 커밋에서 재인용돼도 도입 시점의 태그로 판정하기 위함.
const prToSha = new Map();
for (const line of sh(`git log --first-parent ${logBase} --format=%H%x09%s`).split("\n")) {
	if (!line) continue;
	const tab = line.indexOf("\t");
	const sha = line.slice(0, tab);
	for (const m of line.slice(tab + 1).matchAll(/\(#(\d+)\)/g)) {
		prToSha.set(m[1], sha);
	}
}

/** sha 를 포함하는 가장 이른 릴리스 태그 (없으면 ""). */
function earliestTag(sha) {
	const tags = sh(`git tag --contains ${sha} --list 'v*' --sort=version:refname`);
	return tags ? tags.split("\n")[0] : "";
}

const stale = []; // 릴리스됐으나 placeholder
const pending = []; // 이번 릴리스 대상
const unresolved = []; // (#N) 없음 — 수동 확인

for (const file of FILES) {
	if (!existsSync(join(ROOT, file))) continue;
	readFileSync(join(ROOT, file), "utf8")
		.split("\n")
		.forEach((text, i) => {
			if (!ADOPT_RE.test(text) || CONCRETE_RE.test(text)) return; // 도입 라인 아님 or 이미 확정
			const loc = `${file}:${i + 1}`;
			const prm = text.match(PR_RE);
			if (!prm) {
				unresolved.push({ loc, text: text.trim() });
				return;
			}
			const resolved = resolveSha(prm[1]);
			if (resolved.status === "ok") return; // 미머지로 간주(gh 폴백까지 확인) → placeholder 정상
			if (resolved.status === "unresolved") {
				unresolved.push({ loc, text: `${text.trim()}  — ${resolved.reason}` });
				return;
			}
			const { sha } = resolved;
			const tag = earliestTag(sha);
			if (tag) {
				stale.push({ loc, pr: prm[1], version: tag });
			} else if (hasOriginMain && sh(`git merge-base --is-ancestor ${sha} origin/main && echo y`) === "y") {
				pending.push({ loc, pr: prm[1] });
			}
			// 미머지 → OK
		});
}

let bad = false;
if (stale.length) {
	bad = true;
	console.log("STALE — 릴리스됐으나 도입 버전 미확정 (아래 버전으로 채우세요):");
	for (const s of stale) console.log(`  ${s.loc}  (#${s.pr})  →  ${s.version}`);
}
if (pending.length) {
	bad = true;
	console.log("PENDING — 이번 릴리스에 나감 (태깅할 버전으로 채우세요):");
	for (const p of pending) console.log(`  ${p.loc}  (#${p.pr})`);
}
if (unresolved.length) {
	console.log("UNRESOLVED — 자동 판정 불가(#N 없음 또는 gh 폴백 실패), 수동 확인:");
	for (const u of unresolved) console.log(`  ${u.loc}  ${u.text}`);
}
if (!bad && !unresolved.length) console.log("OK — 모든 도입 버전이 확정됨.");

process.exit(bad ? 1 : 0);
