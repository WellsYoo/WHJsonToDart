# API 代码生成功能 - 完整更新说明

## 更新内容

### 1. 支持无响应参数的 API
- 添加了"有响应参数"选项(默认勾选)
- 取消勾选时,API 方法返回 `bool` 类型
- 自动使用 `MyActionUtil.form().handle()` 包装请求
- 适用于添加、修改、删除等操作

### 2. 自动过滤 validErrors 字段
- 生成 Model 时自动移除 `validErrors` 字段
- 递归处理所有嵌套对象
- 避免重复定义公共字段

### 3. 简化的 API 代码生成
- 不生成完整的 API 类结构
- 只生成 URL 常量和请求方法
- 可以直接复制到现有 API 类中

## 使用示例

### 示例 1: 有响应参数的 POST 请求(列表查询)

**输入配置:**
```
请求方法名: list
方法注释: 列表
API URL: /other/in/warehouse/search
HTTP 方法: POST
Base URL: MyEnvConfig.bizUrl + '/api/mat/v1'
有响应参数: ✅ 勾选

请求参数 JSON:
{
  "pageNum": 1,
  "pageSize": 10,
  "keyword": "test"
}

响应参数 JSON:
{
  "code": 200,
  "message": "success",
  "data": {
    "total": 100,
    "rows": []
  }
}
```

**生成的 API 代码:**
```dart
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

**生成的请求参数 Model (list.dart):**
```dart
import 'dart:convert';

class List {
  List({
    this.pageNum,
    this.pageSize,
    this.keyword,
  });

  factory List.fromJson(Map<String, dynamic> jsonRes) {
    return List(
      pageNum: asT<int?>(jsonRes['pageNum']),
      pageSize: asT<int?>(jsonRes['pageSize']),
      keyword: asT<String?>(jsonRes['keyword']),
    );
  }

  int? pageNum;
  int? pageSize;
  String? keyword;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pageNum': pageNum,
    'pageSize': pageSize,
    'keyword': keyword,
  };
}
```

**生成的响应参数 Model (list_resp.dart):**
```dart
import 'dart:convert';

class ListResp {
  ListResp({
    this.code,
    this.message,
    this.data,
  });

  factory ListResp.fromJson(Map<String, dynamic> jsonRes) {
    return ListResp(
      code: asT<int?>(jsonRes['code']),
      message: asT<String?>(jsonRes['message']),
      data: jsonRes['data'] == null
          ? null
          : ListRespData.fromJson(asT<Map<String, dynamic>>(jsonRes['data'])!),
    );
  }

  int? code;
  String? message;
  ListRespData? data;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'message': message,
    'data': data,
  };
}

class ListRespData {
  ListRespData({
    this.total,
    this.rows,
  });

  factory ListRespData.fromJson(Map<String, dynamic> jsonRes) {
    return ListRespData(
      total: asT<int?>(jsonRes['total']),
      rows: jsonRes['rows'] is List ? <dynamic>[] : null,
    );
  }

  int? total;
  List<dynamic>? rows;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'total': total,
    'rows': rows,
  };
}
```

---

### 示例 2: 无响应参数的 POST 请求(添加操作)

**输入配置:**
```
请求方法名: add
方法注释: 保存
API URL: /other/in/warehouse
HTTP 方法: POST
Base URL: MyEnvConfig.bizUrl + '/api/mat/v1'
有响应参数: ❌ 不勾选

请求参数 JSON:
{
  "name": "test",
  "warehouseId": "123",
  "items": []
}
```

**生成的 API 代码:**
```dart
import 'package:xjj_app_common/xjj_app_common.dart';
import 'package:your_app/model/req/add.dart';

/// 保存 post
static final String add = _baseUrl + '/other/in/warehouse';

static Future<bool> addReq({
  required Add req,
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

**注意:** 只生成请求参数 Model,不生成响应参数 Model

---

### 示例 3: GET 请求(详情查询,使用 sprintf)

**输入配置:**
```
请求方法名: detail
方法注释: 详情
API URL: /other/in/warehouse/%s
HTTP 方法: GET
Base URL: MyEnvConfig.bizUrl + '/api/mat/v1'
使用 sprintf 格式化 URL: ✅ 勾选
有响应参数: ✅ 勾选
```

**生成的 API 代码:**
```dart
import 'package:sprintf/sprintf.dart';
import 'package:xjj_app_common/xjj_app_common.dart';
import 'package:your_app/model/resp/detail_resp.dart';

/// 详情 get
static final String detail = _baseUrl + '/other/in/warehouse/%s';

static Future<DetailResp?> detailReq({
  required String? id,
}) async {
  var response = await MyHttpUtil().get(
    sprintf(detail, [id]),
  );
  return DetailResp.fromJson(response);
}
```

---

### 示例 4: PUT 请求(编辑操作)

**输入配置:**
```
请求方法名: edit
方法注释: 编辑
API URL: /other/in/warehouse
HTTP 方法: PUT
有响应参数: ❌ 不勾选
```

**生成的 API 代码:**
```dart
import 'package:xjj_app_common/xjj_app_common.dart';
import 'package:your_app/model/req/edit.dart';

/// 编辑 put
static final String edit = _baseUrl + '/other/in/warehouse';

static Future<bool> editReq({
  required Edit req,
}) async {
  bool result = await MyActionUtil.form().handle(
    action: () async {
      return await MyHttpUtil().put(edit,
          data: req.toJson()..removeWhere((key, value) => value == null));
    },
    loadText: '提交中...',
    successText: '提交成功',
    errorText: '提交失败',
  );
  return result;
}
```

---

### 示例 5: DELETE 请求(删除操作)

**输入配置:**
```
请求方法名: delete
方法注释: 删除
API URL: /other/in/warehouse/%s
HTTP 方法: DELETE
使用 sprintf 格式化 URL: ✅ 勾选
```

**生成的 API 代码:**
```dart
import 'package:sprintf/sprintf.dart';
import 'package:xjj_app_common/xjj_app_common.dart';

/// 删除 delete
static final String delete = _baseUrl + '/other/in/warehouse/%s';

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

---

## 完整的 API 类示例

将生成的代码添加到现有的 API 类中:

```dart
import 'package:sprintf/sprintf.dart';
import 'package:xjj_app_common/xjj_app_common.dart';
import 'package:your_app/model/req/other_stock_in/other_stock_in_list_req.dart';
import 'package:your_app/model/req/other_stock_in/other_stock_in_add_req.dart';
import 'package:your_app/model/resp/other_stock_in/other_stock_in_list_resp.dart';
import 'package:your_app/model/resp/other_stock_in/other_stock_in_detail_resp.dart';

/// 其他入库单
class OtherStockInApi {
  static final String _baseUrl = MyEnvConfig.bizUrl + '/api/mat/v1';

  /// 列表 post
  static final String list = _baseUrl + '/other/in/warehouse/search';

  static Future<OtherStockInListResp?> listReq({
    required OtherStockInListReq req,
  }) async {
    var response = await MyHttpUtil().post(list,
        data: req.toJson()..removeWhere((key, value) => value == null));
    return OtherStockInListResp.fromJson(response);
  }

  /// 详情 get
  static final String detail = _baseUrl + '/other/in/warehouse/%s';

  static Future<OtherStockInDetailResp?> detailReq({
    required String? id,
  }) async {
    var response = await MyHttpUtil().get(
      sprintf(detail, [id]),
    );
    return OtherStockInDetailResp.fromJson(response);
  }

  /// 保存 post
  static final String add = _baseUrl + '/other/in/warehouse';

  static Future<bool> addReq({
    required OtherStockInAddReq req,
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

  /// 编辑 put
  static final String edit = _baseUrl + '/other/in/warehouse';

  static Future<bool> editReq({
    required OtherStockInAddReq req,
  }) async {
    bool result = await MyActionUtil.form().handle(
      action: () async {
        return await MyHttpUtil().put(edit,
            data: req.toJson()..removeWhere((key, value) => value == null));
      },
      loadText: '提交中...',
      successText: '提交成功',
      errorText: '提交失败',
    );
    return result;
  }

  /// 删除 delete
  static final String delete = _baseUrl + '/other/in/warehouse/%s';

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
}
```

## 关键特性总结

### ✅ 已实现
1. **灵活的响应处理**
   - 有响应: 返回 `Future<ResponseClass?>`
   - 无响应: 返回 `Future<bool>`,自动包装 `MyActionUtil.form().handle()`

2. **自动字段过滤**
   - 自动移除 `validErrors` 字段
   - 避免重复定义公共响应字段

3. **代码片段生成**
   - 不生成完整类结构
   - 只生成 URL 常量和请求方法
   - 方便添加到现有 API 类

4. **支持多种 HTTP 方法**
   - GET (普通/sprintf)
   - POST
   - PUT
   - DELETE

5. **智能命名**
   - URL 常量名: `list`, `detail`, `add` 等
   - 请求方法名: `listReq`, `detailReq`, `addReq` 等
   - Model 类名: `List`, `ListResp`, `Detail`, `DetailResp` 等

### 📝 注意事项

1. **导入路径**: 生成的代码中 `package:your_app` 需要替换为实际的包名

2. **公共方法**: 生成的 Model 使用了 `asT` 和 `tryCatch` 方法,需要在项目中定义或导入,通常在 `preload.dart` 文件中

3. **Model 配置**: 生成的 Model 会使用当前设置中的所有配置选项(命名规范、null safety 等)

4. **validErrors 字段**: 如果响应 JSON 中包含 `validErrors` 字段,会自动被过滤掉

## 工作流程

1. 点击 **"API 代码生成"** 按钮进入 API 模式
2. 填写配置信息:
   - 请求方法名
   - 方法注释(可选)
   - API URL
   - Base URL(可选)
   - 选择 HTTP 方法
   - 勾选相关选项
   - 输入 JSON
3. 点击 **"生成 API 代码"**
4. 在右侧查看生成结果
5. 复制代码到项目中

生成的文件可以单独复制,也可以一次性复制所有代码!
