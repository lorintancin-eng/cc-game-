---
name: autopilot
description: "Autonomous production orchestrator. Drives the full per-story pipeline end-to-end across an epic or sprint — selects the next ready story, runs /story-readiness → /dev-story → /code-review → /story-done, gates on the full test suite, commits, pushes, opens a PR, and (in --auto) merges — making the routine decisions itself via encoded policies instead of asking the user at every step. Stops only for genuine design forks, repeated failures, or destructive actions. Logs every decision for audit."
argument-hint: "[epic-slug | story-path | sprint | all] [--review | --auto | --plan] [--max N] [--review-mode full|lean|solo]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, Task, AskUserQuestion
model: opus
---

# Autopilot — Autonomous Production Orchestrator

This is the **master orchestrator** for the studio's per-story production loop. The
user invokes it once; it then drives the same pipeline a human lead would run —
selecting work, implementing it through the right specialists, reviewing, testing,
and shipping — **making the routine decisions itself** so the user is not asked to
decide at every step.

It is the automation of the manual loop documented in `/dev-story`:
```
select story → /story-readiness → /dev-story → /code-review → /story-done
            → full-suite quality gate → commit → push → PR → CI → merge → next
```

**Autopilot does not invent new work.** It only advances stories that already exist
in `production/epics/**` (created by `/create-epics` + `/create-stories`). If there
are no ready stories, it stops and says so.

**This skill runs in the main session** (only the main session can invoke other
skills, spawn the 49 subagents, and run git/gh). Each pipeline step still delegates
file writes to the correct specialist subagent, which enforces its own write
protocol — autopilot orchestrates; specialists implement.

---

## Phase 0: Parse Arguments & Resolve Mode

Parse the argument string:

- **Scope** (first non-flag token):
  - `[epic-slug]` (e.g. `five-phases-synergy`) → process that epic's ready stories.
  - `[story-path]` (a `.md` under `production/epics/`) → process just that one story.
  - `sprint` → read the active sprint (`production/sprint-status.yaml` / latest in `production/sprints/`) and process its ready stories.
  - `all` → process every ready story across `production/epics/**` in dependency order.
  - *(blank)* → infer from `production/session-state/active.md` "Next recommended"; if none, ask once which epic/sprint to drive.

- **Autonomy mode** (default `--review`):
  | Flag | Behaviour |
  |------|-----------|
  | `--review` *(default, safe)* | Run the full pipeline autonomously **but stop before merging to `main`** — push the branch, open/update the PR, ensure CI is green, then report and await the human merge. Removes ~all per-step decisions; the only human touch is the merge. |
  | `--auto` | Full hands-off — also merge the PR to `main` when CI is green, sync, and continue to the next story. |
  | `--plan` | Dry run — select stories and output the plan + every decision it *would* make. Writes nothing, spawns no implementers. |

- **`--max N`**: max stories to process this run. Default **3**. Use `--max 1` for a single story, or a large N / `all` scope for a long unattended run.

- **`--review-mode full|lean|solo`**: forwarded to every gate-using sub-skill (overrides `production/review-mode.txt`). If absent, sub-skills resolve it themselves (default `lean`).

Record the resolved config at the top of the run report and in the decision log.

---

## Phase 1: Initialize the Decision Log

Create or append to `production/session-state/autopilot-log.md`. Start each run with:

```markdown
## Autopilot run — [date]
- Scope: [scope] | Mode: [--review/--auto/--plan] | Max: [N] | Review-mode: [resolved]
- Starting branch: [branch] | HEAD: [short-sha]
```

**Every autonomous decision in every phase below is appended here** as a one-line
entry: `- [story] · [decision point] → [choice] · [one-line rationale]`. This is the
audit trail — the user can read exactly what autopilot decided without having been
asked. Keep it terse and complete.

---

## Phase 2: The Story Loop

Repeat until a **stopping condition** (Phase 4) is hit. For each iteration:

### 2.1 Select the next story
- Glob the scope's story files; read each `Status:` and `Dependencies:`.
- Eligible = `Status: Ready` (or `In Progress` that is resumable) **and** all
  dependencies are `Complete`/`Done`.
- **Policy — dependency satisfied-but-stale**: if a dependency's deliverable clearly
  exists and its tests pass but its `Status:` is not Complete (the `/dev-story`
  Phase-2 case), mark that dependency Complete, log it, and proceed. Do **not** ask.
- **Policy — selection order**: among eligible stories pick the **most-unblocked,
  lowest-risk, smallest** one first (Logic before Integration before UI; avoid
  stories whose header notes a BLOCKING playtest/DPS gate — defer those and log).
- If none eligible → stop with reason `no-ready-stories` (Phase 4).
- Log the selection + why.

### 2.2 Readiness (`/story-readiness` logic)
Run the `/story-readiness` checks on the selected story. Apply the verdict by policy:
- **READY** → proceed.
- **NEEDS WORK — doc gaps** (missing estimate / Type / Test-Evidence path / TR-ID,
  stale manifest version): auto-fill from the GDD + template + tr-registry, bump the
  manifest version, log each fix, proceed.
- **NEEDS WORK — as-built vs. design gap** (the story's premise contradicts the
  actual code, e.g. it assumes an interface/pipeline that does not exist): apply the
  **minimal-viable-as-built policy** —
  1. Choose the smallest implementation that matches **existing code patterns** and
     satisfies the story's *testable* acceptance criteria.
  2. Correct the story file (add an `AS-BUILT NOTE`, fix any now-untestable AC wording).
  3. Log the decision with the evidence (the file:line that contradicts the design).
  4. Proceed. **Escalate instead** (Phase 4) only if the honest fix is a *major*
     architectural change (touches a Core contract, multiple systems, or a pillar) —
     that is a real fork the user must own.
- **BLOCKED** (missing/DRAFT dependency, `Proposed` ADR, missing TR registry):
  skip the story, log the blocker, continue to the next eligible story.

### 2.3 Implement (`/dev-story`)
Run `/dev-story [story-path]`: it routes to the correct programmer + engine
specialist and writes the implementation + test.
- **Policy — headless-unverifiable slice** (Type: UI / Visual/Feel, or any AC whose
  only evidence is a screenshot/playtest that CI cannot produce): implement the
  **testable logic slice** fully (with automated tests), and **defer the visual
  half** — record what was done vs. deferred in the story, set `Status: In Progress`
  (not Complete), and create the evidence-doc stub path. Log the split. Do not ask.
- **Policy — scope boundary**: if implementing the story cleanly requires touching a
  file outside its stated scope, allow it **only** if the touch is required by the
  story's own Implementation Notes (e.g. wiring a node the story owns). Otherwise log
  it as out-of-scope and escalate if it is non-trivial.

### 2.4 Code review (`/code-review`)
Run `/code-review` on the changed files (+ the story path for ADR context). Apply:
- **APPROVED / APPROVED WITH SUGGESTIONS** → proceed; apply cheap, high-value
  suggestions inline (e.g. a missing cap/edge test the reviewer named), log them.
- **CHANGES REQUIRED** → apply the fixes, re-run `/code-review` (max **2** rounds).
  Still failing after 2 rounds → escalate (Phase 4) with the unresolved findings.

### 2.5 Quality gate — **HARD, never skipped**
Before any commit, run the full suite the CI way and **explicitly check for
parse/load errors** (a test-count-only check is not enough — this is the lesson that
let a parse error reach `main` once):
```bash
/tmp/Godot_v4.6-stable_win64_console.exe --headless -s res://addons/gut/gut_cmdln.gd \
  -gconfig=res://tests/.gutconfig.json -gexit 2>&1 | tee /tmp/autopilot_suite.txt
grep -iE "Parse error|Failed to load" /tmp/autopilot_suite.txt   # MUST be empty
```
(Use the engine binary from `production/session-state/active.md`; if a new
`class_name` was added, run `--headless --import` first.)
- **Any failing test OR any parse/load error → do NOT commit.** Diagnose root cause
  (flaky → re-run once; deferred-behaviour test → add `await get_tree().process_frame`;
  real regression → fix), then re-gate. If a regression is in code autopilot just
  wrote, fix it; if it is pre-existing and unrelated, log it and (small) fix it or
  (large) escalate. Never weaken a test to pass.

### 2.6 Close (`/story-done`)
Run `/story-done [story-path]` (it re-verifies ACs + evidence and writes
`Status: Complete`). For a deferred-slice story, instead mark `In Progress` with the
done/deferred note (do not run the full close). Append the `Session Extract` block.

### 2.7 Commit
Conventional Commits, with the Story/TR/ADR refs in the body and the co-author
trailer. One commit per story (and a separate `fix:` commit if autopilot fixed a
pre-existing regression it found). On a `claude/*` branch; **never** commit on `main`.

### 2.8 Push + PR
- `git push origin HEAD:[current-branch]` (feature branch — **never** push to `main`
  even if the branch tracks `origin/main`; use the explicit `HEAD:branch` form).
- Open the PR if none is open for the branch (`gh pr create --base main`), else the
  pushed commits update the existing PR.

### 2.9 CI + Merge (mode-dependent)
- Poll `gh pr checks` until checks resolve.
  - **Green** → continue.
  - **Red** → pull the failing job log, diagnose: flaky-shaped (timeout/runner) →
    re-enqueue once; real failure → fix in a new commit and re-push. >1 real CI
    failure on the same story → escalate.
- **Merge step:**
  - `--review` → **STOP merging here.** Leave the PR green + ready. (Continue the
    loop to the next story on the same branch/PR — they accumulate — or stop if
    `--max`/end reached. The human merges the batch.)
  - `--auto` → `gh pr merge --merge`. **Verify the merge actually landed** (the API
    sometimes 504s after a successful merge — check `gh pr view --json state,mergedAt`
    and `git merge-base --is-ancestor`, do **not** blindly retry). Fast-forward the
    local branch to the new `main`. Continue.

### 2.10 Loop
Decrement the story budget; go to 2.1 unless a stopping condition is met.

---

## Phase 3: Run Report

At the end of the run (or at any stop/escalation) output a concise report:

```
## Autopilot report — [scope] — [date]
Mode: [--review/--auto/--plan] · Stories processed: [N] · Stopped because: [reason]

| Story | Verdict | Tests | Commit | PR / Merge |
|-------|---------|-------|--------|------------|
| 008 矿脉精粹 | COMPLETE | 12/12 (suite 404/404) | abc1234 | #13 (awaiting merge) |
| ...   | ...     | ...   | ...    | ...        |

Decisions made autonomously: [count] — see production/session-state/autopilot-log.md
Deferred / escalated: [list with one-line reasons]
Next ready story: [title / "none — epic complete"]
Suggested: [human action, e.g. "review + merge PR #13" or "/autopilot five-phases-synergy --auto to continue"]
```

Always update `production/session-state/active.md` with the run's net result.

---

## Phase 4: Stopping & Escalation

**Stop the loop (clean) when:**
- `--max N` reached, scope exhausted, or epic/sprint has no more ready stories.
- A story is BLOCKED and no other story is eligible.
- `--plan` mode (always stops after planning).

**Escalate (STOP and ask the user via `AskUserQuestion`) only when:**
1. A **design fork with no sensible default AND high blast radius** — the as-built
   honest fix is a major architectural change (Core contract / multiple systems /
   a pillar). Present the options; resume on the answer.
2. **Repeated failure** — the same pipeline step fails >2 times (review still
   CHANGES REQUIRED after 2 fix rounds; >1 real CI failure on one story).
3. **Scope explosion** — a story balloons past ~2× its estimate or its Out-of-Scope
   boundary cannot be honoured.
4. **Forbidden-pattern / clone risk** — anything that would violate the control
   manifest's Forbidden list or the originality policy.
5. **Destructive/irreversible non-git action** would be required (deleting content,
   rewriting history, touching another session's owned files per active.md).

On escalation: write the current state to `active.md` + the decision log, present the
**specific** decision (not "what should I do?") with concrete options, and resume the
exact loop position after the user answers. Everything completed so far stays
committed/pushed — never discard finished work because one story escalated.

---

## Guardrails (hard rules — never violated, any mode)

- **CI is law**: never merge red or pending CI; never skip the full-suite + parse-error gate before commit or merge.
- **Never push or merge to `main` directly**: feature branch + PR only; `--review` never merges at all.
- **Never force-push; never `--no-verify`; never weaken/skip a failing test** to go green — fix the cause.
- **Respect review-mode** (solo/lean/full) for every director gate via `.claude/docs/director-gates.md`.
- **Respect the control manifest** Forbidden patterns, coding standards, and the no-clone originality policy.
- **Conventional Commits** + Story/TR/ADR body refs + the `Co-Authored-By` trailer; reference the design doc/task per coding-standards.
- **Never read/commit secrets** (`.env*`) and never touch files another session owns (per `active.md` coordination contract).
- **File writes go through specialists**: autopilot orchestrates and may make small doc/test edits, but implementation writes are delegated to the routed programmer/engine subagent.

---

## Coordination Notes

- Per-story gates this skill leans on (all in `.claude/docs/director-gates.md`):
  `QL-STORY-READY` (readiness), `LP-CODE-REVIEW` (review), `QL-TEST-COVERAGE`
  (epic close-out). They fire only when review-mode permits (`lean` skips per-skill
  gates; `full` runs them).
- This skill is the per-story Production loop only. It does **not** drive earlier
  stages (brainstorm/map-systems/architecture) or `/gate-check` phase transitions —
  surface those as a "next stage" suggestion when an epic completes.
- For a true unattended multi-story run, prefer `/autopilot [epic] --auto --max all`;
  for hands-off-but-human-merge, `/autopilot [epic]` (default `--review`).

---

## Recommended Next Steps

- `/autopilot [epic-slug]` — drive the epic's ready stories to green PRs (you merge).
- `/autopilot [epic-slug] --auto` — fully unattended, merges as CI passes.
- `/autopilot [story-path] --plan` — preview the decisions before committing to a run.
- Review `production/session-state/autopilot-log.md` after any run to audit decisions.
