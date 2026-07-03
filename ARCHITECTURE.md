# Pipeline Architecture

## Overview

Pipeline ถูกออกแบบเป็น **Template-based Architecture** โดยแยกแต่ละ stage เป็นไฟล์ YAML แยก เพื่อให้ง่ายต่อการ maintain, reuse, และ review

**แนวคิดหลัก:** แยก 1 stage = 1 file — `azure-pipelines.yml` ทำหน้าที่เป็น orchestrator เท่านั้น template จริงอยู่ใน GitHub repo กลาง

---

## Structure

```
# GitHub: TantikornDev/template-playwright-automation-pipeline
stages/
├── dry-run.yml              ← Stage 1: Validate project files (non-main)
├── build-dependencies.yml   ← Stage 2: Install & cache dependencies (main)
├── run-tests.yml            ← Stage 3: Execute Playwright tests (main)
└── notify.yml               ← Stage 4: Send Teams notification (always)

# Project repo (e.g. AXONS Sustain)
azure-pipelines.yml          ← Orchestrator — ดึง templates จาก GitHub ข้างบน
```

---

## Pipeline Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    azure-pipelines.yml                       │
│                     (Orchestrator)                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌──────────────────┐    ┌───────────┐  │
│  │  Dry Run    │───▶│  Build Deps      │───▶│ Run Tests │  │
│  │ (non-main)  │    │ (main only)      │    │           │  │
│  └─────────────┘    └──────────────────┘    └─────┬─────┘  │
│                                                   │         │
│                                              ┌────▼────┐    │
│                                              │ Notify  │    │
│                                              │ (Teams) │    │
│                                              └─────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Flow ตาม Branch

```
non-main:  Dry_Run → (skip Build) → (skip Run_Tests) → Notify
main:      (skip Dry_Run) → Build_Dependencies → Run_Tests → Notify
```

---

## Stage Details

### 1. Dry Run (`stages/dry-run.yml`)

| Item | Detail |
|------|--------|
| **Condition** | ทำงานเฉพาะ branch ที่ไม่ใช่ `main` |
| **Pool** | `ubuntu-latest` |
| **Purpose** | ตรวจสอบว่าไฟล์ครบถ้วนก่อน merge |

**ขั้นตอน:**
1. ตรวจสอบ `package.json`, `package-lock.json`, `playwright.config.ts`
2. ติดตั้ง dependencies (`npm ci`)
3. TypeScript compile check (`tsc --noEmit`)
4. Validate test files (`playwright test --list`)

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `TEST_TYPE` | string | `api` หรือ `web` |
| `WEB_DIR` | string | path ของ web tests (default: `tests/web-testing`) |
| `API_DIR` | string | path ของ api tests (default: `tests/api-testing`) |

---

### 2. Build Dependencies (`stages/build-dependencies.yml`)

| Item | Detail |
|------|--------|
| **Condition** | ทำงานเฉพาะ branch `main` |
| **Pool** | `ubuntu-latest` |
| **Purpose** | ติดตั้ง dependencies และ cache เป็น artifacts |

**ขั้นตอน:**
1. Cache npm packages
2. ติดตั้ง dependencies (`npm ci`)
3. Download Playwright browsers (เฉพาะ web testing)
4. บีบอัดและ publish artifacts

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `TEST_TYPE` | string | `api` หรือ `web` |
| `WEB_DIR` | string | path ของ web tests (default: `tests/web-testing`) |
| `API_DIR` | string | path ของ api tests (default: `tests/api-testing`) |

**Artifacts ที่สร้าง:**
- `node_modules-compressed` → `node_modules.tar.gz`
- `playwright-browsers` → `playwright-browsers.tar.gz` (เฉพาะ web)

---

### 3. Run Tests (`stages/run-tests.yml`)

| Item | Detail |
|------|--------|
| **Condition** | ทำงานหลัง Build_Dependencies สำเร็จ (main เท่านั้น) |
| **Pool** | `ubuntu-latest` |
| **Purpose** | รัน Playwright tests และ publish results |

**ขั้นตอน:**
1. ติดตั้ง dependencies และ browsers
2. Generate `.env` file ตาม environment
3. รัน Playwright tests ด้วย options ที่กำหนด
4. Parse test results (passed, failed, skipped, flaky, duration)
5. Publish JUnit results และ HTML report

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `TEST_TYPE` | string | (required) | `api` หรือ `web` |
| `TEST_ENV` | string | (required) | `DEV`, `SIT`, `UAT` |
| `TEST_PATH` | string | `" "` | path เฉพาะที่ต้องการรัน |
| `TEST_TAG` | string | `" "` | tag filter เช่น `@smoke` |
| `EXTRA_ENV` | string | `" "` | override env เช่น `PARALLEL=true` |
| `WEB_DIR` | string | `tests/web-testing` | path ของ web tests |
| `API_DIR` | string | `tests/api-testing` | path ของ api tests |

**Output Variables (ส่งต่อไปยัง Notify stage):**

| Variable | Description |
|----------|-------------|
| `runTests.ENV` | environment ที่รัน |
| `runTests.TEST_TYPE` | ประเภท test |
| `runTests.PASSED` | จำนวน test ที่ผ่าน |
| `runTests.FAILED` | จำนวน test ที่ fail |
| `runTests.SKIPPED` | จำนวน test ที่ skip |
| `runTests.FLAKY` | จำนวน test ที่ flaky |
| `runTests.DURATION` | ระยะเวลารัน |

---

### 4. Notify (`stages/notify.yml`)

| Item | Detail |
|------|--------|
| **Condition** | ทำงานเสมอ `always()` |
| **Pool** | `ubuntu-latest` |
| **Purpose** | ส่ง notification ผ่าน Microsoft Teams |

**ขั้นตอน:**
1. อ่าน output variables จาก Run_Tests stage
2. กำหนดสี/icon ตามผลลัพธ์ (✅ green / ❌ red / ⚠️ yellow)
3. ส่ง MessageCard ไปยัง Teams webhook

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `TEST_TYPE` | string | (required) | `api` หรือ `web` |
| `WEBHOOK_URL_VAR` | string | `TEAMS_WEBHOOK_URL` | ชื่อ secret variable ใน Variable Group |

---

## Triggers

| Trigger | เงื่อนไข |
|---------|----------|
| **CI** | Push ไปที่ `main`, `release/*`, `feature/*` |
| **PR** | PR ไปที่ `main` (เฉพาะเมื่อ `tests/**` หรือ `azure-pipelines.yml` เปลี่ยน) |
| **Schedule** | ทุกวันจันทร์-ศุกร์ เวลา 10:00 ICT (03:00 UTC) |

## Parameters (Manual Run)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `TEST_TYPE` | `web` | เลือก `api` หรือ `web` |
| `TEST_ENV` | `DEV` | เลือก `DEV`, `SIT`, `UAT` |
| `TEST_PATH` | (all) | ระบุ path เฉพาะ เช่น `feature-1/` |
| `TEST_TAG` | (all) | ระบุ tag เช่น `@smoke`, `@regression` |
| `EXTRA_ENV` | (none) | Override env เช่น `PARALLEL=true` |

---

## How to Add a New Stage

1. สร้างไฟล์ใหม่ใน `stages/` ของ template repo เช่น `my-stage.yml`
2. กำหนด `parameters` และ `stages` ตาม format:

```yaml
parameters:
  - name: MY_PARAM
    type: string

stages:
  - stage: My_Stage
    displayName: "My New Stage"
    pool:
      vmImage: "ubuntu-latest"
    jobs:
      - job: MyJob
        steps:
          - script: echo "Hello ${{ parameters.MY_PARAM }}"
```

3. เพิ่ม reference ใน `azure-pipelines.yml` ของ project:

```yaml
stages:
  - template: stages/my-stage.yml@templates
    parameters:
      MY_PARAM: ${{ parameters.TEST_TYPE }}
```

4. Tag version ใหม่บน template repo:

```bash
git tag v1.1.0
git push origin v1.1.0
```

---

## Pros & Cons

### Pros ✅

| ด้าน | รายละเอียด |
|------|-------------|
| **Maintainability** | แก้ไข stage เดียวไม่กระทบ stage อื่น ลด merge conflict |
| **Reusability** | นำ template ไปใช้ข้าม pipeline/project ได้ทันที |
| **Readability** | Main file สั้น เห็น flow ภาพรวมชัดใน ~20 บรรทัด |
| **Testability** | ทดสอบ/debug แต่ละ stage แยกได้ง่าย |
| **Scalability** | เพิ่ม stage ใหม่แค่สร้างไฟล์ + เพิ่ม 3 บรรทัดใน main |
| **Centralized** | Template กลางบน GitHub — ทุก project ได้รับ update พร้อมกัน |

### Cons ❌

| ด้าน | รายละเอียด |
|------|-------------|
| **Debugging ยากขึ้น** | Error อาจต้องกระโดดดูหลายไฟล์/หลาย repo |
| **Compile-time only** | Template expressions ใช้ได้แค่ `${{ }}` ไม่สามารถใช้ runtime variables ใน template logic |
| **Version management** | ต้อง tag และ bump version ทุกครั้งที่แก้ template |
| **Overhead สำหรับ project เล็ก** | ถ้า pipeline มี 2-3 steps แยกไฟล์อาจ overkill |
| **Variable passing ซับซ้อน** | Output variables ข้าม stage ต้องใช้ syntax ยาว `stageDependencies.X.Y.outputs['z.VAR']` |
| **ไม่มี IDE validation** | ไม่มี tool validate template references ตอน develop — รู้ error ตอน run เท่านั้น |

---

## เมื่อไหร่ควรใช้ Template-based

| ใช้ | ไม่ใช้ |
|-----|--------|
| Pipeline มี ≥ 3 stages | Pipeline มี ≤ 2 stages เรียบง่าย |
| ต้องการ reuse ข้าม pipelines/projects | Pipeline ใช้ครั้งเดียว |
| ทีมมีหลายคนแก้ pipeline | คนเดียวดูแล |
| Multi-environment / multi-project | Single environment |

---

## Notes

- แต่ละ stage template กำหนด `pool` เอง — ไม่มี root-level pool
- ใช้ `${{ }}` สำหรับ compile-time expressions (parameters)
- ใช้ `$[ ]` สำหรับ runtime expressions (stage dependencies)
- Template repo ต้องสร้าง Service Connection บน Azure DevOps (`resources.repositories`)
- แนะนำ pin version ด้วย `ref: refs/tags/vX.Y.Z` แทน `refs/heads/main` เพื่อ stability
