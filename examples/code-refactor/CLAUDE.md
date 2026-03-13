# Ralph Agent Instructions (API Auth Hardening: READ-WRITE Mode)

You are an autonomous code implementation agent. Harden the authentication system for the Express API.

## Your Task

1. Read the PRD at `prd.json` (same directory as this file)
2. Read progress log at `progress.txt`
3. Check you're on the correct branch from PRD `branchName`. If not, check it out (create if needed).
4. Pick the **highest priority** story where `passes: false` and all `dependsOn` stories have `passes: true`
5. If a story has `dependsOn`, read the progress.txt entries for those dependencies first
6. Execute the implementation (see Per-Story Workflow below)
7. Commit with message: `auth: [Story ID] - [short description]`
8. Update prd.json to set `passes: true`
9. Append notes to `progress.txt`

## Mode

```
Mode:           READ-WRITE
Target:         /Users/you/your-api/
Commit format:  auth: [STORY-ID] - [short description]
PRD + progress: /Users/you/your-api/scripts/ralph-auth/
```

## What You're Modifying

Express.js API with JWT authentication. Currently has no rate limiting on login, no token rotation, and password reset tokens don't expire. ~15K LOC, TypeScript, Jest for testing, PostgreSQL via Prisma.

## Build Gates (Every Story, Before Committing)

1. `npm run typecheck` must pass
2. `npm test` must pass
3. `git diff --stat` must show < 1000 LOC per commit (deletions excepted)

## Failure Recovery

If code breaks or tests fail:
1. Read the error output
2. Fix the issue
3. Re-run the failing check
4. Max 3 attempts per failure
5. If still failing: document blocker in progress.txt, mark story blocked, move to next

## Safety Rails

- **Never** touch `.env` or `.env.production`
- **Never** modify the database migration files in `prisma/migrations/`
- **Never** force push or reset --hard
- **Never** change JWT_SECRET or any production secrets

## Branch Strategy

```
ralph/auth-hardening (working branch)
  ├── story/SEC-001
  ├── story/SEC-002
  └── ...
```

## Per-Story Workflow (The Inner Loop)

```
1. SELECT: Read prd.json, pick next story
2. BRANCH: git checkout ralph/auth-hardening && git checkout -b story/[ID]
3. UNDERSTAND: Read relevant source files and tests
4. EXECUTE: Write code + tests
5. CHECK: typecheck, test, diff size
6. REVIEW: Self-review diff, verify acceptance criteria
7. MERGE: git checkout ralph/auth-hardening && git merge story/[ID]
8. LOG: Update prd.json + progress.txt, commit
```

## Progress Format

```
## [Date] - [STORY-ID]
- Topic: [one-liner]
- Changes: [files modified/created/deleted]
- Tests added: [list]
- Checks: typecheck ✓ tests ✓
- Key decisions: [choices made]
---
```

## Phase Gate Process

When all stories in a phase pass:
1. Run full test suite
2. Append phase summary to progress.txt
3. Output: <promise>PHASE_GATE</promise>

## Rules

- Be brutally honest in progress.txt.
- If stuck, document and move on.
- Do NOT format existing code.

## Stop Condition

All stories in current phase done: <promise>PHASE_GATE</promise>
All stories in all phases done: <promise>COMPLETE</promise>
