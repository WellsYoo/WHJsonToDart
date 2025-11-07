# API 代码生成功能使用指南

## 功能概述

新增的 API 代码生成功能可以根据 API 的请求和响应 JSON,自动生成以下三个文件:

1. **请求参数 Model** (`{method_name}.dart`) - 如: `login_req.dart`
2. **响应参数 Model** (`{method_name.replace('Req', 'Resp')}.dart`) - 如: `login_resp.dart`
3. **API 方法文件** (`{method_name}_api.dart`) - 如: `login_api.dart`

## 使用步骤

### 1. 进入 API 代码生成模式

在主界面底部的设置栏,点击 **"API 代码生成"** 按钮,切换到 API 生成模式。

### 2. 填写配置信息

在左侧的配置面板中,填写以下信息:

#### 必填项:
- **请求方法名** (例如: `loginReq`)
  - 类名会自动生成: `LoginReq` / `LoginResp`
  - 文件名会自动生成: `login_req.dart` / `login_resp.dart` / `login_api.dart`

- **API URL** (例如: `/api/v1/user/login`)

- **请求参数 JSON** - 粘贴请求参数的 JSON 示例

- **响应参数 JSON** - 粘贴响应参数的 JSON 示例

#### 可选项:
- **Base URL** (例如: `MyEnvConfig.bizUrl + '/api/v1'`)
  - 如果填写,会在生成的代码中创建 `_baseUrl` 常量

- **HTTP 方法** - 选择 GET/POST/PUT/DELETE
  - 不同的方法会生成不同的请求代码

- **使用 sprintf 格式化 URL** - 勾选此项用于带路径参数的 URL
  - 例如: `/api/user/%s` (用于 GET 单个资源或 DELETE)

### 3. 生成代码

点击 **"生成 API 代码"** 按钮,系统会:
1. 解析请求和响应 JSON
2. 生成对应的 Dart Model 类
3. 根据 HTTP 方法生成 API 请求方法
4. 格式化所有代码

### 4. 查看和复制生成结果

右侧会显示生成的三个文件:
- 每个文件都可以单独复制
- 也可以点击 **"复制所有代码"** 一次性复制所有文件内容

### 5. 返回普通模式

点击左上角的 **"返回 JSON 转 Dart"** 按钮,返回普通的 JSON 转 Dart 模式。

## 生成示例

### 输入:
```
请求方法名: loginReq
API URL: /api/v1/user/login
HTTP 方法: POST
Base URL: MyEnvConfig.bizUrl + '/api/v1'

请求参数 JSON:
{
  "username": "admin",
  "password": "123456"
}

响应参数 JSON:
{
  "code": 200,
  "message": "success",
  "data": {
    "token": "xxx",
    "userId": 1
  }
}
```

### 输出:

#### 1. login_req.dart
```dart
import 'dart:convert';

class LoginReq {
  LoginReq({
    this.username,
    this.password,
  });

  factory LoginReq.fromJson(Map<String, dynamic> jsonRes) {
    return LoginReq(
      username: asT<String?>(jsonRes['username']),
      password: asT<String?>(jsonRes['password']),
    );
  }

  String? username;
  String? password;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'username': username,
    'password': password,
  };
}
```

#### 2. login_resp.dart
```dart
import 'dart:convert';

class LoginResp {
  LoginResp({
    this.code,
    this.message,
    this.data,
  });

  factory LoginResp.fromJson(Map<String, dynamic> jsonRes) {
    return LoginResp(
      code: asT<int?>(jsonRes['code']),
      message: asT<String?>(jsonRes['message']),
      data: jsonRes['data'] == null
          ? null
          : LoginRespData.fromJson(asT<Map<String, dynamic>>(jsonRes['data'])!),
    );
  }

  int? code;
  String? message;
  LoginRespData? data;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'message': message,
    'data': data,
  };
}

class LoginRespData {
  // ... 嵌套类
}
```

#### 3. login_api.dart
```dart
import 'package:xjj_app_common/xjj_app_common.dart';
import 'package:your_app/model/req/login_req.dart';
import 'package:your_app/model/resp/login_resp.dart';

/// login
class LoginApi {
  static final String _baseUrl = MyEnvConfig.bizUrl + '/api/v1';

  /// POST - loginReq
  static final String loginReqUrl = _baseUrl + '/api/v1/user/login';

  static Future<LoginResp?> loginReq({
    required LoginReq req,
  }) async {
    var response = await MyHttpUtil().post(loginReqUrl,
        data: req.toJson()..removeWhere((key, value) => value == null));
    return LoginResp.fromJson(response);
  }
}
```

## 不同 HTTP 方法的生成差异

### POST 方法
```dart
static Future<ResponseClass?> methodName({
  required RequestClass req,
}) async {
  var response = await MyHttpUtil().post(methodNameUrl,
      data: req.toJson()..removeWhere((key, value) => value == null));
  return ResponseClass.fromJson(response);
}
```

### GET 方法 (普通)
```dart
static Future<ResponseClass?> methodName({
  required RequestClass req,
}) async {
  var response = await MyHttpUtil().get(
    methodNameUrl,
    queryParameters: req.toJson()..removeWhere((key, value) => value == null),
  );
  return ResponseClass.fromJson(response);
}
```

### GET 方法 (使用 sprintf)
```dart
static Future<ResponseClass?> methodName({
  required String? id,
}) async {
  var response = await MyHttpUtil().get(
    sprintf(methodNameUrl, [id]),
  );
  return ResponseClass.fromJson(response);
}
```

### PUT 方法
```dart
static Future<bool> methodName({
  required RequestClass req,
}) async {
  bool result = await MyActionUtil.form().handle(
    action: () async {
      return await MyHttpUtil().put(methodNameUrl,
          data: req.toJson()..removeWhere((key, value) => value == null));
    },
    loadText: '提交中...',
    successText: '提交成功',
    errorText: '提交失败',
  );
  return result;
}
```

### DELETE 方法 (使用 sprintf)
```dart
static Future<bool> methodName({
  required String? id,
}) async {
  bool result = await MyActionUtil.form().handle(
    action: () async {
      return await MyHttpUtil().delete(
        sprintf(methodNameUrl, [id]),
      );
    },
    loadText: '删除中...',
    successText: '删除成功',
    errorText: '删除失败',
  );
  return result;
}
```

## 注意事项

1. **导入路径**: 生成的代码中使用了 `package:your_app` 作为占位符,需要手动替换为你的实际包名

2. **依赖要求**: 生成的代码假设项目中已经有:
   - `xjj_app_common` 包 (或类似的 HTTP 工具包)
   - `sprintf` 包 (如果使用 sprintf 格式化 URL)

3. **Model 配置**: 生成的 Model 会使用当前设置中的所有配置选项:
   - 命名规范 (camelCase, PascalCase 等)
   - 是否生成 copyWith 方法
   - 是否启用 null safety
   - 等等

4. **代码格式化**: 生成的代码会自动使用 `dart_style` 进行格式化

## 文件架构

生成代码参考的文件结构:
```
lib/
├── model/
│   ├── req/
│   │   └── {method_name}.dart       # 请求参数 Model
│   └── resp/
│       └── {method_name_resp}.dart  # 响应参数 Model
└── api/
    └── {method_name}_api.dart       # API 方法
```

## 反馈

如果遇到问题或有改进建议,请及时反馈!
