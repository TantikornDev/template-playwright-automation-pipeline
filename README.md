# template-playwright-automation-pipeline

Central Azure DevOps pipeline templates for Playwright automation projects.

## Structure

```
stages/
├── dry-run.yml            # Validate files on non-main branches
├── build-dependencies.yml # Install & cache node_modules + browsers (main only)
├── run-tests.yml          # Execute tests & publish results
└── notify.yml             # Send results to Microsoft Teams
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
