#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# notify-teams.sh
# Send Playwright test results to Microsoft Teams via webhook
#
# Required env vars:
#   WEBHOOK_URL   : Teams incoming webhook URL
#   TEST_TYPE     : 'web' | 'api'
#   PASSED        : number of passed tests (or '?')
#   FAILED        : number of failed tests (or '?')
#   SKIPPED       : number of skipped tests (or '?')
#   FLAKY         : number of flaky tests
#   DURATION      : formatted duration e.g. '2m 15s'
#
# Optional env vars (default to generic values if not set):
#   TEST_PATH     : test path/scope that was run (default: All)
#   ENV_NAME      : environment name (default: unknown)
#   JOB_STATUS    : overall status 'Succeeded'|'Failed'|... (default: Unknown)
#   PIPELINE_URL  : link to pipeline run
#   REPORT_URL    : link to test report
#   BRANCH        : branch name
#   TRIGGERED_BY  : who/what triggered the run
#   BUILD_NUMBER  : pipeline/build number
#   PIPELINE_NAME : name of pipeline/project
# ─────────────────────────────────────────────────────────────
set -euo pipefail

: "${WEBHOOK_URL:?WEBHOOK_URL is required}"
: "${TEST_TYPE:?TEST_TYPE is required}"
: "${PASSED:?PASSED is required}"
: "${FAILED:?FAILED is required}"

# ── resolve optional vars ─────────────────────────────────────
TEST_PATH="${TEST_PATH:-All}"
ENV_NAME="${ENV_NAME:-unknown}"
JOB_STATUS="${JOB_STATUS:-Unknown}"
PIPELINE_URL="${PIPELINE_URL:-#}"
REPORT_URL="${REPORT_URL:-#}"
BRANCH="${BRANCH:-unknown}"
TRIGGERED_BY="${TRIGGERED_BY:-CI}"
BUILD_NUMBER="${BUILD_NUMBER:-?}"
PIPELINE_NAME="${PIPELINE_NAME:-QA Pipeline}"
SKIPPED="${SKIPPED:-?}"
FLAKY="${FLAKY:-0}"
DURATION="${DURATION:-?}"

# ── determine color and icon ──────────────────────────────────
TYPE_UPPER=$(echo "$TEST_TYPE" | tr '[:lower:]' '[:upper:]')

if [ "$FAILED" != "?" ] && [ "$FAILED" != "0" ] && [ -n "$FAILED" ]; then
  COLOR="dc3545"; ICON="❌"; DISPLAY_STATUS="Failed ($FAILED)"
elif [ "$JOB_STATUS" = "Succeeded" ] || [ "$JOB_STATUS" = "success" ]; then
  COLOR="28a745"; ICON="✅"; DISPLAY_STATUS="$JOB_STATUS"
elif [ "$JOB_STATUS" = "Failed" ] || [ "$JOB_STATUS" = "failed" ]; then
  COLOR="dc3545"; ICON="❌"; DISPLAY_STATUS="$JOB_STATUS"
else
  COLOR="ffc107"; ICON="⚠️"; DISPLAY_STATUS="$JOB_STATUS"
fi

# ── build Teams MessageCard JSON ──────────────────────────────
PAYLOAD=$(cat <<EOF
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "summary": "QA Test Results - ${TYPE_UPPER}",
  "themeColor": "${COLOR}",
  "title": "${ICON} ${TYPE_UPPER} Tests - ${DISPLAY_STATUS}",
  "sections": [{
    "activityTitle": "Test Execution Summary",
    "activitySubtitle": "${PIPELINE_NAME}",
    "facts": [
      {"name": "🧪 Test Type",  "value": "${TYPE_UPPER}"},
      {"name": "📂 Test Path",  "value": "${TEST_PATH}"},
      {"name": "✅ Passed",     "value": "${PASSED}"},
      {"name": "❌ Failed",     "value": "${FAILED}"},
      {"name": "⏭️ Skipped",    "value": "${SKIPPED}"},
      {"name": "🔄 Flaky",      "value": "${FLAKY}"},
      {"name": "⏱️ Duration",   "value": "${DURATION}"},
      {"name": "🌿 Branch",     "value": "${BRANCH}"},
      {"name": "👤 Triggered",  "value": "${TRIGGERED_BY}"},
      {"name": "🔢 Build",      "value": "${BUILD_NUMBER}"},
      {"name": "🌍 Env",        "value": "${ENV_NAME}"}
    ]
  }],
  "potentialAction": [
    {
      "@type": "OpenUri",
      "name": "📋 View Pipeline",
      "targets": [{"os": "default", "uri": "${PIPELINE_URL}"}]
    },
    {
      "@type": "OpenUri",
      "name": "📊 View Test Report",
      "targets": [{"os": "default", "uri": "${REPORT_URL}"}]
    }
  ]
}
EOF
)

# ── send notification ─────────────────────────────────────────
curl -sf -H "Content-Type: application/json" \
  --retry 3 --retry-delay 2 --max-time 30 \
  -d "$PAYLOAD" "$WEBHOOK_URL" \
  && echo "Teams notification sent" \
  || echo "WARN: Failed to send Teams notification (non-fatal)"
