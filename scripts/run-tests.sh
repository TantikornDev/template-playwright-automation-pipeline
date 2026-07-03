#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# run-tests.sh
# Execute Playwright tests and write results to test-results.env
#
# Required env vars:
#   TEST_TYPE  : 'web' | 'api'
#   TEST_ENV   : environment name (DEV, SIT, UAT)
#   WORK_DIR   : path to test directory (e.g. tests/web-testing)
#
# Optional env vars:
#   TEST_PATH  : specific test file or folder (default: run all)
#   TEST_TAG   : grep tag e.g. @smoke (default: none)
#   EXTRA_ENV  : extra KEY=VALUE overrides e.g. PARALLEL=true (default: none)
#   PARALLEL   : 'true' to run with default workers (default: single worker)
#
# Output file: test-results.env
#   PASSED, FAILED, SKIPPED, FLAKY, DURATION, ENV, TEST_TYPE, TEST_PATH
#   → GitLab CI: declare as artifacts.reports.dotenv
#   → Azure DevOps: emit ##vso[task.setvariable] (auto-detected via TF_BUILD)
#
# Exit code mirrors playwright exit code (non-zero = test failures)
# ─────────────────────────────────────────────────────────────
set -uo pipefail   # no -e: capture playwright exit code explicitly

: "${TEST_TYPE:?TEST_TYPE is required (web|api)}"
: "${TEST_ENV:?TEST_ENV is required (DEV|SIT|UAT)}"
: "${WORK_DIR:?WORK_DIR is required}"

ENV_LOWER=$(echo "$TEST_ENV" | tr '[:upper:]' '[:lower:]')
TEST_PATH_VAL="${TEST_PATH:- }"
TEST_TAG_VAL="${TEST_TAG:- }"
EXTRA_ENV_VAL="${EXTRA_ENV:- }"
RESULTS_ENV_FILE="${RESULTS_ENV_FILE:-test-results.env}"
CONFIG_FILE="${WORK_DIR}/playwright.config.ts"
REPORT_DIR="${WORK_DIR}/playwright-report"

echo "── Run $TEST_TYPE Tests on $TEST_ENV ──"

# ── build playwright command ──────────────────────────────────
CMD="ENV=$ENV_LOWER ${WORK_DIR}/node_modules/.bin/playwright test --config=$CONFIG_FILE"
[ "${PARALLEL:-}" != "true" ] && CMD="$CMD --workers=1"
[ "$TEST_PATH_VAL" != " " ] && [ -n "$TEST_PATH_VAL" ] && CMD="$CMD $TEST_PATH_VAL"
[ "$TEST_TAG_VAL"  != " " ] && [ -n "$TEST_TAG_VAL"  ] && CMD="$CMD --grep '$TEST_TAG_VAL'"
[ "$TEST_TYPE"     = "api" ] && CMD="$CMD --grep-invert '@database|@heavy'"

# Apply extra env overrides
[ "$EXTRA_ENV_VAL" != " " ] && [ -n "$EXTRA_ENV_VAL" ] && export $EXTRA_ENV_VAL

echo "Command: $CMD"
eval $CMD
TEST_EXIT=$?

# ── parse results.json ────────────────────────────────────────
RESULTS_FILE=$(find . -name "results.json" -path "*/test-results/*" 2>/dev/null | head -1)
if [ -n "$RESULTS_FILE" ]; then
  parse() { node -e "$1" 2>/dev/null || echo "?"; }
  PASSED=$(parse  "const r=require('./$RESULTS_FILE');let c=0;(function w(ss){ss.forEach(s=>{(s.specs||[]).forEach(sp=>{(sp.tests||[]).forEach(t=>{if(['passed','expected'].includes(t.results?.[0]?.status))c++})});w(s.suites||[])})})(r.suites||[]);console.log(c)")
  FAILED=$(parse  "const r=require('./$RESULTS_FILE');let c=0;(function w(ss){ss.forEach(s=>{(s.specs||[]).forEach(sp=>{(sp.tests||[]).forEach(t=>{if(['failed','unexpected','timedOut'].includes(t.results?.[0]?.status))c++})});w(s.suites||[])})})(r.suites||[]);console.log(c)")
  SKIPPED=$(parse "const r=require('./$RESULTS_FILE');let c=0;(function w(ss){ss.forEach(s=>{(s.specs||[]).forEach(sp=>{(sp.tests||[]).forEach(t=>{if((t.results?.[0]?.status||t.status)==='skipped')c++})});w(s.suites||[])})})(r.suites||[]);console.log(c)")
  FLAKY=$(parse   "const r=require('./$RESULTS_FILE');let c=0;(function w(ss){ss.forEach(s=>{(s.specs||[]).forEach(sp=>{(sp.tests||[]).forEach(t=>{if(t.results&&t.results.length>1&&t.results.at(-1)?.status==='passed')c++})});w(s.suites||[])})})(r.suites||[]);console.log(c)")
  DURATION=$(parse "const r=require('./$RESULTS_FILE');const d=r.stats?.duration||0;console.log(Math.floor(d/60000)+'m '+Math.floor((d%60000)/1000)+'s')")
else
  PASSED="?"; FAILED="?"; SKIPPED="?"; FLAKY="0"; DURATION="?"
fi

DISPLAY_PATH="$TEST_PATH_VAL"
[ "$DISPLAY_PATH" = " " ] || [ -z "$DISPLAY_PATH" ] && DISPLAY_PATH="All"

# ── write test-results.env ────────────────────────────────────
# GitLab CI reads this via: artifacts.reports.dotenv
cat > "$RESULTS_ENV_FILE" <<EOF
ENV=$ENV_LOWER
TEST_TYPE=$TEST_TYPE
TEST_PATH=$DISPLAY_PATH
PASSED=$PASSED
FAILED=$FAILED
SKIPPED=$SKIPPED
FLAKY=$FLAKY
DURATION=$DURATION
REPORT_DIR=$REPORT_DIR
EOF

echo "Results → $RESULTS_ENV_FILE"
cat "$RESULTS_ENV_FILE"

# ── Azure DevOps: emit output variables (GitLab: no-op) ──────
if [ -n "${TF_BUILD:-}" ]; then
  echo "##vso[task.setvariable variable=ENV;isOutput=true]$ENV_LOWER"
  echo "##vso[task.setvariable variable=TEST_TYPE;isOutput=true]$TEST_TYPE"
  echo "##vso[task.setvariable variable=TEST_PATH;isOutput=true]$DISPLAY_PATH"
  echo "##vso[task.setvariable variable=PASSED;isOutput=true]$PASSED"
  echo "##vso[task.setvariable variable=FAILED;isOutput=true]$FAILED"
  echo "##vso[task.setvariable variable=SKIPPED;isOutput=true]$SKIPPED"
  echo "##vso[task.setvariable variable=FLAKY;isOutput=true]$FLAKY"
  echo "##vso[task.setvariable variable=DURATION;isOutput=true]$DURATION"
fi

exit $TEST_EXIT
