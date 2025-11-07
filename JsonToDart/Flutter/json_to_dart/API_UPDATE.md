# API 代码生成 - 更新说明

## 生成格式

现在的 API 代码生成**不再生成完整的 API 类**,而是生成可以直接添加到现有 API 类中的**代码片段**。

## 生成示例

### 输入:
```
请求方法名: list
方法注释: 列表
API URL: /other/in/warehouse/search
HTTP 方法: POST
```

### 生成的 API 代码片段:
```dart
import 'package:sprintf/sprintf.dart';
import 'package:xjj_app_common/xjj_app_common.dart';
import 'package:your_app/model/req/list.dart';
import 'package:your_app/model/resp/list_resp.dart';

/// 列表 post
static final String list = _baseUrl + '/other/in/warehouse/search';

static Future<ListResp?> listReq({
  required List req,
}) async {
  var response = await MyHttpUtil().post(list,
      data: req.toJson()..removeWhere((key, value) => value == null));
  return ListResp.fromJson(response);
}
```

## 使用方式

1. 将生成的 **URL 常量** 和 **请求方法** 复制到你现有的 API 类中
2. 不需要创建新的 API 类,只需要添加到现有类中

例如添加到:
```dart
class OtherStockInApi {
  static final String _baseUrl = MyEnvConfig.bizUrl + '/api/mat/v1';

  // 在这里粘贴生成的代码
  /// 列表 post
  static final String list = _baseUrl + '/other/in/warehouse/search';

  static Future<OtherStockInListResp?> listReq({
    required OtherStockInListReq req,
  }) async {
    var response = await MyHttpUtil().post(list,
        data: req.toJson()..removeWhere((key, value) => value == null));
    return OtherStockInListResp.fromJson(response);
  }
}
```

## 方法名规则

- **URL 常量名**: 使用你输入的 `methodName` (如: `list`)
- **请求方法名**: `{methodName}Req` (如: `listReq`)
- **Model 类名**: 自动生成大写开头 (如: `List` -> `ListReq` / `ListResp`)

## 注释

- 可以在 "方法注释" 字段输入中文注释 (如: "列表")
- 如果不填写,会自动使用方法名

## 不同 HTTP 方法

所有方法的生成格式都遵循上述规则,只是请求方式不同:
- **POST**: 使用 `post()`,传递 `data`
- **GET**: 使用 `get()`,传递 `queryParameters` 或使用 `sprintf` 格式化
- **PUT**: 使用 `put()`,包含 `MyActionUtil` 处理
- **DELETE**: 使用 `delete()`,包含 `MyActionUtil` 处理
