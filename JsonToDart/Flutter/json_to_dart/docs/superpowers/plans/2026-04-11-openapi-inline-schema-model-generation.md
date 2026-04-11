# OpenAPI Inline Schema Model Generation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix OpenAPI batch import so inline request/response schemas generate Dart models correctly, and make downloads default to a clearer `req/`, `resp/`, and `api/` export structure that is easier to use directly.

**Architecture:** Extend the OpenAPI parsing layer so it can resolve either `$ref` schemas or inline `application/json.schema` objects into JSON examples for the existing `generateModelCodeAsync()` pipeline. Keep the current batch generator and download flow, but route model generation through a schema-source abstraction and improve the generated result summary so users can see what was exported and what was skipped.

**Tech Stack:** Flutter, Dart, GetX, file_picker, existing `json_to_dart_library` model generation pipeline

---

## File Structure

### Files to modify
- `lib/models/openapi_document.dart`
  - Add helpers for reading raw request/response schemas from `application/json`, not only `$ref`.
- `lib/utils/openapi_parser.dart`
  - Add schema resolution methods that support inline objects, arrays, nested properties, nullable/null fields, and existing `$ref` lookups.
- `lib/utils/batch_api_generator.dart`
  - Update request/response model generation to use raw schema data first, then `$ref` fallback, and record generation results for UI/export summaries.
- `lib/pages/openapi_import_page.dart`
  - Update download flow to prefer structured export, improve success messaging/preview, and expose which files were generated or skipped.
- `lib/utils/batch_file_download_stub.dart`
  - Keep desktop directory export as the primary structured export path and support an export root folder name.
- `lib/utils/batch_file_download_web.dart`
  - Keep browser fallback, but support clearer file naming/output metadata for manual organization.

### Files to create
- `test/utils/openapi_parser_test.dart`
  - Regression tests for resolving inline response/request schemas from a fixture matching the user’s `22.json` shape.
- `test/utils/batch_api_generator_test.dart`
  - Regression tests proving inline response models are included in `respFiles` and empty responses are skipped.
- `test/fixtures/openapi_inline_schema.json`
  - Minimal OpenAPI fixture with one inline response object, one inline array response, one empty response, and one query-only request.

---

### Task 1: Add parser regression coverage for inline schemas

**Files:**
- Create: `test/fixtures/openapi_inline_schema.json`
- Create: `test/utils/openapi_parser_test.dart`
- Modify: `pubspec.yaml` only if test dependency is missing (do not change if `flutter_test` already exists)

- [ ] **Step 1: Write the failing fixture**

Create `test/fixtures/openapi_inline_schema.json` with this exact content:

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "inline-schema-test",
    "version": "1.0.0"
  },
  "paths": {
    "/api/servicePlan/purchaseList": {
      "get": {
        "summary": "采购证列表",
        "parameters": [
          {
            "name": "type",
            "in": "query",
            "required": true,
            "schema": {
              "type": "string"
            }
          }
        ],
        "responses": {
          "200": {
            "description": "成功",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": { "type": "boolean" },
                    "code": { "type": "integer" },
                    "msg": { "type": "string" },
                    "data": {
                      "type": "object",
                      "properties": {
                        "data": {
                          "type": "array",
                          "items": {
                            "type": "object",
                            "properties": {
                              "id": { "type": "integer" },
                              "name": { "type": "string" }
                            }
                          }
                        },
                        "page": { "type": "integer" }
                      }
                    }
                  }
                },
                "example": {
                  "status": true,
                  "code": 200,
                  "msg": "操作成功",
                  "data": {
                    "data": [
                      {
                        "id": 1,
                        "name": "foo"
                      }
                    ],
                    "page": 1
                  }
                }
              }
            }
          }
        }
      }
    },
    "/api/servicePlan/getPurchase": {
      "get": {
        "summary": "可参与类型",
        "responses": {
          "200": {
            "description": "成功",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {
                    "status": { "type": "boolean" },
                    "data": {
                      "type": "array",
                      "items": {
                        "type": "object",
                        "properties": {
                          "type": { "type": "integer" },
                          "name": { "type": "string" }
                        }
                      }
                    }
                  }
                },
                "example": {
                  "status": true,
                  "data": [
                    {
                      "type": 1,
                      "name": "采购证"
                    }
                  ]
                }
              }
            }
          }
        }
      }
    },
    "/api/servicePlan/submit": {
      "post": {
        "summary": "确认页面提交",
        "responses": {
          "200": {
            "description": "成功",
            "content": {
              "application/json": {
                "schema": {
                  "type": "object",
                  "properties": {}
                }
              }
            }
          }
        }
      }
    }
  },
  "components": {
    "schemas": {}
  }
}
```

- [ ] **Step 2: Write the failing parser test**

Create `test/utils/openapi_parser_test.dart` with this exact content:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_to_dart/utils/openapi_parser.dart';

void main() {
  group('OpenApiParser inline schema support', () {
    late OpenApiParser parser;

    setUpAll(() async {
      final String jsonString =
          await File('test/fixtures/openapi_inline_schema.json').readAsString();
      parser = OpenApiParser.fromJson(jsonString);
    });

    test('resolves inline object response schema into json example', () {
      final Map<String, dynamic>? schemaJson =
          parser.resolveResponseSchemaToJson('/api/servicePlan/purchaseList', 'get');

      expect(schemaJson, isNotNull);
      expect(schemaJson!['status'], false);
      expect(schemaJson['code'], 0);
      expect(schemaJson['msg'], '');
      expect(schemaJson['data'], isA<Map<String, dynamic>>());
      expect(schemaJson['data']['data'], isA<List<dynamic>>());
      expect(schemaJson['data']['page'], 0);
    });

    test('resolves inline array response schema under data', () {
      final Map<String, dynamic>? schemaJson =
          parser.resolveResponseSchemaToJson('/api/servicePlan/getPurchase', 'get');

      expect(schemaJson, isNotNull);
      expect(schemaJson!['data'], isA<List<dynamic>>());
      expect(schemaJson['data'].first, isA<Map<String, dynamic>>());
      expect(schemaJson['data'].first['type'], 0);
      expect(schemaJson['data'].first['name'], '');
    });

    test('returns empty object for empty inline schema', () {
      final Map<String, dynamic>? schemaJson =
          parser.resolveResponseSchemaToJson('/api/servicePlan/submit', 'post');

      expect(schemaJson, isNotNull);
      expect(schemaJson, isEmpty);
    });
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/utils/openapi_parser_test.dart`

Expected: FAIL with undefined method or missing implementation for `resolveResponseSchemaToJson`, or with null results because inline schemas are not currently supported.

- [ ] **Step 4: Write minimal parser implementation**

Modify `lib/models/openapi_document.dart` to add raw schema accessors on request/response objects. Add this code inside `RequestBody` after `schemaRef`, and inside `ApiResponse` after `schemaRef`:

```dart
  Map<String, dynamic>? get schema {
    if (content == null) {
      return null;
    }
    final Map<String, dynamic>? applicationJson =
        content!['application/json'] as Map<String, dynamic>?;
    if (applicationJson == null) {
      return null;
    }
    return applicationJson['schema'] as Map<String, dynamic>?;
  }
```

Then modify `lib/utils/openapi_parser.dart` by adding these methods:

```dart
  Map<String, dynamic>? resolveRequestSchemaToJsonForEndpoint(
    ParsedApiEndpoint endpoint,
  ) {
    if (endpoint.requestSchemaRef != null) {
      return resolveSchemaToJson(endpoint.requestSchemaRef);
    }

    final Operation? operation = _findOperation(endpoint.path, endpoint.method);
    final Map<String, dynamic>? schema = operation?.requestBody?.schema;
    if (schema == null) {
      return null;
    }
    return schemaToJson(schema);
  }

  Map<String, dynamic>? resolveResponseSchemaToJson(
    String path,
    String method,
  ) {
    final Operation? operation = _findOperation(path, method);
    final ApiResponse? response = operation?.responses?['200'];
    final Map<String, dynamic>? schema = response?.schema;
    if (schema == null) {
      return null;
    }

    if (response?.schemaRef != null) {
      return resolveSchemaToJson(response!.schemaRef);
    }

    return schemaToJson(schema);
  }

  Map<String, dynamic>? resolveResponseSchemaToJsonForEndpoint(
    ParsedApiEndpoint endpoint,
  ) {
    if (endpoint.responseSchemaRef != null) {
      return resolveSchemaToJson(endpoint.responseSchemaRef);
    }
    return resolveResponseSchemaToJson(endpoint.path, endpoint.method);
  }

  Map<String, dynamic> schemaToJson(Map<String, dynamic> schema) {
    return _schemaToJson(schema);
  }

  Operation? _findOperation(String path, String method) {
    final PathItem? pathItem = document.paths[path];
    if (pathItem == null) {
      return null;
    }

    switch (method.toLowerCase()) {
      case 'get':
        return pathItem.get;
      case 'post':
        return pathItem.post;
      case 'put':
        return pathItem.put;
      case 'delete':
        return pathItem.delete;
      default:
        return null;
    }
  }
```

Also update `_generateExampleValue` in `lib/utils/openapi_parser.dart` so `null` and nullable unions do not collapse to `''`:

```dart
    final dynamic typeValue = schema['type'];
    final dynamic formatValue = schema['format'];

    if (typeValue is List<dynamic>) {
      final Iterable<String> types = typeValue.whereType<String>();
      if (types.contains('object')) {
        return _schemaToJson(<String, dynamic>{
          ...schema,
          'type': 'object',
        });
      }
      if (types.contains('array')) {
        return _generateExampleValue(<String, dynamic>{
          ...schema,
          'type': 'array',
        });
      }
      if (types.contains('string')) {
        return '';
      }
      if (types.contains('integer')) {
        return 0;
      }
      if (types.contains('number')) {
        return 0.0;
      }
      if (types.contains('boolean')) {
        return false;
      }
      if (types.contains('null')) {
        return null;
      }
    }

    if (typeValue == 'null') {
      return null;
    }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/utils/openapi_parser_test.dart`

Expected: PASS with 3 passing tests.

- [ ] **Step 6: Commit**

```bash
git add test/fixtures/openapi_inline_schema.json test/utils/openapi_parser_test.dart lib/models/openapi_document.dart lib/utils/openapi_parser.dart
git commit -m "fix: support inline OpenAPI schema parsing"
```

### Task 2: Add batch generator regression coverage for inline response models

**Files:**
- Create: `test/utils/batch_api_generator_test.dart`
- Modify: `lib/utils/batch_api_generator.dart`

- [ ] **Step 1: Write the failing generator test**

Create `test/utils/batch_api_generator_test.dart` with this exact content:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_to_dart/utils/batch_api_generator.dart';
import 'package:json_to_dart/utils/openapi_parser.dart';

void main() {
  group('BatchApiCodeGenerator inline response models', () {
    late OpenApiParser parser;
    late List<ParsedApiEndpoint> endpoints;

    setUpAll(() async {
      final String jsonString =
          await File('test/fixtures/openapi_inline_schema.json').readAsString();
      parser = OpenApiParser.fromJson(jsonString);
      endpoints = parser.parseEndpoints();
    });

    test('generates response files for inline response schemas', () async {
      final BatchApiCodeGenerator generator = BatchApiCodeGenerator(
        parser: parser,
        endpoints: endpoints,
        baseUrl: "'https://example.com'",
        apiClassName: 'InlineSchemaApi',
        modelGenerator: (String jsonString, String className) async {
          return 'class $className {}';
        },
      );

      final BatchApiCodeResult result = await generator.generateAll();

      expect(result.respFiles.keys, contains('api_service_plan_purchase_list_resp.dart'));
      expect(result.respFiles.keys, contains('api_service_plan_get_purchase_resp.dart'));
      expect(result.respFiles.keys, isNot(contains('api_service_plan_submit_resp.dart')));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/utils/batch_api_generator_test.dart`

Expected: FAIL because `result.respFiles` is currently empty for inline schemas.

- [ ] **Step 3: Write minimal batch generator implementation**

Modify `lib/utils/batch_api_generator.dart`.

First, update `BatchApiCodeResult` to carry skipped-file metadata:

```dart
  BatchApiCodeResult({
    required this.reqFiles,
    required this.respFiles,
    required this.apiFileContent,
    required this.apiFileName,
    required this.skippedReqModels,
    required this.skippedRespModels,
  });

  final List<String> skippedReqModels;
  final List<String> skippedRespModels;
```

Then initialize the new lists in `generateAll()`:

```dart
    final List<String> skippedReqModels = <String>[];
    final List<String> skippedRespModels = <String>[];
```

Update request model generation block in `generateAll()` to record skips and support inline request schemas:

```dart
      final String? reqModelCode = await _generateRequestModel(endpoint);
      if (reqModelCode != null) {
        final String fileName = _toSnakeCase(endpoint.classNamePrefix) + '_req.dart';
        reqFiles[fileName] = reqModelCode;
      } else if (endpoint.requestSchemaRef != null ||
          parser.resolveRequestSchemaToJsonForEndpoint(endpoint) != null) {
        skippedReqModels.add(endpoint.classNamePrefix);
      }
```

Update response model generation block in `generateAll()` similarly:

```dart
      if (endpoint.hasResponse) {
        final String? respModelCode = await _generateResponseModel(endpoint);
        if (respModelCode != null) {
          final String fileName = _toSnakeCase(endpoint.classNamePrefix) + '_resp.dart';
          respFiles[fileName] = respModelCode;
        } else if (endpoint.responseSchemaRef != null ||
            parser.resolveResponseSchemaToJsonForEndpoint(endpoint) != null) {
          skippedRespModels.add(endpoint.classNamePrefix);
        }
      }
```

Update `_generateRequestModel()`:

```dart
  Future<String?> _generateRequestModel(ParsedApiEndpoint endpoint) async {
    final Map<String, dynamic>? schemaJson =
        parser.resolveRequestSchemaToJsonForEndpoint(endpoint);
    if (schemaJson == null || schemaJson.isEmpty) {
      return null;
    }

    final String jsonString = _jsonToString(schemaJson);
    final String className = endpoint.classNamePrefix + 'Req';

    return await modelGenerator(jsonString, className) as String?;
  }
```

Update `_generateResponseModel()`:

```dart
  Future<String?> _generateResponseModel(ParsedApiEndpoint endpoint) async {
    final String? dataTypeRef =
        parser.extractDataTypeFromResponse(endpoint.responseSchemaRef);

    Map<String, dynamic>? schemaJson;
    if (dataTypeRef != null) {
      schemaJson = parser.resolveSchemaToJson(dataTypeRef);
    } else {
      schemaJson = parser.resolveResponseSchemaToJsonForEndpoint(endpoint);
    }

    if (schemaJson == null || schemaJson.isEmpty) {
      return null;
    }

    final String jsonString = _jsonToString(schemaJson);
    final String className = endpoint.classNamePrefix + 'Resp';

    return await modelGenerator(jsonString, className) as String?;
  }
```

Update the `return BatchApiCodeResult(...)` call:

```dart
    return BatchApiCodeResult(
      reqFiles: reqFiles,
      respFiles: respFiles,
      apiFileContent: apiContent.toString(),
      apiFileName: apiFileName,
      skippedReqModels: skippedReqModels,
      skippedRespModels: skippedRespModels,
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/utils/batch_api_generator_test.dart`

Expected: PASS with the two inline response files generated and the empty response skipped.

- [ ] **Step 5: Run the focused regression suite**

Run: `flutter test test/utils/openapi_parser_test.dart test/utils/batch_api_generator_test.dart`

Expected: PASS with all tests green.

- [ ] **Step 6: Commit**

```bash
git add test/utils/batch_api_generator_test.dart lib/utils/batch_api_generator.dart
git commit -m "fix: generate models from inline OpenAPI responses"
```

### Task 3: Improve structured export and preview messaging

**Files:**
- Modify: `lib/pages/openapi_import_page.dart`
- Modify: `lib/utils/batch_file_download_stub.dart`
- Modify: `lib/utils/batch_file_download_web.dart`

- [ ] **Step 1: Write the failing UI-facing expectation as a widget-adjacent regression note**

Because there is no existing widget test harness in this repo, add a focused pure-Dart helper path first by extracting preview/export summary builders from the widget into deterministic methods. Add these methods inside `_OpenApiImportPageState` in `lib/pages/openapi_import_page.dart`:

```dart
  String _buildGeneratedSummary(BatchApiCodeResult result) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('请求 Model: ${result.reqFiles.length} 个');
    buffer.writeln('响应 Model: ${result.respFiles.length} 个');
    buffer.writeln(
      'API 方法: ${_endpoints!.where((ParsedApiEndpoint e) => e.selected.value).length} 个',
    );
    if (result.skippedReqModels.isNotEmpty) {
      buffer.writeln('未生成请求 Model: ${result.skippedReqModels.join(', ')}');
    }
    if (result.skippedRespModels.isNotEmpty) {
      buffer.writeln('未生成响应 Model: ${result.skippedRespModels.join(', ')}');
    }
    return buffer.toString();
  }

  String _buildExportRootName() {
    final String sanitized =
        _apiClassNameInput.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return sanitized.isEmpty ? 'openapi_export' : sanitized;
  }
```

The failure here is compile-time until `BatchApiCodeResult` includes the skipped-model fields from Task 2.

- [ ] **Step 2: Run analyzer on the affected file to verify it fails before wiring everything**

Run: `flutter analyze lib/pages/openapi_import_page.dart lib/utils/batch_file_download_stub.dart lib/utils/batch_file_download_web.dart`

Expected: FAIL until the helper usage and new function signatures are fully wired.

- [ ] **Step 3: Write minimal export implementation**

Update `lib/utils/batch_file_download_stub.dart` function signature and root folder creation:

```dart
Future<String?> downloadBatchFiles({
  required Map<String, String> reqFiles,
  required Map<String, String> respFiles,
  required String apiFileContent,
  required String apiFileName,
  required String exportRootName,
}) async {
```

Replace the directory creation block with:

```dart
    final Directory rootDir = Directory('$outputDir/$exportRootName');
    final Directory reqDir = Directory('${rootDir.path}/req');
    final Directory respDir = Directory('${rootDir.path}/resp');
    final Directory apiDir = Directory('${rootDir.path}/api');

    await rootDir.create(recursive: true);
    await reqDir.create(recursive: true);
    await respDir.create(recursive: true);
    await apiDir.create(recursive: true);
```

Return `rootDir.path` instead of `outputDir`.

Update `lib/utils/batch_file_download_web.dart` signature to match:

```dart
Future<String?> downloadBatchFiles({
  required Map<String, String> reqFiles,
  required Map<String, String> respFiles,
  required String apiFileContent,
  required String apiFileName,
  required String exportRootName,
}) async {
  return null;
}
```

Update the call site in `lib/pages/openapi_import_page.dart` inside `_downloadSeparateFiles()`:

```dart
      final String? outputDir = await batch_download.downloadBatchFiles(
        reqFiles: result.reqFiles,
        respFiles: result.respFiles,
        apiFileContent: result.apiFileContent,
        apiFileName: result.apiFileName,
        exportRootName: _buildExportRootName(),
      );
```

Update the desktop success message to mention the export root folder:

```dart
            content: Text('已保存到: $outputDir\n'
                '目录结构: req/、resp/、api/\n'
                '包含: req/ (${result.reqFiles.length}个), '
                'resp/ (${result.respFiles.length}个), '
                'api/ (1个)'),
```

Update `_showGeneratedCodePreview()` summary card text block to use the helper:

```dart
                      Text(_buildGeneratedSummary(result)),
```

Replace the existing individual `Text('• 请求 Model...')` lines with the single helper output and keep the copy confirmation line beneath it.

Finally, make the dialog action labels favor structured export by changing button text:

```dart
label: const Text('下载目录说明 MD'),
```

and

```dart
label: const Text('导出分目录文件'),
```

- [ ] **Step 4: Run analyzer to verify it passes**

Run: `flutter analyze lib/pages/openapi_import_page.dart lib/utils/batch_file_download_stub.dart lib/utils/batch_file_download_web.dart lib/utils/batch_api_generator.dart lib/utils/openapi_parser.dart lib/models/openapi_document.dart`

Expected: PASS with no new analyzer errors in the touched files.

- [ ] **Step 5: Run the full focused verification with the user scenario fixture**

Run: `flutter test test/utils/openapi_parser_test.dart test/utils/batch_api_generator_test.dart && flutter analyze lib/pages/openapi_import_page.dart lib/utils/batch_file_download_stub.dart lib/utils/batch_file_download_web.dart lib/utils/batch_api_generator.dart lib/utils/openapi_parser.dart lib/models/openapi_document.dart`

Expected: PASS. This proves inline schema parsing works, batch response model generation works, and the export UI compiles against the new result metadata.

- [ ] **Step 6: Commit**

```bash
git add lib/pages/openapi_import_page.dart lib/utils/batch_file_download_stub.dart lib/utils/batch_file_download_web.dart
git commit -m "feat: improve OpenAPI batch export structure"
```

### Task 4: Manual verification with the real `22.json` workflow

**Files:**
- Modify: none required unless verification exposes a real bug
- Reference: `/Users/mini/Downloads/22.json`

- [ ] **Step 1: Run the app locally**

Run: `flutter run -d chrome`

Expected: App launches successfully in a browser.

- [ ] **Step 2: Reproduce the user flow with the real file**

Manual steps:
1. Open “OpenAPI 批量导入” page.
2. Import `/Users/mini/Downloads/22.json`.
3. Keep the default selected endpoints.
4. Fill Base URL with `MyEnvConfig.bizUrl + '/v1'`.
5. Keep or set API 类名 to `AppV20Api`.
6. Click “生成并下载”.
7. In the preview dialog, click “导出分目录文件”.

Expected:
- Preview summary shows non-zero response model count.
- The endpoints corresponding to `/api/servicePlan/purchaseList`, `/api/servicePlan/list`, and `/api/servicePlan/getPurchase` now generate response models.
- Export output contains `req/`, `resp/`, and `api/` directories (desktop) or clearly named exported files (web fallback).

- [ ] **Step 3: Verify the generated response files are the expected ones**

Check for files with these names in the export output:

```text
resp/api_service_plan_purchase_list_resp.dart
resp/api_service_plan_list_resp.dart
resp/api_service_plan_get_purchase_resp.dart
```

Expected: All three files exist and contain generated Dart classes.

- [ ] **Step 4: Verify empty-response endpoints are still skipped**

Check that endpoints like `/api/servicePlan/submit` do not produce meaningless empty response model files.

Expected: No `resp/api_service_plan_submit_resp.dart` file is exported.

- [ ] **Step 5: Run a final status check**

Run: `git status --short`

Expected: Only the intended source/test changes appear.

- [ ] **Step 6: Commit**

```bash
git add lib/models/openapi_document.dart lib/utils/openapi_parser.dart lib/utils/batch_api_generator.dart lib/pages/openapi_import_page.dart lib/utils/batch_file_download_stub.dart lib/utils/batch_file_download_web.dart test/fixtures/openapi_inline_schema.json test/utils/openapi_parser_test.dart test/utils/batch_api_generator_test.dart
git commit -m "fix: support inline OpenAPI model export"
```

---

## Self-Review

- Spec coverage: The plan covers the root-cause fix (inline schema support), the generator path, export UX improvements, and verification against the user’s real `22.json` flow.
- Placeholder scan: All tasks include exact files, commands, and code blocks. No TBD/TODO placeholders remain.
- Type consistency: The new parser methods, `BatchApiCodeResult` fields, and download function signatures are introduced before later tasks rely on them.
