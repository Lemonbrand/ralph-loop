#!/bin/bash
# Ralph Loop Runner
# Spawns fresh AI agent instances to work through a PRD, one story per iteration.
# Usage: ./ralph.sh [--tool amp|claude] [--no-sandbox] [max_iterations]

set -e

# Parse arguments
TOOL="claude"
MAX_ITERATIONS=10
NO_SANDBOX=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --no-sandbox)
      NO_SANDBOX=true
      shift
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "claude" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'amp' or 'claude'."
  exit 1
fi

# nono sandbox detection (optional, install via: brew install nono)
NONO_CMD=""
if [[ "$NO_SANDBOX" == false ]] && command -v nono &>/dev/null; then
  NONO_CMD="nono run --profile ralph-loop --silent --no-rollback --"
  echo "Sandbox: nono (profile: ralph-loop)"
elif [[ "$NO_SANDBOX" == false ]]; then
  echo "Sandbox: disabled (nono not found)"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"

    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Headless git auth (optional, requires ~/.ssh/id_ed25519_ralph)
# Uncomment these lines if you need git push/pull without interactive auth:
#
# export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/id_ed25519_ralph -o IdentitiesOnly=yes"
# export GIT_CONFIG_COUNT=2
# export GIT_CONFIG_KEY_0="url.git@github.com:.insteadOf"
# export GIT_CONFIG_VALUE_0="https://github.com/"
# export GIT_CONFIG_KEY_1="commit.gpgsign"
# export GIT_CONFIG_VALUE_1="false"

echo "Starting Ralph - Tool: $TOOL - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  if [[ "$TOOL" == "amp" ]]; then
    OUTPUT=$(cat "$SCRIPT_DIR/prompt.md" | $NONO_CMD amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  else
    OUTPUT=$(unset CLAUDECODE; $NONO_CMD claude --dangerously-skip-permissions -p "$(cat "$SCRIPT_DIR/CLAUDE.md")" 2>&1 | tee /dev/stderr) || true
  fi

  # Check for completion
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  # Check for phase gate
  if echo "$OUTPUT" | grep -q "<promise>PHASE_GATE</promise>"; then
    echo ""
    echo "Ralph hit a phase gate at iteration $i."
    echo "Review progress.txt and re-run when ready."
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
