# template-playwright-automation-pipeline

Central CI/CD pipeline templates for Playwright automation — supports both **Azure DevOps** and **GitLab CI**.

## Structure

```
stages/                        # Azure DevOps stage templates
├── dry-run.yml                # Validate files on non-main branches
├── build-dependencies.yml     # Install & cache node_modules + browsers (main only)
├── run-tests.yml              # Execute tests & publish results
└── notify.yml                 # Send results to Microsoft Teams

gitlab-stages/                 # GitLab CI job templates (include: remote:)
├── dry-run.yml                # Hidden job .dry_run
├── build-dependencies.yml     # Hidden job .build_dependencies
├── run-tests.yml              # Hidden job .run_tests  (exports test-results.env)
└── notify.yml                 # Hidden job .notify_teams

scripts/                       # Shared shell scripts (used by GitLab CI at runtime)
├── validate-project.sh        # File check, npm ci, tsc, playwright --list
├── generate-env.sh            # Generate .env file from CI secret variables
├── run-tests.sh               # Run playwright, parse results → test-results.env
└── notify-teams.sh            # Send MessageCard to Teams webhook

azure-pipelines-example.yml    # Full Azure DevOps consumer example
gitlab-ci-example.yml          # Full GitLab CI consumer example
gitlab-playground.gitlab-ci.yml  # Ready-to-use .gitlab-ci.yml for playground repo
```

## Usage

### 1. Create GitHub Service Connection in Azure DevOps

**Project Settings → Service Connections → New → GitHub**

- Connection name: `github-playwright-templates`
- Auth: GitHub App (recommended) or OAuth

### 2. Reference in your `azure-pipelines.yml`

```yaml
resources:
  repositories:
    - repository: templates
      type: github
      name: TantikornDev/template-playwright-automation-pipeline
      endpoint: github-playwright-templates
      ref: refs/tags/v1.0.0   # pin to a version tag

stages:
  - template: stages/dry-run.yml@templates
    parameters:
      TEST_TYPE: ${{ parameters.TEST_TYPE }}

  - template: stages/build-dependencies.yml@templates
    parameters:
      TEST_TYPE: ${{ parameters.TEST_TYPE }}

  - template: stages/run-tests.yml@templates
    parameters:
      TEST_TYPE: ${{ parameters.TEST_TYPE }}
      TEST_ENV: ${{ parameters.TEST_ENV }}
      TEST_PATH: ${{ parameters.TEST_PATH }}
      TEST_TAG: ${{ parameters.TEST_TAG }}
      EXTRA_ENV: ${{ parameters.EXTRA_ENV }}

  - template: stages/notify.yml@templates
    parameters:
      TEST_TYPE: ${{ parameters.TEST_TYPE }}
      WEBHOOK_URL_VAR: "TEAMS_WEBHOOK_URL_WMSH"   # secret name in Variable Group
```

See `azure-pipelines-example.yml` for a full working example.

---

## GitLab CI Usage

### 1. Set CI/CD Secret Variables

Go to **GitLab project → Settings → CI/CD → Variables** and add:

```
TEAMS_WEBHOOK_URL   (masked)
BASE_URL, AUTH_API_URL, ORG_CODE
API_USERNAME, API_PASSWORD, ...   (see gitlab-ci-example.yml for full list)
```

### 2. Copy `gitlab-ci-example.yml` to your project as `.gitlab-ci.yml`

The file uses `include: remote:` to pull templates from this GitHub repo at pipeline runtime.

```yaml
include:
  - remote: "https://raw.githubusercontent.com/TantikornDev/template-playwright-automation-pipeline/main/gitlab-stages/dry-run.yml"
  - remote: "https://raw.githubusercontent.com/TantikornDev/template-playwright-automation-pipeline/main/gitlab-stages/build-dependencies.yml"
  - remote: "https://raw.githubusercontent.com/TantikornDev/template-playwright-automation-pipeline/main/gitlab-stages/run-tests.yml"
  - remote: "https://raw.githubusercontent.com/TantikornDev/template-playwright-automation-pipeline/main/gitlab-stages/notify.yml"

stages: [validate, build, test, notify]

run_tests:
  extends: .run_tests
  variables:
    TEST_TYPE: "web"
    TEST_ENV: "DEV"

notify:
  extends: .notify_teams
  dependencies: [run_tests]
  variables:
    TEAMS_WEBHOOK_URL: $TEAMS_WEBHOOK_URL
```

### How variables flow between GitLab CI jobs

```
run_tests job
  └── writes test-results.env  (PASSED, FAILED, SKIPPED, FLAKY, DURATION, ENV, ...)
        └── artifacts.reports.dotenv → exports to downstream jobs

notify job
  └── dependencies: [run_tests]  ← downloads test-results.env artifact
        └── reads PASSED, FAILED, etc. directly as env vars
```

---

## Template Parameters

### `dry-run.yml` / `build-dependencies.yml` / `run-tests.yml`

| Parameter   | Type   | Default              | Description                      |
|-------------|--------|----------------------|----------------------------------|
| `TEST_TYPE` | string | (required)           | `web` or `api`                   |
| `WEB_DIR`   | string | `tests/web-testing`  | Relative path to web test folder |
| `API_DIR`   | string | `tests/api-testing`  | Relative path to API test folder |

### `run-tests.yml` (additional)

| Parameter   | Type   | Default    | Description                              |
|-------------|--------|------------|------------------------------------------|
| `TEST_ENV`  | string | (required) | Environment: DEV, SIT, UAT               |
| `TEST_PATH` | string | `" "`      | Specific test file/folder (optional)     |
| `TEST_TAG`  | string | `" "`      | Grep tag e.g. `@smoke` (optional)        |
| `EXTRA_ENV` | string | `" "`      | Extra env overrides e.g. `PARALLEL=true` |

### `notify.yml`

| Parameter         | Type   | Default             | Description                       |
|-------------------|--------|---------------------|-----------------------------------|
| `TEST_TYPE`       | string | (required)          | `web` or `api`                    |
| `WEBHOOK_URL_VAR` | string | `TEAMS_WEBHOOK_URL` | Name of the Variable Group secret |

## Required Variable Group Secrets

Your Azure DevOps Variable Group must include:

```
# Common
BASE_URL, AUTH_API_URL, ORG_CODE

# API tests
DEFAULT_SITE_ID, DEFAULT_CONNECTION_ID
API_USERNAME, API_PASSWORD
USERNAME_IVR, PASSWORD_IVR

# Web tests
WEB_USERNAME, WEB_PASSWORD

# Database
DB_HOST, DB_PORT, DB_SERVICE_NAME, DB_USER, DB_PASSWORD

# Teams notification
TEAMS_WEBHOOK_URL   (or custom name via WEBHOOK_URL_VAR parameter)
```

## Versioning

```bash
# After making changes, create a new tag
git tag v1.1.0
git push origin v1.1.0
```

Each consuming project controls which version it uses via `ref: refs/tags/vX.Y.Z`.
