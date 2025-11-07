# API 请求模式功能说明

## 概述

现在 JSON to Dart 工具支持两种不同的 API 请求模式,让你可以根据实际需求选择最合适的代码生成方式。

## 两种请求模式

### 1. 直接请求模式 (Direct Mode)

**适用场景:**
- 查询操作 (GET)
- 列表获取 (POST/GET)
- 详情查看 (GET)
- 不需要用户反馈的操作

**生成代码特点:**
- 直接调用 `MyHttpUtil()` 发送请求
- 返回实际的响应数据类型 (如 `Future<ResponseClass?>`)
- 不显示加载提示、成功/失败提示
- 代码更简洁

**示例代码 (POST 请求):**
```dart
static Future<ListResp?> listReq({
  required ListReq req,
}) async {
  var response = await MyHttpUtil().post(list,
      data: req.toJson()..removeWhere((key, value) => value == null));
  return ListResp.fromJson(response);
}
```

**示例代码 (GET 请求):**
```dart
static Future<DetailResp?> detailReq({
  required String? id,
}) async {
  var response = await MyHttpUtil().get(
    sprintf(detail, [id]),
  );
  return DetailResp.fromJson(response);
}
```

### 2. Form 请求模式 (Form Mode)

**适用场景:**
- 新建操作 (POST)
- 修改操作 (PUT)
- 删除操作 (DELETE)
- 需要用户反馈的操作

**生成代码特点:**
- 使用 `MyActionUtil.form().handle()` 包装请求
- 返回 `Future<bool>` 表示操作是否成功
- 自动显示加载中、成功、失败提示
- 提供更好的用户体验

**示例代码 (POST 请求):**
```dart
static Future<bool> addReq({
  required AddReq req,
}) async {
  bool result = await MyActionUtil.form().handle(
    action: () async {
      return await MyHttpUtil().post(add,
          data: req.toJson()..removeWhere((key, value) => value == null));
    },
    loadText: '提交中...',
    successText: '提交成功',
    errorText: '提交失败',
  );
  return result;
}
```

**示例代码 (DELETE 请求):**
```dart
static Future<bool> deleteReq({
  required String? id,
}) async {
  bool result = await MyActionUtil.form().handle(
    action: () async {
      return await MyHttpUtil().delete(
        sprintf(delete, [id]),
      );
    },
    loadText: '删除中...',
    successText: '删除成功',
    errorText: '删除失败',
  );
  return result;
}
```

## 智能推荐功能

系统会根据你选择的 HTTP 方法自动推荐合适的请求模式:

| HTTP 方法 | 默认推荐模式 | 原因 |
|-----------|--------------|------|
| GET | Direct (直接请求) | 查询操作通常不需要用户反馈 |
| POST | 保持当前选择 | POST 既可能是查询也可能是添加 |
| PUT | Form (Form请求) | 修改操作需要用户反馈 |
| DELETE | Form (Form请求) | 删除操作需要用户确认和反馈 |

## 自定义提示文本 (Form 模式)

当选择 Form 请求模式时,可以自定义三个提示文本:

1. **加载提示文本** - 请求进行中显示的文本 (默认: "提交中...")
2. **成功提示文本** - 请求成功后显示的文本 (默认: "提交成功")
3. **失败提示文本** - 请求失败后显示的文本 (默认: "提交失败")

系统会根据 HTTP 方法智能设置默认文本:

- **POST**: 提交中... / 提交成功 / 提交失败
- **PUT**: 修改中... / 修改成功 / 修改失败
- **DELETE**: 删除中... / 删除成功 / 删除失败
- **GET**: 加载中... / 加载成功 / 加载失败

## 使用示例

### 场景1: 获取列表 (查询操作)

**配置:**
- HTTP 方法: POST
- 请求模式: Direct (直接请求)
- 有响应参数: 是

**生成结果:**
```dart
static Future<ListResp?> listReq({
  required ListReq req,
}) async {
  var response = await MyHttpUtil().post(list,
      data: req.toJson()..removeWhere((key, value) => value == null));
  return ListResp.fromJson(response);
}
```

### 场景2: 添加数据 (需要用户反馈)

**配置:**
- HTTP 方法: POST
- 请求模式: Form (Form请求)
- 有响应参数: 否
- 加载提示: "提交中..."
- 成功提示: "提交成功"
- 失败提示: "提交失败"

**生成结果:**
```dart
static Future<bool> addReq({
  required AddReq req,
}) async {
  bool result = await MyActionUtil.form().handle(
    action: () async {
      return await MyHttpUtil().post(add,
          data: req.toJson()..removeWhere((key, value) => value == null));
    },
    loadText: '提交中...',
    successText: '提交成功',
    errorText: '提交失败',
  );
  return result;
}
```

### 场景3: 删除数据 (路径参数 + Form 模式)

**配置:**
- HTTP 方法: DELETE
- 请求模式: Form (Form请求)
- 使用 sprintf 格式化 URL: 是
- 加载提示: "删除中..."
- 成功提示: "删除成功"
- 失败提示: "删除失败"

**生成结果:**
```dart
static Future<bool> deleteReq({
  required String? id,
}) async {
  bool result = await MyActionUtil.form().handle(
    action: () async {
      return await MyHttpUtil().delete(
        sprintf(delete, [id]),
      );
    },
    loadText: '删除中...',
    successText: '删除成功',
    errorText: '删除失败',
  );
  return result;
}
```

## 配置界面说明

在 API 代码生成配置界面中:

1. **请求模式下拉菜单**: 选择 "直接请求 (Direct)" 或 "Form 请求 (带提示)"
2. **请求模式说明**: 显示当前选择模式的详细说明
3. **Form 提示文本配置**: 只在选择 Form 模式时显示,可以自定义三个提示文本

## 最佳实践建议

### 使用 Direct 模式的场景:
- ✅ 列表查询
- ✅ 详情查看
- ✅ 搜索功能
- ✅ 数据统计
- ✅ 不需要用户感知的后台操作

### 使用 Form 模式的场景:
- ✅ 创建新数据
- ✅ 更新现有数据
- ✅ 删除数据
- ✅ 提交表单
- ✅ 需要用户明确知道操作结果的场景

## 技术实现

### 修改的文件

1. **lib/models/api_config.dart**
   - 添加 `ApiRequestMode` 枚举 (direct/form)
   - 添加 `requestMode` 配置字段
   - 添加 `formLoadText`, `formSuccessText`, `formErrorText` 配置字段

2. **lib/utils/api_code_generator.dart**
   - 更新所有 HTTP 方法生成逻辑 (POST/GET/PUT/DELETE)
   - 根据 `requestMode` 生成不同的代码

3. **lib/pages/api_config_page.dart**
   - 添加请求模式下拉菜单
   - 添加 Form 提示文本配置输入框
   - 实现智能推荐逻辑

### 核心逻辑

**Direct 模式 - 有响应参数:**
```dart
if (apiConfig.requestMode.value == ApiRequestMode.direct) {
  if (apiConfig.hasResponse.value) {
    // 生成返回响应类型的代码
    sb.writeLine('static Future<$responseClassName?> $actualMethodName({');
    // ... 直接调用 MyHttpUtil
  }
}
```

**Form 模式:**
```dart
else {
  // 生成返回 bool 的代码,使用 MyActionUtil.form()
  sb.writeLine('static Future<bool> $actualMethodName({');
  sb.writeLine('  bool result = await MyActionUtil.form().handle(');
  // ... 包装请求并显示提示
}
```

## 总结

新增的请求模式功能让 API 代码生成更加灵活和智能:

- 🎯 **智能推荐**: 根据 HTTP 方法自动推荐合适的模式
- 🔧 **灵活配置**: 可以自由选择任意组合
- 💬 **自定义提示**: Form 模式下可以自定义所有提示文本
- 📝 **代码规范**: 生成的代码符合项目规范,可直接使用
- 🚀 **提高效率**: 减少手动编写重复代码的时间
