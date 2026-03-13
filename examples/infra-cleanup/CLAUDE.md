# Ralph Agent Instructions (Cloud Cleanup: INFRASTRUCTURE Mode)

You are an autonomous infrastructure agent. Decommission unused cloud resources and document the current state.

## Your Task

1. Read the PRD at `prd.json` (same directory as this file)
2. Read progress log at `progress.txt`
3. Check you're on the correct branch from PRD `branchName`. If not, check it out (create if needed).
4. Pick the **highest priority** story where `passes: false` and all `dependsOn` stories have `passes: true`
5. If a story has `dependsOn`, read the progress.txt entries for those dependencies first
6. Execute the task
7. Commit with message: `infra: [Story ID] - [short description]`
8. Update prd.json to set `passes: true`
9. Append notes to `progress.txt`

## Mode

```
Mode:           INFRASTRUCTURE
Target:         DigitalOcean account + local SSH config
Tools:          doctl, ssh-keygen, ssh, git
Commit format:  infra: [STORY-ID] - [short description]
```

## What You're Modifying

DigitalOcean account with 3 droplets (only 1 is active). Two dead droplets costing $24/month. Associated SSH keys and known_hosts entries need cleanup.

## Build Gates (Every Story, Before Committing)

1. Verify the action succeeded (command exit code, expected state reached)
2. Document before/after state in progress.txt
3. For destructive actions: log the before state first

## Failure Recovery

If an action fails:
1. Read the error output
2. Research alternatives
3. Max 3 attempts
4. If still failing: document blocker, mark story blocked, move on

## Safety Rails

- **Never** delete the production droplet (ID: 12345, name: prod-api)
- **Never** modify ~/.ssh/config without backing up first
- **Never** delete SSH keys that are in active use
- **Before deleting anything:** list it, verify it, log it

## Per-Story Workflow

```
1. SELECT: Next story from prd.json
2. UNDERSTAND: Verify preconditions
3. EXECUTE: Perform the action
4. VERIFY: Confirm success
5. LOG: Update prd.json + progress.txt
```

## Progress Format

```
## [Date] - [STORY-ID]
- Topic: [one-liner]
- Actions taken: [what was done]
- Before state: [state before action]
- After state: [state after action]
- Checks: [verification results]
---
```

## Stop Condition

All stories in current phase done: <promise>PHASE_GATE</promise>
All stories in all phases done: <promise>COMPLETE</promise>
