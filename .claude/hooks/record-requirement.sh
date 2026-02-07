#!/bin/bash
# Record user prompt to requirements_records.md

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Skip if prompt is empty
if [ -z "$PROMPT" ]; then
  exit 0
fi

AUDIT_DIR="${CWD}/audits"
mkdir -p "$AUDIT_DIR"
YEAR_MONTH=$(date '+%Y%m')
RECORD_FILE="${AUDIT_DIR}/requirements_records_${YEAR_MONTH}.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Create file with header if it doesn't exist
if [ ! -f "$RECORD_FILE" ]; then
  cat > "$RECORD_FILE" << 'HEADER'
# Requirements Records

User request log, auto-recorded by Claude Code hook.

---

HEADER
fi

# Append the record
cat >> "$RECORD_FILE" << EOF
### $TIMESTAMP

$PROMPT

---

EOF

exit 0
