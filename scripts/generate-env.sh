#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# generate-env.sh
# Generate .env file for Playwright tests from CI secret variables
#
# Required env vars:
#   TEST_TYPE  : 'web' | 'api'
#   TEST_ENV   : 'DEV' | 'SIT' | 'UAT'
#   WEB_DIR    : path to web test folder  (e.g. tests/web-testing)
#   API_DIR    : path to api test folder  (e.g. tests/api-testing)
#
# Secret env vars (inject from CI Variable Group / GitLab CI Variables):
#   BASE_URL, AUTH_API_URL, ORG_CODE
#   DEFAULT_SITE_ID, DEFAULT_CONNECTION_ID
#   API_USERNAME, API_PASSWORD, USERNAME_IVR, PASSWORD_IVR
#   WEB_USERNAME, WEB_PASSWORD
#   DB_HOST, DB_PORT, DB_SERVICE_NAME, DB_USER, DB_PASSWORD
# ─────────────────────────────────────────────────────────────
set -euo pipefail

: "${TEST_TYPE:?TEST_TYPE is required (web|api)}"
: "${TEST_ENV:?TEST_ENV is required (DEV|SIT|UAT)}"
: "${WEB_DIR:?WEB_DIR is required}"
: "${API_DIR:?API_DIR is required}"

ENV_UPPER=$(echo "$TEST_ENV" | tr '[:lower:]' '[:upper:]')
ENV_LOWER=$(echo "$TEST_ENV" | tr '[:upper:]' '[:lower:]')

# Determine output .env file path
if [ "$TEST_TYPE" = "web" ]; then
  # web: .env (SIT default) or .env.dev / .env.uat
  SUFFIX=""
  [ "$ENV_LOWER" != "sit" ] && SUFFIX=".$ENV_LOWER"
  ENV_FILE="${WEB_DIR}/.env${SUFFIX}"
else
  ENV_FILE="${API_DIR}/.env.$ENV_LOWER"
fi

echo "Generating: $ENV_FILE (TEST_TYPE=$TEST_TYPE ENV=$ENV_UPPER)"

if [ "$TEST_TYPE" = "api" ]; then
cat > "$ENV_FILE" <<EOF
ENV=${ENV_UPPER}
BASE_URL=${BASE_URL}
AUTH_API_URL=${AUTH_API_URL}
ORG_CODE=${ORG_CODE}
DEFAULT_SITE_ID=${DEFAULT_SITE_ID}
DEFAULT_CONNECTION_ID=${DEFAULT_CONNECTION_ID}
USERNAME=${API_USERNAME}
PASSWORD=${API_PASSWORD}
USERNAME_IVR=${USERNAME_IVR}
PASSWORD_IVR=${PASSWORD_IVR}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_SERVICE_NAME=${DB_SERVICE_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
EOF
else
cat > "$ENV_FILE" <<EOF
ENV=${ENV_UPPER}
BASE_URL=${BASE_URL}
USERNAME=${WEB_USERNAME}
PASSWORD=${WEB_PASSWORD}
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_SERVICE_NAME=${DB_SERVICE_NAME}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
EOF
fi

# Remove any accidental leading whitespace
sed -i 's/^[[:space:]]*//' "$ENV_FILE"
echo "Generated: $ENV_FILE"
