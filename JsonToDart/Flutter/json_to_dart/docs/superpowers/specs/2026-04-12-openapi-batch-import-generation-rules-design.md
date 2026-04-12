# OpenAPI 批量导入生成规则文档设计

**日期：** 2026-04-12
**主题：** 整理批量导入生成规则并输出开发者中文文档
**目标：** 基于当前代码实现，整理 OpenAPI 批量导入 / 批量生成的真实规则、隐含规则、跳过规则、导出规则与已知限制，形成一份可用于自查和后续完善的中文文档，放入 `docs/` 目录。

## 1. 背景与定位

当前仓库已经具备 OpenAPI 批量导入能力，核心逻辑分布在解析层、批量生成层、Model 生成复用层以及页面导出层。用户本次需求不是补功能，而是先把“现有代码到底按什么规则生成”整理清楚，方便后续逐项完善。

因此，这份文档不是面向最终使用者的操作手册，而是面向开发者的“规则校验文档”。文档必须忠实描述当前实现，而不是描述理想状态。

## 2. 文档产出范围

最终文档覆盖以下范围：

1. OpenAPI 批量导入入口与执行链路
2. endpoint 提取规则
3. 请求 Model 生成规则
4. 响应 Model 生成规则
5. API 方法生成规则
6. Model 共用生成规则
7. 文件命名与导出结构规则
8. 跳过生成与降级行为
9. 当前隐含规则、边界条件与已知问题
10. 建议校验清单
11. 汇总附录（命名、判定、跳过、输出总表）

## 3. 信息来源

文档以当前仓库实现为准，重点依据以下文件：

- `lib/pages/openapi_import_page.dart`
- `lib/utils/batch_api_generator.dart`
- `lib/utils/openapi_parser.dart`
- `lib/models/openapi_document.dart`
- `lib/main_controller.dart`
- `lib/utils/batch_file_download_stub.dart`
- `lib/utils/batch_file_download_web.dart`
- `lib/models/api_config.dart`
- 已存在的实现计划文档 `docs/superpowers/plans/2026-04-11-openapi-inline-schema-model-generation.md`

## 4. 推荐文档结构

### 4.1 文档开头
- 文档目的
- 适用范围
- 核心文件定位
- 一张简化的生成链路说明

### 4.2 主体按执行链路展开
正文采用“从输入到输出”的链路式结构，而不是按文件逐个说明。这样更适合后续对照代码逐项校验。

建议章节顺序：

#### A. 批量导入总体流程
说明从上传 OpenAPI JSON、解析 endpoints、选择接口、调用批量生成器，到复制/下载输出的完整流程。

#### B. Endpoint 提取规则
描述：
- 如何遍历 `paths`
- 如何遍历每个 path 下的 HTTP method
- 如何处理 `deprecated`
- 如何提取 path/query 参数
- 只取 `200` 响应的现状
- `hasResponse` 的当前判定方式
- `methodName` 和 `classNamePrefix` 的生成逻辑

#### C. 请求 Model 生成规则
描述：
- 什么情况下生成请求 Model
- `$ref` schema、inline schema、query 参数三者的优先顺序
- path 参数与请求 Model 的关系
- 类名和文件名规则
- 哪些情况会被跳过并进入 skipped 列表

#### D. 响应 Model 生成规则
描述：
- `hasResponse` 为真时才尝试生成
- 优先通过 `extractDataTypeFromResponse()` 提取 `data` 对应 `$ref`
- fallback 到整个响应 schema 转 JSON
- inline response schema 的当前支持边界
- 空 schema 与跳过逻辑
- 类名和文件名规则

#### E. API 方法生成规则
描述：
- API 类头生成方式
- `_baseUrl` 与 URL 常量规则
- GET/POST/PUT/DELETE 分支
- `sprintf` URL、请求 Model、inline 参数 三种参数传递形态
- 有响应 / 无响应时返回值差异
- 当前写死或不够通用的部分（如 path 参数固定 `id`）

#### F. Model 共用生成规则
描述：
- 批量生成如何复用 `MainController.generateModelCodeAsync()`
- 生成前如何移除 `validErrors`
- 嵌套类重命名：`Data -> XxxData`、`Rows -> XxxModel`
- API Model 与普通 Model 在 helper 注入上的差异
- 失败时如何返回 `null`

#### G. 导出与下载规则
描述：
- 复制全部代码时的内容拼接格式
- 下载预览说明 MD 的内容来源
- 分目录导出结构：`req/`、`resp/`、`api/`
- 桌面端与 Web 端差异
- Web 端当前空实现的事实

#### H. 跳过规则与已知问题
这一章必须显式区分：
- 明确规则
- 隐含规则
- 明显限制 / 待完善点

内容包括：
- `requestParameterCount >= 3` 才生成请求 Model 的阈值规则
- path 参数存在时优先走 `sprintf`，不会走 query inline 逻辑
- 只识别 `application/json`
- 只识别 `200`
- `hasResponse` 对 example 的依赖不稳
- 响应模型解析优先取 `data`，可能忽略外层包装意图
- Web 端目录导出未实现
- path 参数生成固定为 `id`

### 4.3 末尾附录总表
正文之后附一个汇总区，便于快速查规则：

1. 命名规则总表
2. 请求/响应生成判定总表
3. 导出产物总表
4. 跳过生成总表
5. 已知问题清单

## 5. 写作原则

最终文档必须遵循以下原则：

1. **以当前代码为准**：描述“现在是怎么做的”，不是“应该怎么做”。
2. **明确区分事实与判断**：
   - 事实：当前代码路径与行为
   - 判断：可能有问题、值得优化的点
3. **注明关键代码位置**：尽量使用 `file_path:line_number` 形式标注核心规则来源。
4. **中文表达清晰可检索**：章节名要便于后续搜索，比如“请求 Model 生成规则”“跳过生成规则”“已知限制”。
5. **不是用户教程**：不过多描述按钮使用，而是重心放在规则与实现约束。

## 6. 实施方式

实际执行时，先继续补齐必要代码阅读，再在 `docs/` 下创建最终中文文档。建议文件名：

- `docs/openapi_batch_import_generation_rules.md`

如果在整理过程中发现更贴切的文件名，可以微调，但应保持清晰、稳定、可搜索。

## 7. 风险与注意事项

1. 当前实现分散在多个文件中，部分规则是显式逻辑，部分规则是执行顺序带来的隐式行为，文档必须把两者区分开。
2. 部分逻辑已经在最近计划文档中出现，但最终文档不能照搬计划，而要以当前仓库代码实际状态为准。
3. 一些行为可能存在“实现与命名不完全一致”的情况，文档中需要保留这种不一致，而不是替代码美化解释。

## 8. 完成标准

当满足以下条件时，认为该文档完成：

- 已放入 `docs/` 目录
- 为中文文档
- 覆盖主链路、命名、判定、导出、跳过、已知问题
- 关键规则附有代码位置引用
- 适合开发者逐项校验并继续完善

## 9. 备注

按用户明确要求，后续流程无需再次逐步征求确认，可直接继续产出最终文档。
