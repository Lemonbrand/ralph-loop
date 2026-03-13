# Ralph Loop

Autonomous AI agent loops with phase gates, voice alerts, and sandboxing. Runs [Claude Code](https://docs.anthropic.com/en/docs/claude-code) or [Amp](https://amp.dev) on autopilot until your PRD is done.

Built on top of [snarktank/ralph](https://github.com/snarktank/ralph) (the original autonomous agent loop by Ryan Carson), this project extends the concept with:

- **Phase gates**: pause between phases for human review before proceeding
- **Voice alerts**: macOS `say` notifications when the loop hits a gate, gets blocked, or finishes
- **Three modes**: code changes, infrastructure ops, or read-only research
- **Branch-per-story**: each story gets its own git branch, merged back after checks pass
- **Sandboxing**: optional [nono](https://github.com/anthropics/nono) integration to restrict file/network access
- **Headless git auth**: SSH key setup so loops push/pull without interactive auth (1Password, etc.)

## How It Works

A Ralph loop is a directory containing 5 files:

```
scripts/ralph-myproject/
  CLAUDE.md       # Agent instructions (what to do, how to do it, safety rails)
  prd.json        # Stories with acceptance criteria, grouped into phases
  progress.txt    # Append-only log (the agent's memory between iterations)
  ralph.sh        # The bash runner (same across all loops)
  monitor.sh      # Optional: voice alerts via macOS say
```

The runner (`ralph.sh`) spawns a fresh Claude Code (or Amp) instance per iteration. Each instance:

1. Reads the PRD, finds the next incomplete story
2. Creates a feature branch
3. Does the work
4. Runs build checks (typecheck, tests, etc.)
5. Self-reviews the diff
6. Merges back, marks the story as done
7. Logs what happened to `progress.txt`
8. Exits. Next iteration picks up the next story.

When all stories in a phase pass, the agent outputs `<promise>PHASE_GATE</promise>` and stops. You review, approve, and re-run. When everything across all phases passes: `<promise>COMPLETE</promise>`.

```
Phase 0: Research (no gate)     Phase 1: Core Work (GATE)     Phase 2: Polish (GATE)
  ┌─────────────┐                ┌─────────────┐               ┌─────────────┐
  │ RECON-001   │──flows──into──▶│ IMPL-001    │──stops──for──▶│ CLEAN-001   │
  │ RECON-002   │                │ IMPL-002    │  human review │ CLEAN-002   │
  └─────────────┘                │ IMPL-003    │               └─────────────┘
                                 └─────────────┘
```

## Quickstart

### Option 1: Use the CLI (recommended)

```bash
git clone https://github.com/Lemonbrand/ralph-loop.git
cd ralph-loop
./create-loop.sh
```

The CLI asks you:
- **Name**: short slug (e.g., "auth-fix", "seo-cleanup")
- **Goal**: one sentence
- **Target**: what repo/system the loop modifies
- **Mode**: `code`, `infra`, or `research`
- **Stories**: tasks with acceptance criteria
- **Phase gates**: where to pause for review

Then generates all 5 files into `scripts/ralph-{name}/` in your target project.

### Option 2: Copy templates manually

```bash
cp -r templates/ /path/to/your/project/scripts/ralph-myloop/
cd /path/to/your/project/scripts/ralph-myloop/
# Edit CLAUDE.md and prd.json for your use case
chmod +x ralph.sh monitor.sh
```

### Run it

```bash
cd scripts/ralph-myloop
./ralph.sh --tool claude 10    # 10 iterations with Claude Code
./ralph.sh --tool amp 10       # 10 iterations with Amp
```

Flags:
- `--tool claude|amp`: which AI tool to use (default: amp)
- `--no-sandbox`: skip nono sandboxing even if installed
- Number argument: max iterations (default: 10)

## Writing Good Stories

The biggest factor in loop success is story quality. Each story must be completable in a single AI context window.

**Good stories:**
```json
{
  "id": "AUTH-001",
  "title": "Add rate limiting to login endpoint",
  "description": "Add express-rate-limit middleware to POST /api/auth/login. 5 attempts per IP per 15 minutes. Return 429 with retry-after header.",
  "acceptance": [
    "Rate limiter applied to login route only",
    "429 response includes Retry-After header",
    "Existing tests still pass",
    "New test covers rate limit trigger"
  ],
  "dependsOn": [],
  "passes": false,
  "priority": 1
}
```

**Bad stories** (too big, too vague):
- "Build the authentication system"
- "Refactor the codebase"
- "Make it faster"

Rules of thumb:
- One story = one commit
- < 500 lines of change (excluding deletions)
- 2-4 concrete acceptance criteria
- Use `dependsOn` when order matters

## PRD Format

```json
{
  "name": "Project Name",
  "description": "What this loop accomplishes",
  "branchName": "ralph/my-feature",
  "targetRepo": "/path/to/repo",
  "phases": [
    {
      "name": "Phase Name",
      "description": "What this phase covers",
      "phaseGate": true,
      "stories": [
        {
          "id": "PREFIX-001",
          "title": "Story title",
          "description": "Detailed description of what to do",
          "acceptance": ["criterion 1", "criterion 2"],
          "files": ["src/relevant-file.ts"],
          "dependsOn": [],
          "passes": false,
          "priority": 1
        }
      ]
    }
  ]
}
```

| Field | Purpose |
|-------|---------|
| `id` | Unique story identifier (used in commits, progress log) |
| `acceptance` | Concrete criteria the agent checks before marking done |
| `files` | Hints for the agent about which files to read/modify |
| `dependsOn` | Array of story IDs that must pass first |
| `passes` | Set to `true` by the agent when done |
| `priority` | Lower number = higher priority (agent picks lowest available) |
| `phaseGate` | When `true`, agent stops after all stories in this phase pass |

## Three Modes

### Code Mode (`READ-WRITE`)

For making code changes to a repository. The agent creates feature branches, writes code, runs checks, and merges.

**Build gates:** typecheck, lint, unit tests, e2e tests, diff size check
**Commit format:** `{prefix}: {STORY-ID} - {description}`
**Example use cases:** feature implementation, refactoring, test coverage, dependency upgrades

### Infrastructure Mode (`INFRASTRUCTURE`)

For system-level changes: SSH keys, cloud resources, deployments, configuration.

**Build gates:** verify action succeeded, document before/after state
**Safety rails:** no destructive actions without verification, backup before modifying config
**Example use cases:** server decommission, auth setup, CI/CD configuration, cloud migration

### Research Mode (`RESEARCH`)

Read-only analysis. The agent gathers information, documents findings, but makes no changes to the target system.

**Build gates:** verify findings with sources, cross-reference claims
**Safety rails:** strictly read-only, no modifications
**Example use cases:** security audit, dependency analysis, architecture review, competitive analysis

## The Monitor (Voice Alerts)

`monitor.sh` checks `progress.txt` every 2 minutes and uses macOS `say` to announce:

- **Phase gate**: "Ralph hit a phase gate. Needs your review."
- **Blocked**: "Ralph is blocked. Check progress."
- **Complete**: "Ralph loop complete."

Uses a `.monitor-state` file to avoid repeating the same announcement.

### Setup with launchd (macOS)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.yourname.ralph-monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/path/to/your/loop/monitor.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>120</integer>
    <key>RunAtLoad</key>
    <false/>
</dict>
</plist>
```

```bash
cp your-monitor.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/your-monitor.plist
```

## Advanced: Headless Git Auth

By default, Ralph loops inherit your shell's git auth (SSH agent, credential helper, etc.). If you run loops in a headless context (cron, background process, sandboxed), you need dedicated auth.

`ralph.sh` includes environment-based SSH auth that activates automatically:

```bash
# These env vars are set inside ralph.sh before launching the agent
export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519_ralph -o IdentitiesOnly=yes"
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0="url.git@github.com:.insteadOf"
export GIT_CONFIG_VALUE_0="https://github.com/"
export GIT_CONFIG_KEY_1="commit.gpgsign"
export GIT_CONFIG_VALUE_1="false"
```

Setup:
1. `ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_ralph -C "ralph-headless"`
2. Add the public key to your GitHub account (Settings > SSH keys)
3. That's it. `ralph.sh` handles the rest. Your normal interactive git is unaffected.

The `insteadOf` rule transparently rewrites HTTPS remotes to SSH at the transport layer, so you don't need to change any remote URLs.

## Advanced: nono Sandboxing

[nono](https://github.com/anthropics/nono) restricts what the agent can access on your machine. When `ralph.sh` detects nono on PATH, it wraps the agent in a sandbox automatically.

```bash
# Install nono
brew install nono

# Create a profile
mkdir -p ~/.config/nono/profiles
cat > ~/.config/nono/profiles/ralph-loop.json << 'EOF'
{
  "extends": "claude-code",
  "allow": [
    {"path": "~/myproject", "access": "read-write"},
    {"path": "~/another-repo", "access": "read-write"}
  ]
}
EOF
```

The `--no-sandbox` flag bypasses nono when needed:
```bash
./ralph.sh --tool claude --no-sandbox 10
```

## Related Projects

- **[snarktank/ralph](https://github.com/snarktank/ralph)**: The original Ralph by Ryan Carson. This project builds on his concept of fresh-context-per-iteration autonomous loops. If you want the simplest possible setup, start there.
- **[nono](https://github.com/anthropics/nono)**: Anthropic's sandboxing tool for AI agents. Optional but recommended for production loops.
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)**: Anthropic's CLI for Claude. The `--dangerously-skip-permissions` flag enables autonomous operation (required for Ralph loops).
- **[Amp](https://amp.dev)**: Alternative AI coding tool. Ralph supports both via `--tool amp|claude`.

## Claude Code Skills Integration

If you use Claude Code, you can install Ralph as a skill for interactive loop creation:

1. Copy `templates/` into your project's `.claude/skills/create-ralph-loop/`
2. Add to your project's CLAUDE.md:
   ```
   - `/create-ralph-loop`: Scaffold a new Ralph loop with interactive setup
   ```
3. Use `/create-ralph-loop` in any Claude Code session to scaffold a new loop with guided prompts

## FAQ

**How many iterations should I run?**
Start with the number of stories + a few extra for failures/retries. A 10-story PRD usually completes in 12-15 iterations. If it hasn't finished, check `progress.txt` for what's going wrong.

**What if a story keeps failing?**
After 3 failed attempts, the agent marks the story as blocked in `progress.txt` and moves to the next one. Review the blocker, fix the underlying issue, and re-run.

**Can I run multiple loops in parallel?**
Yes, as long as they work on different branches and don't modify the same files. Each loop is self-contained in its own directory.

**Does it work with other AI tools?**
The runner supports Claude Code and Amp out of the box. For other tools, modify the execution block in `ralph.sh` to call your preferred CLI.

**How do I add stories mid-run?**
Edit `prd.json` directly. Add new stories with `"passes": false` and the correct `priority`. The next iteration will pick them up.

## License

MIT
