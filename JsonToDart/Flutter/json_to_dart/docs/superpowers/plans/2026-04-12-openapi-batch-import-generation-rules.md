# OpenAPI Batch Import Generation Rules Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a developer-facing Chinese document in `docs/` that accurately describes the current OpenAPI batch import / batch generation rules, hidden behaviors, skip conditions, export structure, and known limitations based on the existing implementation.

**Architecture:** This is a documentation-only change. Read the existing implementation files that participate in OpenAPI batch import, extract the real rule chain from parsing through export, then write a single Markdown document organized by execution flow plus summary tables. Verify the document against the code paths it cites and ensure it clearly separates current behavior from issues and future improvement points.

**Tech Stack:** Flutter/Dart codebase, Markdown documentation, existing OpenAPI batch import implementation

---

## File Structure

### Files to read
- `lib/pages/openapi_import_page.dart`
  - UI entry, batch generation entrypoints, copy/download behavior, summary and preview behavior.
- `lib/utils/batch_api_generator.dart`
  - Core batch generation rules for request/response model generation and API method generation.
- `lib/utils/openapi_parser.dart`
  - OpenAPI parsing, endpoint extraction, schema-to-json conversion, request/response resolution.
- `lib/models/openapi_document.dart`
  - Document model, request/response schema accessors, endpoint-derived naming and parameter rules.
- `lib/main_controller.dart`
  - Shared model-generation pipeline reused by batch generation.
- `lib/utils/batch_file_download_stub.dart`
  - Desktop export directory behavior.
- `lib/utils/batch_file_download_web.dart`
  - Web export fallback behavior.
- `lib/models/api_config.dart`
  - Naming and file naming rules used by single API generation for comparison if needed.
- `docs/superpowers/specs/2026-04-12-openapi-batch-import-generation-rules-design.md`
  - Approved design/spec for the target documentation structure.
- `docs/superpowers/plans/2026-04-11-openapi-inline-schema-model-generation.md`
  - Existing implementation plan for nearby behavior and terminology cross-checking.

### Files to create
- `docs/openapi_batch_import_generation_rules.md`
  - Final developer-facing Chinese documentation.

### Files to modify
- None expected beyond creating the final docs file.

---

### Task 1: Extract current implementation rules from parsing to export

**Files:**
- Read: `lib/pages/openapi_import_page.dart`
- Read: `lib/utils/batch_api_generator.dart`
- Read: `lib/utils/openapi_parser.dart`
- Read: `lib/models/openapi_document.dart`
- Read: `lib/main_controller.dart`
- Read: `lib/utils/batch_file_download_stub.dart`
- Read: `lib/utils/batch_file_download_web.dart`
- Read: `docs/superpowers/specs/2026-04-12-openapi-batch-import-generation-rules-design.md`

- [ ] **Step 1: Read the approved spec and map required sections to code files**

Capture this mapping while reading:

```text
总体流程 -> openapi_import_page.dart + batch_api_generator.dart
endpoint 提取规则 -> openapi_parser.dart + openapi_document.dart
请求/响应 model 规则 -> batch_api_generator.dart + openapi_parser.dart + main_controller.dart
API 方法规则 -> batch_api_generator.dart
导出规则 -> openapi_import_page.dart + batch_file_download_*.dart
已知限制 -> cross-file synthesis from all above
```

- [ ] **Step 2: Read endpoint extraction and naming logic**

Focus on these code areas and record the actual rules they implement:

```text
lib/utils/openapi_parser.dart
- parseEndpoints()
- resolveRequestSchemaToJsonForEndpoint()
- resolveResponseSchemaToJsonForEndpoint()
- extractDataTypeFromResponse()

lib/models/openapi_document.dart
- RequestBody.schemaRef / schema
- ApiResponse.schemaRef / schema / example
- ParsedApiEndpoint.methodName
- ParsedApiEndpoint.classNamePrefix
- ParsedApiEndpoint.useSprintfUrl
- ParsedApiEndpoint.requestParameterCount
```

- [ ] **Step 3: Read batch generation and model reuse logic**

Focus on these code areas and record the actual rules they implement:

```text
lib/utils/batch_api_generator.dart
- generateAll()
- _generateRequestModel()
- _generateResponseModel()
- _usesRequestModel()
- _usesInlineParameters()
- _generateApiMethod()
- _generateGetMethod()
- _generatePostMethod()
- _generatePutMethod()
- _generateDeleteMethod()

lib/main_controller.dart
- generateModelCodeAsync()
- _generateModelCode()
- _removeValidErrorsFromJson()
- _renameNestedClasses()
- _generateModelCodeWithoutHelpers()
```

- [ ] **Step 4: Read export behavior and output assembly logic**

Focus on these code areas and record the actual rules they implement:

```text
lib/pages/openapi_import_page.dart
- _generateAndCopyAll()
- _generateAndDownloadAll()
- _showGeneratedCodePreview()
- _downloadSeparateFiles()
- _buildGeneratedSummary()
- _buildExportRootName()

lib/utils/batch_file_download_stub.dart
- downloadBatchFiles()

lib/utils/batch_file_download_web.dart
- downloadBatchFiles()
```

- [ ] **Step 5: Write a scratch outline for the final doc**

Use this exact outline as the document skeleton:

```markdown
# OpenAPI 批量导入生成规则

## 1. 文档目的与适用范围
## 2. 相关代码入口
## 3. 生成链路总览
## 4. 批量导入总体流程
## 5. Endpoint 提取规则
## 6. 请求 Model 生成规则
## 7. 响应 Model 生成规则
## 8. API 方法生成规则
## 9. Model 共用生成规则
## 10. 导出与下载规则
## 11. 跳过规则、隐含规则与已知问题
## 12. 建议校验清单
## 13. 附录：规则总表
```

- [ ] **Step 6: Verify coverage before writing**

Check that each spec requirement from `docs/superpowers/specs/2026-04-12-openapi-batch-import-generation-rules-design.md` maps to at least one of the sections above. Expected result: no unmapped requirement remains.

---

### Task 2: Write the final Chinese documentation in `docs/`

**Files:**
- Create: `docs/openapi_batch_import_generation_rules.md`
- Read: `lib/pages/openapi_import_page.dart`
- Read: `lib/utils/batch_api_generator.dart`
- Read: `lib/utils/openapi_parser.dart`
- Read: `lib/models/openapi_document.dart`
- Read: `lib/main_controller.dart`
- Read: `lib/utils/batch_file_download_stub.dart`
- Read: `lib/utils/batch_file_download_web.dart`

- [ ] **Step 1: Write the document header and code entry overview**

Start the file with this exact structure, replacing the placeholder bullets with implementation-derived content:

```markdown
# OpenAPI 批量导入生成规则

## 1. 文档目的与适用范围

本文用于整理当前仓库中 OpenAPI 批量导入 / 批量生成逻辑的真实实现规则，方便开发者对照代码逐项校验与后续完善。

本文只描述“当前代码实际上怎么做”，不描述理想方案，也不是用户操作手册。

## 2. 相关代码入口

- `lib/pages/openapi_import_page.dart`
- `lib/utils/batch_api_generator.dart`
- `lib/utils/openapi_parser.dart`
- `lib/models/openapi_document.dart`
- `lib/main_controller.dart`
- `lib/utils/batch_file_download_stub.dart`
- `lib/utils/batch_file_download_web.dart`

## 3. 生成链路总览

1. 导入 OpenAPI JSON
2. 解析 OpenAPI 文档
3. 提取 endpoint 列表
4. 按勾选结果批量生成请求/响应 Model 与 API 方法
5. 复制整合代码或导出分目录文件
```

- [ ] **Step 2: Write the execution-flow sections with code references**

For sections 4 through 10, write each rule as:

```markdown
- 规则说明
- 对应代码位置
- 该规则的直接结果
```

Use code locations in `file_path:line_number` format, for example:

```markdown
- `OpenApiParser.parseEndpoints()` 会遍历 `document.paths` 下每个 path，再遍历 `PathItem.operations` 中的 get/post/put/delete 操作，生成 `ParsedApiEndpoint` 列表。对应代码见 `lib/utils/openapi_parser.dart:11`、`lib/models/openapi_document.dart:75`。
```

- [ ] **Step 3: Write the skip-rules and known-issues section with explicit labels**

Use this subsection structure exactly:

```markdown
## 11. 跳过规则、隐含规则与已知问题

### 11.1 明确的跳过规则
### 11.2 隐含规则
### 11.3 当前已知限制 / 待完善点
```

Make sure the content explicitly includes:

```text
- 未选中的 endpoint 会被直接跳过
- requestSchemaRef 不存在且 query 参数少于 3 个时，不会生成请求 Model，而是可能直接展开参数
- path 参数存在时优先走 sprintf URL 分支
- 只识别 application/json
- 只识别 200 响应
- hasResponse 依赖 example.data 的特殊值判断
- path 参数生成代码当前固定为 id
- Web 端 downloadBatchFiles() 当前直接返回 null
```

- [ ] **Step 4: Write the validation checklist section**

Add a developer checklist section using this exact template and fill the unchecked items as Markdown checkboxes:

```markdown
## 12. 建议校验清单

- [ ] 是否需要支持除 `200` 之外的成功响应码
- [ ] 是否需要支持除 `application/json` 之外的 content type
- [ ] path 参数是否需要支持多个参数而不是固定 `id`
- [ ] `hasResponse` 是否应该脱离 `example.data` 特判
- [ ] 请求参数少于 3 个时是否仍应允许生成请求 Model
- [ ] 响应模型是否应优先保留完整包裹结构而不是只抽取 `data`
- [ ] Web 端是否需要真正支持分目录导出
```

- [ ] **Step 5: Write the summary tables appendix**

Create these four tables:

```markdown
### 13.1 命名规则总表
### 13.2 请求/响应生成判定总表
### 13.3 导出产物总表
### 13.4 跳过生成总表
```

Each table must include these columns:

```text
| 项目 | 当前规则 | 代码位置 | 备注 |
```

- [ ] **Step 6: Save the completed file**

Write the final content to:

```text
docs/openapi_batch_import_generation_rules.md
```

Expected result: one complete Chinese Markdown document with all required sections and code-location references.

---

### Task 3: Self-review the document against the code and fix any inaccuracies

**Files:**
- Modify: `docs/openapi_batch_import_generation_rules.md`
- Read: `docs/openapi_batch_import_generation_rules.md`
- Read: `lib/pages/openapi_import_page.dart`
- Read: `lib/utils/batch_api_generator.dart`
- Read: `lib/utils/openapi_parser.dart`
- Read: `lib/models/openapi_document.dart`
- Read: `lib/main_controller.dart`
- Read: `lib/utils/batch_file_download_stub.dart`
- Read: `lib/utils/batch_file_download_web.dart`

- [ ] **Step 1: Verify every major section has at least one concrete code location**

Check sections 4 through 11 and make sure each section cites at least one `file_path:line_number` location. Expected result: no descriptive section is missing a code reference.

- [ ] **Step 2: Verify the document never claims unsupported behavior**

Search manually for statements that imply any of the following unsupported behaviors and correct them if present:

```text
- 支持所有响应码
- 支持所有 content type
- Web 已支持分目录导出
- path 参数会自动生成完整参数列表
- 所有 query 参数都会生成 Req Model
```

Expected result: the document describes only currently implemented behavior.

- [ ] **Step 3: Verify the line-number references are still accurate enough to navigate**

Re-open the referenced files and ensure each citation still points to the correct nearby function or getter. If any citation is off, update it in the Markdown file.

- [ ] **Step 4: Verify the distinction between fact and judgment is explicit**

Make sure “当前规则” and “待完善点/限制” are not mixed together in the same bullet without labeling. If mixed, split them into separate bullets.

- [ ] **Step 5: Verify the appendix tables summarize, not contradict, the正文**

Check each appendix row against the earlier sections. Expected result: no table row introduces a new rule that was never explained above.

- [ ] **Step 6: Save final edits**

Expected result: `docs/openapi_batch_import_generation_rules.md` is internally consistent and ready for developer use.

---

### Task 4: Perform completion verification

**Files:**
- Read: `docs/openapi_batch_import_generation_rules.md`
- Read: `docs/superpowers/specs/2026-04-12-openapi-batch-import-generation-rules-design.md`

- [ ] **Step 1: Check section coverage against the approved spec**

Confirm the final doc covers all items from the spec:

```text
- 主链路
- endpoint 提取规则
- 请求 Model 生成规则
- 响应 Model 生成规则
- API 方法规则
- Model 共用规则
- 导出规则
- 跳过规则
- 已知问题
- 校验清单
- 汇总附录
```

Expected result: all are present.

- [ ] **Step 2: Verify the final file is in the requested docs directory**

Expected path:

```text
docs/openapi_batch_import_generation_rules.md
```

- [ ] **Step 3: Verify the document is fully Chinese except code/file identifiers**

Expected result: prose is Chinese, while code symbols and file paths remain as-is.

- [ ] **Step 4: Verify the document is useful for future code improvement**

Check that the file contains both:

```text
- 当前规则说明
- 待完善/建议校验项
```

Expected result: the document supports both current-state understanding and future refinement.
