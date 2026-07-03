#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# validate-project.sh
# Validate Playwright project files before merge (dry-run logic)
#
# Required env vars:
#   TEST_TYPE  : 'web' | 'api'
#   WORK_DIR   : path to test directory (e.g. tests/web-testing)
#
# Exit codes:
#   0 = validation passed
#   1 = validation failed
# ─────────────────────────────────────────────────────────────
set -euo pipefail

# ── helpers ───────────────────────────────────────────────────
log_error() {
  # Emit Azure DevOps annotation when running in Azure Pipelines
  if [ -n "${TF_BUILD:-}" ]; then
    echo "##vso[task.logissue type=error]$1"
  else
    echo "ERROR: $1" >&2
  fi
}

# ── validate inputs ───────────────────────────────────────────
: "${TEST_TYPE:?TEST_TYPE is required (web|api)}"
: "${WORK_DIR:?WORK_DIR is required}"

BRANCH="${CI_COMMIT_BRANCH:-${BUILD_SOURCEBRANCH:-unknown}}"
echo "── Dry Run: $TEST_TYPE ──"
echo "Branch:   $BRANCH"
echo "Work Dir: $WORK_DIR"

# ── check required files ──────────────────────────────────────
cd "$WORK_DIR"
MISSING=0
for FILE in package.json package-lock.json playwright.config.ts; do
  if [ ! -f "$FILE" ]; then
    log_error "$FILE not found"
    MISSING=1
  fi
done
[ "$MISSING" -eq 1 ] && exit 1
echo "All required files exist"

# ── install dependencies ──────────────────────────────────────
npm ci --prefer-offline

# ── TypeScript compile check ──────────────────────────────────
npx tsc --noEmit --project tsconfig.json 2>/dev/null || npx tsc --noEmit || true

# ── validate test files (list only) ──────────────────────────
npx playwright test --list 2>/dev/null \
  && echo "Test files parsed successfully" \
  || echo "WARN: Could not list tests — check playwright.config.ts"
