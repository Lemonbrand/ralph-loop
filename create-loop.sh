#!/bin/bash
# Ralph Loop Creator - Interactive scaffold for new autonomous agent loops
# Usage: ./create-loop.sh [target-directory]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/templates"

echo ""
echo "  Ralph Loop Creator"
echo "  ==================="
echo ""

# Target directory (where to create the loop)
TARGET_BASE="${1:-.}"
if [ "$TARGET_BASE" = "." ]; then
  read -p "Target project directory (where scripts/ralph-{name}/ will be created): " TARGET_BASE
  TARGET_BASE="${TARGET_BASE:-$(pwd)}"
fi

# Expand ~ and resolve path
TARGET_BASE="${TARGET_BASE/#\~/$HOME}"
TARGET_BASE="$(cd "$TARGET_BASE" 2>/dev/null && pwd || echo "$TARGET_BASE")"

if [ ! -d "$TARGET_BASE" ]; then
  echo "Error: Directory '$TARGET_BASE' does not exist."
  exit 1
fi

echo ""

# Name
read -p "Loop name (short slug, e.g., 'auth-fix', 'seo-cleanup'): " LOOP_NAME
if [ -z "$LOOP_NAME" ]; then
  echo "Error: Name is required."
  exit 1
fi

LOOP_DIR="$TARGET_BASE/scripts/ralph-$LOOP_NAME"
if [ -d "$LOOP_DIR" ]; then
  echo "Error: $LOOP_DIR already exists."
  exit 1
fi

# Goal
echo ""
read -p "Goal (one sentence, what does this loop accomplish?): " GOAL
if [ -z "$GOAL" ]; then
  echo "Error: Goal is required."
  exit 1
fi

# Target repo
echo ""
read -p "Target repo/system path [$TARGET_BASE]: " TARGET_REPO
TARGET_REPO="${TARGET_REPO:-$TARGET_BASE}"

# Mode
echo ""
echo "Mode:"
echo "  1) code       - Code changes to a repository (typecheck, tests, git)"
echo "  2) infra      - Infrastructure ops (SSH, cloud, deployments)"
echo "  3) research   - Read-only analysis (docs, reports, no modifications)"
echo ""
read -p "Select mode [1]: " MODE_CHOICE
case "$MODE_CHOICE" in
  2) MODE="INFRASTRUCTURE" ;;
  3) MODE="RESEARCH" ;;
  *) MODE="READ-WRITE" ;;
esac

# Branch name
echo ""
read -p "Branch name [ralph/$LOOP_NAME]: " BRANCH_NAME
BRANCH_NAME="${BRANCH_NAME:-ralph/$LOOP_NAME}"

# Commit prefix
echo ""
SUGGESTED_PREFIX=$(echo "$LOOP_NAME" | sed 's/-.*//g')
read -p "Commit prefix [$SUGGESTED_PREFIX]: " COMMIT_PREFIX
COMMIT_PREFIX="${COMMIT_PREFIX:-$SUGGESTED_PREFIX}"

# Stories
echo ""
echo "Stories (enter one per line, format: 'TITLE | acceptance criterion 1 | criterion 2')"
echo "Type 'done' when finished. Type 'phase PHASE_NAME' to start a new phase."
echo ""

PHASES_JSON=""
CURRENT_PHASE_NAME="Core"
CURRENT_PHASE_STORIES=""
STORY_COUNT=0
PRIORITY=1
PHASE_COUNT=0

# Determine prefix based on mode
case "$MODE" in
  "READ-WRITE") STORY_PREFIX="FEAT" ;;
  "INFRASTRUCTURE") STORY_PREFIX="SETUP" ;;
  "RESEARCH") STORY_PREFIX="RES" ;;
esac

while true; do
  read -p "> " INPUT

  if [ "$INPUT" = "done" ] || [ -z "$INPUT" ]; then
    # Close current phase if it has stories
    if [ -n "$CURRENT_PHASE_STORIES" ]; then
      PHASE_GATE="true"
      if [ $PHASE_COUNT -eq 0 ]; then
        PHASE_GATE="false"
      fi
      if [ -n "$PHASES_JSON" ]; then
        PHASES_JSON="$PHASES_JSON,"
      fi
      PHASES_JSON="$PHASES_JSON
    {
      \"name\": \"$CURRENT_PHASE_NAME\",
      \"description\": \"Phase: $CURRENT_PHASE_NAME\",
      \"phaseGate\": $PHASE_GATE,
      \"stories\": [$CURRENT_PHASE_STORIES
      ]
    }"
      PHASE_COUNT=$((PHASE_COUNT + 1))
    fi
    break
  fi

  # Check for phase marker
  if [[ "$INPUT" == phase\ * ]]; then
    # Close current phase
    if [ -n "$CURRENT_PHASE_STORIES" ]; then
      PHASE_GATE="true"
      if [ $PHASE_COUNT -eq 0 ]; then
        PHASE_GATE="false"
      fi
      if [ -n "$PHASES_JSON" ]; then
        PHASES_JSON="$PHASES_JSON,"
      fi
      PHASES_JSON="$PHASES_JSON
    {
      \"name\": \"$CURRENT_PHASE_NAME\",
      \"description\": \"Phase: $CURRENT_PHASE_NAME\",
      \"phaseGate\": $PHASE_GATE,
      \"stories\": [$CURRENT_PHASE_STORIES
      ]
    }"
      PHASE_COUNT=$((PHASE_COUNT + 1))
    fi
    CURRENT_PHASE_NAME="${INPUT#phase }"
    CURRENT_PHASE_STORIES=""
    echo "  Starting phase: $CURRENT_PHASE_NAME"
    continue
  fi

  # Parse story: TITLE | criterion 1 | criterion 2
  IFS='|' read -ra PARTS <<< "$INPUT"
  TITLE=$(echo "${PARTS[0]}" | xargs)
  STORY_COUNT=$((STORY_COUNT + 1))
  STORY_ID="$STORY_PREFIX-$(printf '%03d' $STORY_COUNT)"

  # Build acceptance array
  ACCEPTANCE=""
  for ((j=1; j<${#PARTS[@]}; j++)); do
    CRITERION=$(echo "${PARTS[$j]}" | xargs)
    if [ -n "$CRITERION" ]; then
      if [ -n "$ACCEPTANCE" ]; then
        ACCEPTANCE="$ACCEPTANCE,"
      fi
      ACCEPTANCE="$ACCEPTANCE
            \"$CRITERION\""
    fi
  done

  if [ -z "$ACCEPTANCE" ]; then
    ACCEPTANCE="
            \"$TITLE completed successfully\""
  fi

  if [ -n "$CURRENT_PHASE_STORIES" ]; then
    CURRENT_PHASE_STORIES="$CURRENT_PHASE_STORIES,"
  fi
  CURRENT_PHASE_STORIES="$CURRENT_PHASE_STORIES
        {
          \"id\": \"$STORY_ID\",
          \"title\": \"$TITLE\",
          \"description\": \"$TITLE\",
          \"acceptance\": [$ACCEPTANCE
          ],
          \"files\": [],
          \"dependsOn\": [],
          \"passes\": false,
          \"priority\": $PRIORITY
        }"

  PRIORITY=$((PRIORITY + 1))
  echo "  Added: $STORY_ID - $TITLE"
done

if [ $STORY_COUNT -eq 0 ]; then
  echo ""
  echo "No stories entered. Creating with empty PRD (edit prd.json manually)."
  PHASES_JSON="
    {
      \"name\": \"Phase 1\",
      \"description\": \"Add your stories here\",
      \"phaseGate\": true,
      \"stories\": []
    }"
fi

# Monitor
echo ""
read -p "Enable voice monitor (macOS say)? [Y/n]: " MONITOR_CHOICE
MONITOR_CHOICE="${MONITOR_CHOICE:-Y}"

# Safety rails
echo ""
echo "Safety rails (things the loop must NEVER do, one per line, 'done' to finish):"
SAFETY_RAILS=""
while true; do
  read -p "  > " RAIL
  if [ "$RAIL" = "done" ] || [ -z "$RAIL" ]; then
    break
  fi
  SAFETY_RAILS="$SAFETY_RAILS\n- **Never** $RAIL"
done

if [ -z "$SAFETY_RAILS" ]; then
  case "$MODE" in
    "READ-WRITE")
      SAFETY_RAILS="\n- **Never** touch .env files or production credentials\n- **Never** force push or reset --hard\n- **Never** deploy without phase gate approval"
      ;;
    "INFRASTRUCTURE")
      SAFETY_RAILS="\n- **Never** delete data without verification\n- **Never** modify SSH config without backup\n- **Never** run sudo without phase gate"
      ;;
    "RESEARCH")
      SAFETY_RAILS="\n- **Never** modify any files in the target system\n- **Never** make outbound API calls without approval"
      ;;
  esac
fi

# Create the directory
echo ""
echo "Creating loop at: $LOOP_DIR"
mkdir -p "$LOOP_DIR"

# Write prd.json
cat > "$LOOP_DIR/prd.json" << PRDJSON
{
  "name": "$GOAL",
  "description": "$GOAL",
  "branchName": "$BRANCH_NAME",
  "targetRepo": "$TARGET_REPO",
  "phases": [$PHASES_JSON
  ]
}
PRDJSON

# Write progress.txt
cat > "$LOOP_DIR/progress.txt" << PROGRESS
# Ralph Progress Log
Started: $GOAL
---
PROGRESS

# Copy ralph.sh
cp "$TEMPLATE_DIR/ralph.sh" "$LOOP_DIR/ralph.sh"
chmod +x "$LOOP_DIR/ralph.sh"

# Write CLAUDE.md from template with substitutions
sed \
  -e "s|{GOAL}|$GOAL|g" \
  -e "s|{GOAL_DESCRIPTION}|$GOAL|g" \
  -e "s|{MODE}|$MODE|g" \
  -e "s|{TARGET_PATH}|$TARGET_REPO|g" \
  -e "s|{COMMIT_PREFIX}|$COMMIT_PREFIX|g" \
  -e "s|{LOOP_DIR}|$LOOP_DIR|g" \
  -e "s|{BRANCH_NAME}|$BRANCH_NAME|g" \
  -e "s|{PREFIX}|$STORY_PREFIX|g" \
  "$TEMPLATE_DIR/CLAUDE.md.template" > "$LOOP_DIR/CLAUDE.md"

# Append safety rails to CLAUDE.md
if [ -n "$SAFETY_RAILS" ]; then
  # Replace the placeholder safety rails section
  printf "\n## Safety Rails (Custom)\n" >> "$LOOP_DIR/CLAUDE.md"
  printf "$SAFETY_RAILS\n" >> "$LOOP_DIR/CLAUDE.md"
fi

# Monitor
if [[ "$MONITOR_CHOICE" =~ ^[Yy] ]]; then
  cp "$TEMPLATE_DIR/monitor.sh" "$LOOP_DIR/monitor.sh"
  chmod +x "$LOOP_DIR/monitor.sh"
  echo "Monitor: enabled (run via launchd or: watch -n 120 $LOOP_DIR/monitor.sh)"
fi

# Summary
echo ""
echo "  Loop created!"
echo "  ============="
echo ""
echo "  Directory:  $LOOP_DIR"
echo "  Branch:     $BRANCH_NAME"
echo "  Mode:       $MODE"
echo "  Stories:    $STORY_COUNT"
echo "  Phases:     $PHASE_COUNT"
echo ""
echo "  Files:"
ls -1 "$LOOP_DIR" | sed 's/^/    /'
echo ""
echo "  Run it:"
echo "    cd $LOOP_DIR"
echo "    ./ralph.sh --tool claude 10"
echo ""
echo "  Edit prd.json to refine stories and acceptance criteria before running."
echo ""
