# OpenAPI 批量导入生成规则

## 1. 文档目的与适用范围

本文用于整理当前仓库中 **OpenAPI 批量导入 / 批量生成** 逻辑的真实实现规则，方便开发者对照代码逐项校验与后续完善。

本文只描述“**当前代码实际上怎么做**”，不描述理想方案，也不是面向终端用户的操作手册。

当前文档覆盖的范围包括：

- OpenAPI 文档导入入口与执行链路
- endpoint 提取规则
- 请求 Model 生成规则
- 响应 Model 生成规则
- API 方法生成规则
- 与普通 JSON 转 Dart 共用的 Model 生成规则
- 导出、复制、下载规则
- 跳过规则、隐含规则、已知限制
- 后续建议校验项

## 2. 相关代码入口

本功能当前主要分布在以下文件：

- `lib/pages/openapi_import_page.dart`
- `lib/utils/batch_api_generator.dart`
- `lib/utils/openapi_parser.dart`
- `lib/models/openapi_document.dart`
- `lib/main_controller.dart`
- `lib/utils/batch_file_download_stub.dart`
- `lib/utils/batch_file_download_web.dart`

如果要继续完善规则，通常也需要顺带对照：

- `lib/models/api_config.dart`
- `docs/superpowers/plans/2026-04-11-openapi-inline-schema-model-generation.md`

## 3. 生成链路总览

当前批量导入链路可以概括为：

1. 在 OpenAPI 批量导入页中选择 `.json` 文件。
2. 将 JSON 文本交给 `OpenApiParser.fromJson()` 解析成 `OpenApiDocument`。
3. 调用 `parseEndpoints()` 提取可展示、可勾选的 endpoint 列表。
4. 用户勾选要生成的接口，并填写 `Base URL`、`API 类名`。
5. 调用 `BatchApiCodeGenerator.generateAll()` 逐个 endpoint 生成：
   - 请求 Model
   - 响应 Model
   - API 方法
6. 生成结果可以：
   - 拼接后复制到剪贴板
   - 在弹窗中预览
   - 导出为 `req/`、`resp/`、`api/` 三个目录结构
   - 在 Web 降级为逐个文件下载

对应代码见：

- 导入与入口：`lib/pages/openapi_import_page.dart:133`、`lib/pages/openapi_import_page.dart:155`
- parser 创建：`lib/utils/openapi_parser.dart:334`
- endpoint 提取：`lib/utils/openapi_parser.dart:11`
- 批量生成：`lib/utils/batch_api_generator.dart:54`
- 复制与下载：`lib/pages/openapi_import_page.dart:566`、`lib/pages/openapi_import_page.dart:657`、`lib/pages/openapi_import_page.dart:930`

## 4. 批量导入总体流程

### 4.1 文件导入与解析入口

- 页面只允许选择 `json` 扩展名文件，并且读取 `file.bytes` 后按 UTF-8 解码，异常时仅提示“文件读取失败”。对应代码见 `lib/pages/openapi_import_page.dart:133`。
- 文本解析入口是 `_parseDocument()`，内部直接调用 `OpenApiParser.fromJson(jsonString)`。对应代码见 `lib/pages/openapi_import_page.dart:155`、`lib/utils/openapi_parser.dart:334`。
- 解析成功后会立即调用 `parser.parseEndpoints(includeDeprecated: _includeDeprecated)` 生成 endpoint 列表。对应代码见 `lib/pages/openapi_import_page.dart:157`。
- 页面会把 API 类名默认设置为 `OpenAPI info.title` 转 PascalCase 后再追加 `Api`。对应代码见 `lib/pages/openapi_import_page.dart:164`、`lib/pages/openapi_import_page.dart:1012`。

直接结果：

- 批量导入依赖 OpenAPI 文档中的 `info.title` 来提供默认 API 类名。
- 一旦 parser 成功构建，后续所有批量生成都建立在 `ParsedApiEndpoint` 列表之上。

### 4.2 endpoint 列表展示与选择

- 每个解析出的 endpoint 默认 `selected = true`，即默认全选。对应代码见 `lib/models/openapi_document.dart:365`。
- 页面支持“包含废弃接口”开关；切换时会重新调用 `parseEndpoints(includeDeprecated: ...)` 生成列表，而不是在已有列表上过滤。对应代码见 `lib/pages/openapi_import_page.dart:314`。
- “全选”按钮本质是检查当前是否全部已选，再批量反转 `selected` 状态。对应代码见 `lib/pages/openapi_import_page.dart:358`。

直接结果：

- endpoint 是否进入后续生成流程，最终由 `ParsedApiEndpoint.selected` 决定。
- “包含废弃接口”会影响 endpoint 列表本身，而不仅仅是 UI 展示。

### 4.3 生成动作入口

当前页面有两种生成入口：

1. **复制所有代码**：`_generateAndCopyAll()`，将所有生成内容拼成一个大文本并写入剪贴板。对应代码见 `lib/pages/openapi_import_page.dart:566`。
2. **生成并下载**：`_generateAndDownloadAll()`，先生成一个预览文档文本，再弹窗预览，并允许进一步导出分目录文件。对应代码见 `lib/pages/openapi_import_page.dart:657`、`lib/pages/openapi_import_page.dart:779`。

这两个入口在正式生成前都要求：

- 至少选中一个接口
- `Base URL` 非空
- `API 类名` 非空

对应代码见：

- 复制流程校验：`lib/pages/openapi_import_page.dart:571`
- 下载流程校验：`lib/pages/openapi_import_page.dart:662`

直接结果：

- 当前批量导入不是“零配置即可生成”，至少要求填写 `Base URL` 和 `API 类名`。

## 5. Endpoint 提取规则

## 5.1 遍历路径与 HTTP 方法的规则

- `OpenApiParser.parseEndpoints()` 会遍历 `document.paths.entries`，然后对每个 `PathItem.operations` 中的 operation 继续遍历。对应代码见 `lib/utils/openapi_parser.dart:11`、`lib/models/openapi_document.dart:75`。
- `PathItem.operations` 当前只会收集 `get`、`post`、`put`、`delete` 四种方法。对应代码见 `lib/models/openapi_document.dart:75`。

直接结果：

- 当前批量导入只支持这 4 类 HTTP 方法。
- 如果 OpenAPI 文档里存在 `patch`、`options`、`head` 等方法，当前实现不会进入 endpoint 列表。

## 5.2 deprecated 过滤规则

- `parseEndpoints()` 在 `includeDeprecated == false` 且 `operation.deprecated == true` 时直接 `continue` 跳过。对应代码见 `lib/utils/openapi_parser.dart:22`。

直接结果：

- “是否包含废弃接口”是在解析阶段生效的过滤规则，不是生成阶段再过滤。

## 5.3 参数提取规则

- `parseEndpoints()` 只会把 `parameters` 中 `in == 'path'` 的参数提取到 `pathParameters`，把 `in == 'query'` 的参数提取到 `queryParameters`。对应代码见 `lib/utils/openapi_parser.dart:26`。
- `header`、`cookie` 等其他参数类型没有进入 `ParsedApiEndpoint` 的专门字段。对应代码见 `lib/utils/openapi_parser.dart:26`、`lib/models/openapi_document.dart:361`。

直接结果：

- 当前批量导入只显式处理 path/query 参数。
- 其他参数类型即使存在，也不会进入当前的请求参数推导主链路。

## 5.4 请求体与响应体提取规则

- 请求体只从 `requestBody.content['application/json']['schema']` 里取数据。`RequestBody.schemaRef` 和 `RequestBody.schema` 都是围绕 `application/json` 取值。对应代码见 `lib/models/openapi_document.dart:174`、`lib/models/openapi_document.dart:193`。
- 响应体也只从 `responses['200'].content['application/json']` 中提取 schema / example。对应代码见 `lib/utils/openapi_parser.dart:39`、`lib/models/openapi_document.dart:222`、`lib/models/openapi_document.dart:253`。

直接结果：

- 当前实现只认 `application/json`。
- 当前实现只认 `200` 响应，不会去读 `201`、`204`、`default` 等成功响应。

## 5.5 hasResponse 的当前判定逻辑

- `parseEndpoints()` 中 `hasResponse` 默认是 `true`。对应代码见 `lib/utils/openapi_parser.dart:38`。
- 只有当存在 `responses['200']`，且 `response.example` 是 `Map`，并且其中 `example['data']` 的值等于 `''`、`null` 或 `false` 时，才会把 `hasResponse` 改成 `false`。对应代码见 `lib/utils/openapi_parser.dart:43`。

直接结果：

- `hasResponse` 并不是根据 schema 是否为空来判定。
- 它依赖 `example.data` 的特殊值，是一种带业务假设的特判。

## 5.6 methodName 生成规则

- `ParsedApiEndpoint.methodName` 的来源是 path 分段，而不是 `operationId`。对应代码见 `lib/models/openapi_document.dart:369`。
- 规则是：
  1. path 按 `/` 分割
  2. 去掉空段和 `{id}` 这类路径参数段
  3. 去掉 `v1`、`v2` 这类版本段
  4. 如果剩余段数 >= 2，只取最后两段
  5. 把这两段拼接后转成 camelCase

对应代码见 `lib/models/openapi_document.dart:370`。

直接结果：

- 方法名更接近“路径末尾语义”，不是完整路径语义。
- 不同模块下如果最后两段重复，有潜在重名风险。

## 5.7 classNamePrefix 生成规则

- `ParsedApiEndpoint.classNamePrefix` 同样来自 path，但与 `methodName` 不同，它会使用**整个路径**（去掉空段、路径参数段、版本段后）转 PascalCase。对应代码见 `lib/models/openapi_document.dart:388`。

直接结果：

- `classNamePrefix` 通常比 `methodName` 更长。
- 请求/响应类名是以完整 path 语义为主，而方法名以末尾两段语义为主。

## 5.8 useSprintfUrl 与 requestParameterCount 规则

- `useSprintfUrl` 的判断非常直接：只要 `pathParameters` 非空就返回 `true`。对应代码见 `lib/models/openapi_document.dart:401`。
- `requestParameterCount` 的规则为：
  - 如果 `requestSchemaRef != null`，直接返回 `999`
  - 否则如果 `useSprintfUrl == true`，返回 path 参数数量
  - 否则返回 query 参数数量

对应代码见 `lib/models/openapi_document.dart:412`。

直接结果：

- 请求参数计数是服务于“是否生成请求 Model”的阈值判断，不是用于准确描述所有输入参数。
- 当存在请求体 schema ref 时，参数数值会被人为抬到 `999`。

## 6. 请求 Model 生成规则

## 6.1 生成入口

- `BatchApiCodeGenerator.generateAll()` 会对每个已选中的 endpoint 调用 `_generateRequestModel(endpoint)`。对应代码见 `lib/utils/batch_api_generator.dart:63`、`lib/utils/batch_api_generator.dart:68`。
- 文件名规则为：`_toSnakeCase(_normalizedClassNamePrefix(endpoint)) + '_req.dart'`。对应代码见 `lib/utils/batch_api_generator.dart:70`。

直接结果：

- 请求 Model 文件会放入 `req/` 目录，且统一以后缀 `_req.dart` 结尾。

## 6.2 是否生成请求 Model 的判定规则

- `_generateRequestModel()` 首先依赖 `_usesRequestModel(endpoint)`。如果它返回 `false`，直接不生成。对应代码见 `lib/utils/batch_api_generator.dart:121`。
- `_usesRequestModel(endpoint)` 当前规则为：
  - `requestSchemaRef != null` 时生成
  - 或者 `!endpoint.useSprintfUrl && endpoint.requestParameterCount >= 3` 时生成

对应代码见 `lib/utils/batch_api_generator.dart:210`。

直接结果：

- 只要有 path 参数，哪怕 query 参数很多，也不会走“query 参数数量 >= 3 就生成请求 Model”这条路。
- 少于 3 个 query 参数时，默认不会生成请求 Model。

## 6.3 请求 schema 解析优先顺序

`_generateRequestModel()` 的解析顺序是：

1. 先调用 `parser.resolveRequestSchemaToJsonForEndpoint(endpoint)` 取请求 JSON 示例。对应代码见 `lib/utils/batch_api_generator.dart:126`。
2. `resolveRequestSchemaToJsonForEndpoint()` 内部优先顺序为：
   - 如果 `endpoint.requestSchemaRef != null`，优先 `resolveSchemaToJson(requestSchemaRef)`
   - 否则如果 query 参数存在，则把 query 参数转成 JSON 示例
   - 否则再尝试从 `operation.requestBody.schema` 取 inline schema

对应代码见 `lib/utils/openapi_parser.dart:92`。

直接结果：

- 对请求参数来说，`$ref schema` 优先级最高。
- 没有 `$ref` 时，query 参数会优先于 inline requestBody schema。
- 这意味着某些同时带 query 参数和 inline body 的接口，当前行为可能更偏向 query 参数生成。

## 6.4 query 参数转 JSON 示例规则

- `_queryParametersToJson()` 会把每个 query 参数名作为 key，value 由 `_generateExampleValue(parameter.schema)` 生成。对应代码见 `lib/utils/openapi_parser.dart:110`。
- `_generateExampleValue()` 的默认值规则大致是：
  - `string -> ''`
  - `integer -> 0`
  - `number -> 0.0`
  - `boolean -> false`
  - `array -> [items 默认值]`
  - `object -> 递归转 map`
  - `null -> null`

对应代码见 `lib/utils/openapi_parser.dart:188`。

直接结果：

- query 参数生成请求 Model 时，本质上是先被构造成一个“示例 JSON”，再走统一的 JSON 转 Dart 流程。

## 6.5 path 参数与请求 Model 的关系

- 只要 `endpoint.useSprintfUrl == true`，`_usesRequestModel()` 的第二条阈值逻辑就不会触发。对应代码见 `lib/utils/batch_api_generator.dart:210`。
- GET / DELETE 的 path 参数分支中，当前生成的参数签名固定是 `required String? id`，并使用 `sprintf($urlConstantName, [id])`。对应代码见 `lib/utils/batch_api_generator.dart:279`、`lib/utils/batch_api_generator.dart:470`。

直接结果：

- path 参数不会参与请求 Model 生成。
- 当前 path 参数代码并没有根据真实参数名动态生成，而是写死为 `id`。

## 6.6 请求类名规则

- 请求类名通过 `_normalizedClassNamePrefix(endpoint) + 'Req'` 生成。对应代码见 `lib/utils/batch_api_generator.dart:133`。
- `_normalizedClassNamePrefix()` 会在 `classNamePrefix` 以 `Api` 开头且长度大于 3 时去掉前缀 `Api`。对应代码见 `lib/utils/batch_api_generator.dart:222`。

直接结果：

- 如果 path 以 `/api/...` 开头，对应生成类名前缀会尝试去掉 `Api` 这层公共前缀。

## 6.7 请求 Model 进入 skippedReqModels 的规则

- 当 `reqModelCode == null`，并且 `_usesRequestModel(endpoint) == true`，同时 `endpoint.requestSchemaRef != null` 或 `parser.resolveRequestSchemaToJsonForEndpoint(endpoint) != null`，会把该 endpoint 的 `classNamePrefix` 记入 `skippedReqModels`。对应代码见 `lib/utils/batch_api_generator.dart:72`。

直接结果：

- “跳过请求 Model”并不等于“这个接口没有请求输入”。
- 它更多表示“按当前规则本来想生成，但最后没有成功产出代码”。

## 7. 响应 Model 生成规则

## 7.1 生成入口

- `generateAll()` 只有在 `endpoint.hasResponse == true` 时才会尝试调用 `_generateResponseModel(endpoint)`。对应代码见 `lib/utils/batch_api_generator.dart:79`。
- 响应文件名规则为：`_toSnakeCase(_normalizedClassNamePrefix(endpoint)) + '_resp.dart'`。对应代码见 `lib/utils/batch_api_generator.dart:82`。

直接结果：

- `hasResponse` 是整个响应 Model 生成链路的第一层开关。

## 7.2 响应 schema 解析优先顺序

`_generateResponseModel()` 当前采用以下顺序：

1. 先调用 `parser.extractDataTypeFromResponse(endpoint.responseSchemaRef)` 尝试从响应 schema ref 中提取 `data` 对应的 `$ref`。对应代码见 `lib/utils/batch_api_generator.dart:139`。
2. 如果成功拿到 `dataTypeRef`，则调用 `parser.resolveSchemaToJson(dataTypeRef)`，即优先按 `data` 内层模型生成。对应代码见 `lib/utils/batch_api_generator.dart:143`。
3. 如果拿不到 `dataTypeRef`，则退回 `parser.resolveResponseSchemaToJsonForEndpoint(endpoint)`。对应代码见 `lib/utils/batch_api_generator.dart:146`。

直接结果：

- 对于响应 schema ref，当前实现更偏向直接提取 `data` 内层模型，而不是完整保留外层返回包装结构。

## 7.3 extractDataTypeFromResponse() 的规则

- `extractDataTypeFromResponse()` 仅在 `responseSchemaRef` 存在时生效。对应代码见 `lib/utils/openapi_parser.dart:268`。
- 它会读取 ref 指向的 schema，然后找 `properties['data']`：
  - 如果 `data` 直接是 `$ref`，返回该 ref
  - 如果 `data.type == 'array'` 且 `items.$ref` 存在，也返回该 ref

对应代码见 `lib/utils/openapi_parser.dart:278`。

直接结果：

- 当前实现特别偏向“接口返回统一包裹，真正业务模型在 `data` 字段里”的结构。
- 如果 `data` 不是 `$ref` 而是 inline object/array，就会走 fallback 分支。

## 7.4 fallback 到整个响应 schema 的规则

- `resolveResponseSchemaToJsonForEndpoint()` 的逻辑是：
  - 如果 `endpoint.responseSchemaRef != null`，优先 `resolveSchemaToJson(responseSchemaRef)`
  - 否则调用 `resolveResponseSchemaToJson(path, method)`

对应代码见 `lib/utils/openapi_parser.dart:139`。
- `resolveResponseSchemaToJson(path, method)` 会：
  - 找到对应 operation
  - 读取 `responses['200']`
  - 如果 `response.schemaRef != null`，再次优先 `resolveSchemaToJson(schemaRef)`
  - 否则对 `response.schema` 做 `schemaToJson()`

对应代码见 `lib/utils/openapi_parser.dart:121`。

直接结果：

- 响应处理同样优先 `$ref`，其次才是 inline schema。
- inline response schema 当前已经能走到 `schemaToJson()` 这条路径。

## 7.5 schemaToJson / _schemaToJson 的规则

- `_schemaToJson()` 只在 `type == 'object'` 或 `type == null` 时遍历 `properties`。对应代码见 `lib/utils/openapi_parser.dart:152`。
- 如果属性本身包含 `$ref`，会继续递归解析该 ref。对应代码见 `lib/utils/openapi_parser.dart:168`。
- 其他属性则走 `_generateExampleValue()` 转换成示例值。对应代码见 `lib/utils/openapi_parser.dart:180`。

直接结果：

- schema 转 JSON 的目标不是保留 OpenAPI schema 结构，而是构造一份可交给 JSON-to-Dart 流程使用的示例 JSON。

## 7.6 响应类名规则

- 响应类名通过 `_normalizedClassNamePrefix(endpoint) + 'Resp'` 生成。对应代码见 `lib/utils/batch_api_generator.dart:154`。

直接结果：

- 请求类名与响应类名共享同一个 path-derived 前缀，仅后缀不同。

## 7.7 响应 Model 进入 skippedRespModels 的规则

- 当 `respModelCode == null`，并且 `endpoint.responseSchemaRef != null` 或 `parser.resolveResponseSchemaToJsonForEndpoint(endpoint) != null` 时，会把该 endpoint 的 `classNamePrefix` 记入 `skippedRespModels`。对应代码见 `lib/utils/batch_api_generator.dart:85`。

直接结果：

- 只要当前逻辑认为“本来存在可解析响应”，但最后没产出代码，就会进入 skipped 列表。

## 8. API 方法生成规则

## 8.1 API 类头规则

- `generateAll()` 在开始时先调用 `_generateApiClassHeader(apiContent)`。对应代码见 `lib/utils/batch_api_generator.dart:61`。
- 类头固定输出：
  - `// ignore_for_file: always_specify_types`
  - `class $apiClassName {`
  - `factory $apiClassName() => const $apiClassName._();`
  - `const $apiClassName._();`
  - `static final String _baseUrl = $baseUrl;`

对应代码见 `lib/utils/batch_api_generator.dart:109`。

直接结果：

- 批量 API 文件默认是一个带私有构造和 factory 的类。
- `baseUrl` 会被直接插入源码字符串中，不做额外转义或校验。

## 8.2 URL 常量规则

- 每个方法前都会先写一段注释 `/// ${endpoint.summary} ${endpoint.method.toUpperCase()}`。对应代码见 `lib/utils/batch_api_generator.dart:169`。
- URL 常量名来自 `_getUrlConstantName(endpoint)`：
  - 先取 `endpoint.methodName`
  - 如果结尾是 `Req/req` 则去掉
  - 如果结尾不是 `Url`，则追加 `Url`

对应代码见 `lib/utils/batch_api_generator.dart:165`、`lib/utils/batch_api_generator.dart:513`。
- URL 常量值的规则为：
  - path 参数场景：`static final String xxxUrl = '$_baseUrl${sprintf 格式 path}';`
  - 非 path 参数场景：`static final String xxxUrl = '$_baseUrl${endpoint.path}';`

对应代码见 `lib/utils/batch_api_generator.dart:170`、`lib/utils/batch_api_generator.dart:529`。

直接结果：

- URL 常量统一按方法维度生成。
- path 参数接口不会保留原始 `{id}` 形式，而会转成 `sprintf` 可替换格式。

## 8.3 GET 方法规则

GET 生成逻辑分 4 条分支：

1. `useSprintfUrl == true`
2. `_usesRequestModel(endpoint) == true`
3. `_usesInlineParameters(endpoint) == true`
4. 无参数

对应代码见 `lib/utils/batch_api_generator.dart:270`。

其中：

- path 参数分支固定方法签名为 `required String? id`。对应代码见 `lib/utils/batch_api_generator.dart:281`。
- 请求 Model 分支会把 `req.toJson()..removeWhere(...)` 作为 `queryParameters`。对应代码见 `lib/utils/batch_api_generator.dart:303`。
- inline 参数分支会把 query 参数直接展开到方法签名里，再组装成 `queryParameters` map，并删除值为 `null` 的项。对应代码见 `lib/utils/batch_api_generator.dart:238`、`lib/utils/batch_api_generator.dart:247`、`lib/utils/batch_api_generator.dart:319`。
- 有响应 Model 时返回 `Future<$responseClassName?>`，否则返回 `Future<dynamic>`。对应代码见 `lib/utils/batch_api_generator.dart:280`、`lib/utils/batch_api_generator.dart:289`。

直接结果：

- GET 是当前分支最细的一类，显式区分了 path 参数、请求 Model、inline query 参数、无参数四种形式。

## 8.4 POST 方法规则

POST 同样按 `_usesRequestModel()` / `_usesInlineParameters()` / 无参数 三类处理。对应代码见 `lib/utils/batch_api_generator.dart:358`。

具体规则：

- 有请求 Model 时：
  - 如果 endpoint 有 query 参数，则把 `req.toJson()` 当成 `queryParameters`
  - 否则把 `req.toJson()` 当成 `data`

对应代码见 `lib/utils/batch_api_generator.dart:372`。
- inline 参数分支会把展开参数当成 `queryParameters`，不会生成 body。对应代码见 `lib/utils/batch_api_generator.dart:394`。
- 有响应时返回 `Future<$responseClassName?>`，无响应时返回 `Future<void>`。对应代码见 `lib/utils/batch_api_generator.dart:368`、`lib/utils/batch_api_generator.dart:381`。

直接结果：

- POST 并不是总是把参数放在请求体里；如果 endpoint 同时带 query 参数，请求 Model 也可能走 queryParameters。

## 8.5 PUT 方法规则

- PUT 只生成 `Future<void>`，没有响应 Model 返回分支。对应代码见 `lib/utils/batch_api_generator.dart:426`。
- 有请求 Model 时，如果存在 query 参数，则把 `req.toJson()` 作为 `queryParameters`；否则作为 `data`。对应代码见 `lib/utils/batch_api_generator.dart:434`。
- inline 参数分支同样只走 `queryParameters`。对应代码见 `lib/utils/batch_api_generator.dart:447`。

直接结果：

- PUT 当前没有“有响应体则返回 Resp”的分支实现。

## 8.6 DELETE 方法规则

- DELETE 的 path 参数分支固定返回 `Future<bool>`，并使用 `MyActionUtil.form().handle(...)` 包装删除动作。对应代码见 `lib/utils/batch_api_generator.dart:470`。
- 删除成功/失败文案写死为：`删除中`、`删除成功`、`删除失败`。对应代码见 `lib/utils/batch_api_generator.dart:480`。
- 非 path 参数场景下，DELETE 统一返回 `Future<void>`。对应代码见 `lib/utils/batch_api_generator.dart:486`。

直接结果：

- DELETE 的 path 参数分支是一个明显带业务倾向的特化实现，而不是纯粹的 HTTP 方法模板。

## 8.7 inline 参数展开规则

- `_usesInlineParameters(endpoint)` 的前提是：
  - `!endpoint.useSprintfUrl`
  - `endpoint.requestSchemaRef == null`
  - `endpoint.requestParameterCount > 0`
  - `endpoint.requestParameterCount < 3`

对应代码见 `lib/utils/batch_api_generator.dart:215`。
- `_writeInlineMethodParameters()` 会根据 query 参数 schema 生成 Dart 参数类型，目前只会映射成：
  - `integer -> int?`
  - `number -> double?`
  - `boolean -> bool?`
  - 其他 -> `String?`

对应代码见 `lib/utils/batch_api_generator.dart:238`、`lib/utils/batch_api_generator.dart:256`。

直接结果：

- “少量 query 参数”会直接展开成方法参数，而不是生成请求 Model。
- inline 参数的类型映射明显比完整 Model 生成简单很多。

## 9. Model 共用生成规则

## 9.1 批量生成复用 MainController.generateModelCodeAsync()

- `BatchApiCodeGenerator` 构造时接收了一个 `modelGenerator` 回调，页面层传入的是 `_controller.generateModelCodeAsync`。对应代码见 `lib/pages/openapi_import_page.dart:598`、`lib/main_controller.dart:440`。

直接结果：

- 批量导入没有实现一套独立的 Model 生成器，而是复用了主界面的 JSON 转 Dart 主链路。

## 9.2 生成前清理 validErrors

- `_generateModelCode()` 在解析 JSON 前，先调用 `_removeValidErrorsFromJson(jsonString)` 清理 `validErrors` / `validError` 字段。对应代码见 `lib/main_controller.dart:407`、`lib/main_controller.dart:446`。
- 之后又调用 `_removeValidErrorsField(dartObject!)` 递归移除对象树中的对应字段与类，属于“双重保险”。对应代码见 `lib/main_controller.dart:425`、`lib/main_controller.dart:734`。

直接结果：

- 当前生成流程默认把 `validErrors` 当作不希望出现在最终模型里的污染字段。

## 9.3 嵌套类重命名规则

- `_renameNestedClasses()` 会先把根类名去掉 `Resp` / `Req` 后缀，得到 `baseName`。对应代码见 `lib/main_controller.dart:495`。
- 然后遍历 `allObjects`：
  - 类名为 `Data` 的对象改名为 `${baseName}Data`
  - 类名为 `Rows` 的对象改名为 `${baseName}Model`

对应代码见 `lib/main_controller.dart:510`。

直接结果：

- 当前嵌套类重命名只对 `Data` 和 `Rows` 做了特判，并不是通用命名重写器。

## 9.4 API Model 与普通 Model 的 helper 差异

- `_generateModelCodeWithoutHelpers()` 会写入 `DartHelper.jsonImport`。对应代码见 `lib/main_controller.dart:576`。
- 也会按配置追加 `ConfigSetting().defaultImports`。对应代码见 `lib/main_controller.dart:578`。
- 但明确**不添加**辅助函数（如 `tryCatch`、`FFConvert`、`asT`）。对应代码见 `lib/main_controller.dart:585`。

直接结果：

- 批量导出的 API Model 更接近“纯 Model 文件”，依赖使用方自己准备公共 helper。

## 9.5 失败返回规则

- `_generateModelCodeWithoutHelpers()` 发现类名/属性名错误时，会弹窗并返回 `null`。对应代码见 `lib/main_controller.dart:531`。
- 格式化或生成过程中抛异常，也会返回 `null`，并把错误与堆栈复制到剪贴板。对应代码见 `lib/main_controller.dart:601`。

直接结果：

- 批量生成器侧看到的“某个 Model 没生成出来”，在底层就是拿到了 `null`。

## 10. 导出与下载规则

## 10.1 复制所有代码的拼接规则

- `_generateAndCopyAll()` 会把所有请求 Model 拼在 `// ==================== Request Models ====================` 下，把响应 Model 拼在 `// ==================== Response Models ====================` 下，再把 API 文件拼在 `// ==================== API Methods ====================` 下。对应代码见 `lib/pages/openapi_import_page.dart:608`。
- 每个文件块前会写 `// File: req/xxx.dart`、`// File: resp/xxx.dart`、`// File: xxx_api.dart` 这种伪文件头。对应代码见 `lib/pages/openapi_import_page.dart:611`。

直接结果：

- “复制所有代码”不是导出真实文件，而是导出一份带分段注释的总文本。

## 10.2 生成并下载时的预览文本规则

- `_generateAndDownloadAll()` 会先拼一段 README 风格文本，内容包括：
  - 根目录名
  - `req/`、`resp/`、`api/` 文件结构
  - 使用说明

对应代码见 `lib/pages/openapi_import_page.dart:699`。
- 然后再追加完整代码块，作为弹窗预览和下载说明 MD 的内容来源。对应代码见 `lib/pages/openapi_import_page.dart:723`。

直接结果：

- “生成并下载”先生成的是一份用于预览/复制/下载说明的 Markdown 文本，而不是直接保存目录。

## 10.3 预览弹窗与统计规则

- `_showGeneratedCodePreview()` 会展示生成统计，统计文本由 `_buildGeneratedSummary(result)` 生成。对应代码见 `lib/pages/openapi_import_page.dart:779`、`lib/pages/openapi_import_page.dart:990`。
- 统计里会显示：
  - 请求 Model 数量
  - 响应 Model 数量
  - 选中接口数量作为 API 方法数
  - skippedReqModels / skippedRespModels 列表（如果非空）

对应代码见 `lib/pages/openapi_import_page.dart:990`。

直接结果：

- 预览弹窗能帮助定位“哪些接口选中了，但对应 Model 没生成出来”。

## 10.4 导出根目录命名规则

- `_buildExportRootName()` 会把 `_apiClassNameInput` 中非字母数字字符替换为 `_`。
- 如果处理后为空，则回退为 `openapi_export`。

对应代码见 `lib/pages/openapi_import_page.dart:1006`。

直接结果：

- 导出根目录名本质上来自 API 类名，而不是 OpenAPI title。

## 10.5 Desktop / macOS 分目录导出规则

- `batch_file_download_stub.dart` 中的 `downloadBatchFiles()` 会先让用户选择目录。对应代码见 `lib/utils/batch_file_download_stub.dart:7`。
- 然后创建：
  - `<output>/<exportRootName>/req`
  - `<output>/<exportRootName>/resp`
  - `<output>/<exportRootName>/api`

对应代码见 `lib/utils/batch_file_download_stub.dart:23`。
- 请求、响应、API 文件分别写入这三个目录。对应代码见 `lib/utils/batch_file_download_stub.dart:33`。

直接结果：

- 桌面端分目录导出是真正的目录结构导出，不是 zip，也不是单文本导出。

## 10.6 Web 端导出降级规则

- `batch_file_download_web.dart` 里的 `downloadBatchFiles()` 当前直接 `return null`。对应代码见 `lib/utils/batch_file_download_web.dart:3`。
- 页面层 `_downloadSeparateFiles()` 在拿到 `null` 或捕获异常后，会进入降级逻辑，逐个调用 `file_download.downloadFile()` 下载请求文件、响应文件、API 文件。对应代码见 `lib/pages/openapi_import_page.dart:930`。
- 降级后会提示用户手动整理到 `${_buildExportRootName()}/req、resp、api`。对应代码见 `lib/pages/openapi_import_page.dart:981`。

直接结果：

- Web 端当前并不真正支持创建目录结构，只能逐个文件下载后手动整理。

## 11. 跳过规则、隐含规则与已知问题

### 11.1 明确的跳过规则

- 未选中的 endpoint 在 `generateAll()` 里会被直接 `continue` 跳过，不参与任何请求/响应/API 生成。对应代码见 `lib/utils/batch_api_generator.dart:63`。
- `hasResponse == false` 的 endpoint 不会尝试生成响应 Model。对应代码见 `lib/utils/batch_api_generator.dart:79`。
- `_usesRequestModel(endpoint) == false` 时，不会生成请求 Model。对应代码见 `lib/utils/batch_api_generator.dart:121`。
- 对于复制/下载入口，如果一个接口都没选，流程会在页面层直接终止。对应代码见 `lib/pages/openapi_import_page.dart:574`、`lib/pages/openapi_import_page.dart:665`。

### 11.2 隐含规则

- `requestSchemaRef` 不存在且 query 参数少于 3 个时，不会生成请求 Model，而是可能直接展开为 inline 参数。对应代码见 `lib/utils/batch_api_generator.dart:210`、`lib/utils/batch_api_generator.dart:215`。
- path 参数存在时优先走 `sprintf` URL 分支，因此不会再走 query inline 参数的展开逻辑。对应代码见 `lib/models/openapi_document.dart:401`、`lib/utils/batch_api_generator.dart:279`。
- 请求和响应 schema 都优先 `$ref`，只有拿不到 `$ref` 时才回退到 inline schema。对应代码见 `lib/utils/openapi_parser.dart:92`、`lib/utils/openapi_parser.dart:121`、`lib/utils/batch_api_generator.dart:139`。
- schema 最终都会先转成“示例 JSON”，再交给 JSON-to-Dart 主链路，而不是直接按 OpenAPI schema 生成 Dart。对应代码见 `lib/utils/openapi_parser.dart:148`、`lib/main_controller.dart:407`。

### 11.3 当前已知限制 / 待完善点

- 只识别 `application/json`，没有覆盖其他 content type。对应代码见 `lib/models/openapi_document.dart:179`、`lib/models/openapi_document.dart:227`。
- 只识别 `200` 响应，没有覆盖 `201`、`204`、`default` 等成功响应。对应代码见 `lib/utils/openapi_parser.dart:39`、`lib/utils/openapi_parser.dart:126`。
- `hasResponse` 依赖 `example.data` 的特殊值判断，规则带有明显业务假设，不够通用。对应代码见 `lib/utils/openapi_parser.dart:43`。
- path 参数生成代码当前固定为 `id`，没有按真实 path 参数名动态生成。对应代码见 `lib/utils/batch_api_generator.dart:281`、`lib/utils/batch_api_generator.dart:471`。
- query 参数少于 3 个时默认不生成请求 Model，这个阈值是硬编码规则。对应代码见 `lib/utils/batch_api_generator.dart:210`、`lib/utils/batch_api_generator.dart:215`。
- 响应模型解析优先抽取 `data` 内层 `$ref`，可能忽略外层统一返回包装结构。对应代码见 `lib/utils/openapi_parser.dart:268`、`lib/utils/batch_api_generator.dart:139`。
- PUT 当前没有生成“带响应体返回”的分支。对应代码见 `lib/utils/batch_api_generator.dart:426`。
- Web 端 `downloadBatchFiles()` 当前空实现，只能依赖页面层降级逐个下载。对应代码见 `lib/utils/batch_file_download_web.dart:3`、`lib/pages/openapi_import_page.dart:957`。

## 12. 建议校验清单

- [ ] 是否需要支持除 `200` 之外的成功响应码
- [ ] 是否需要支持除 `application/json` 之外的 content type
- [ ] path 参数是否需要支持多个参数而不是固定 `id`
- [ ] `hasResponse` 是否应该脱离 `example.data` 特判
- [ ] 请求参数少于 3 个时是否仍应允许生成请求 Model
- [ ] 响应模型是否应优先保留完整包裹结构而不是只抽取 `data`
- [ ] PUT / DELETE 是否也需要像 GET / POST 一样完整区分有响应与无响应分支
- [ ] query 参数与 inline requestBody 同时存在时，优先级是否需要重新定义
- [ ] Web 端是否需要真正支持分目录导出

## 13. 附录：规则总表

### 13.1 命名规则总表

| 项目 | 当前规则 | 代码位置 | 备注 |
| --- | --- | --- | --- |
| endpoint 方法名 | 从 path 去掉空段、路径参数段、版本段后，取最后两段转 camelCase | `lib/models/openapi_document.dart:369` | 不使用 `operationId` |
| endpoint 类名前缀 | 从 path 去掉空段、路径参数段、版本段后，整条路径转 PascalCase | `lib/models/openapi_document.dart:388` | 比方法名更长 |
| 请求类名 | `_normalizedClassNamePrefix(endpoint) + 'Req'` | `lib/utils/batch_api_generator.dart:133` | 可能去掉前导 `Api` |
| 响应类名 | `_normalizedClassNamePrefix(endpoint) + 'Resp'` | `lib/utils/batch_api_generator.dart:154` | 与请求类名共享前缀 |
| 请求文件名 | `snake_case(prefix) + '_req.dart'` | `lib/utils/batch_api_generator.dart:70` | 输出到 `req/` |
| 响应文件名 | `snake_case(prefix) + '_resp.dart'` | `lib/utils/batch_api_generator.dart:82` | 输出到 `resp/` |
| API 文件名 | `snake_case(apiClassName) + '.dart'` | `lib/utils/batch_api_generator.dart:97` | 输出到 `api/` |
| 导出根目录名 | API 类名中的非字母数字替换为 `_`，空则回退 `openapi_export` | `lib/pages/openapi_import_page.dart:1006` | 与 OpenAPI title 无直接绑定 |

### 13.2 请求/响应生成判定总表

| 项目 | 当前规则 | 代码位置 | 备注 |
| --- | --- | --- | --- |
| 是否解析 endpoint | 仅遍历 `get/post/put/delete` | `lib/models/openapi_document.dart:75` | 其他 HTTP 方法忽略 |
| 是否包含废弃接口 | `includeDeprecated == false` 时跳过 `deprecated` 接口 | `lib/utils/openapi_parser.dart:22` | 解析阶段过滤 |
| 是否生成请求 Model | `requestSchemaRef != null` 或 `!useSprintfUrl && requestParameterCount >= 3` | `lib/utils/batch_api_generator.dart:210` | 3 是硬编码阈值 |
| 是否展开 inline 参数 | `!useSprintfUrl && requestSchemaRef == null && 0 < requestParameterCount < 3` | `lib/utils/batch_api_generator.dart:215` | 只处理少量 query 参数 |
| 是否生成响应 Model | `endpoint.hasResponse == true` 时才尝试 | `lib/utils/batch_api_generator.dart:79` | 首先受 `hasResponse` 控制 |
| hasResponse 判定 | 依赖 `response.example['data']` 是否为 `''/null/false` | `lib/utils/openapi_parser.dart:43` | 业务特判 |
| 响应优先解析策略 | 优先提取 `data` 内部 `$ref`，否则 fallback 到整个响应 schema | `lib/utils/batch_api_generator.dart:139`、`lib/utils/openapi_parser.dart:268` | 倾向抽取业务 data |
| schema 转 JSON | 优先 `$ref`，否则递归生成示例 JSON | `lib/utils/openapi_parser.dart:79`、`lib/utils/openapi_parser.dart:152` | 再交给 JSON-to-Dart |

### 13.3 导出产物总表

| 项目 | 当前规则 | 代码位置 | 备注 |
| --- | --- | --- | --- |
| 复制所有代码 | 拼成一个大文本后写入剪贴板 | `lib/pages/openapi_import_page.dart:608` | 带 `// File:` 注释 |
| 预览文本 | 先生成目录说明，再附完整代码块 | `lib/pages/openapi_import_page.dart:699`、`lib/pages/openapi_import_page.dart:723` | 用于弹窗预览和下载说明 |
| 请求目录导出 | 写入 `<root>/req/` | `lib/utils/batch_file_download_stub.dart:24` | Desktop 真目录 |
| 响应目录导出 | 写入 `<root>/resp/` | `lib/utils/batch_file_download_stub.dart:25` | Desktop 真目录 |
| API 目录导出 | 写入 `<root>/api/` | `lib/utils/batch_file_download_stub.dart:26` | Desktop 真目录 |
| Web 分目录导出 | `downloadBatchFiles()` 直接返回 `null` | `lib/utils/batch_file_download_web.dart:3` | 实际未实现 |
| Web 降级导出 | 改为逐个下载所有文件 | `lib/pages/openapi_import_page.dart:960` | 用户手动整理目录 |

### 13.4 跳过生成总表

| 项目 | 当前规则 | 代码位置 | 备注 |
| --- | --- | --- | --- |
| 未选中的 endpoint | 在 `generateAll()` 里直接跳过 | `lib/utils/batch_api_generator.dart:63` | 不生成任何产物 |
| 请求 Model 被跳过 | 本来满足请求 Model 条件，但最终没生成代码时记入 `skippedReqModels` | `lib/utils/batch_api_generator.dart:72` | 用 `classNamePrefix` 记录 |
| 响应 Model 被跳过 | 本来存在可解析响应，但最终没生成代码时记入 `skippedRespModels` | `lib/utils/batch_api_generator.dart:85` | 用 `classNamePrefix` 记录 |
| 无响应体接口 | `hasResponse == false` 时不生成响应 Model | `lib/utils/batch_api_generator.dart:79` | API 方法仍会生成 |
| 请求参数较少 | 少于 3 个 query 参数时通常不生成请求 Model | `lib/utils/batch_api_generator.dart:210`、`lib/utils/batch_api_generator.dart:215` | 可能转为 inline 参数 |

---

## 结论

当前 OpenAPI 批量导入实现已经形成了一套比较明确的“**路径驱动命名 + schema 转示例 JSON + 复用 JSON-to-Dart 生成 + 按目录导出**”的链路，但其中仍存在若干明显带业务假设或硬编码阈值的规则。

如果后续要继续完善，优先建议从下面几项开始：

1. 去掉 `hasResponse` 对 `example.data` 的特殊值依赖
2. 放宽成功响应码与 content type 的识别范围
3. 让 path 参数按真实参数名生成，而不是固定 `id`
4. 重新评估“少于 3 个 query 参数不生成请求 Model”的阈值规则
5. 明确响应模型应保留完整包裹结构还是继续优先抽取 `data`
6. 补齐 Web 端目录导出能力
