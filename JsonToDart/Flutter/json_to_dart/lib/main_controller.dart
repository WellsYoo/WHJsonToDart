import 'dart:convert';

import 'package:dart_style/dart_style.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:json_schema/json_schema.dart';
import 'package:json_to_dart/l10n/app_localizations.dart';
import 'package:json_to_dart_library/json_to_dart_library.dart' hide StringE;

import 'models/api_config.dart';
import 'models/config.dart';
import 'utils/api_code_generator.dart';
import 'utils/file_download_stub.dart'
    if (dart.library.html) 'utils/file_download_web.dart' as file_download;

AppLocalizations get appLocalizations => AppLocalizations.of(Get.context!)!;

/// Custom TextEditingController that preserves IME composing state
/// to fix Chinese/Japanese/Korean input method issues
class ComposingTextEditingController extends TextEditingController {
  @override
  set value(TextEditingValue newValue) {
    // Preserve composing range when updating text programmatically
    // This prevents interrupting IME composition (e.g., Chinese Pinyin input)
    final TextRange composing = value.composing;

    // If there's an active composition, preserve it
    if (composing.isValid && !composing.isCollapsed) {
      super.value = newValue.copyWith(composing: composing);
    } else {
      super.value = newValue;
    }
  }

  @override
  set text(String newText) {
    // Check if composing is in progress
    if (value.composing.isValid && !value.composing.isCollapsed) {
      // Don't update text while composing
      return;
    }
    super.text = newText;
  }
}

void showAlertDialog(String msg, [IconData data = Icons.warning]) {
  SmartDialog.show(
    builder: (BuildContext b) => AlertDialog(
      title: Icon(data),
      content: Text(msg),
      actions: <Widget>[
        TextButton(
          child: Text(appLocalizations.ok),
          onPressed: () {
            SmartDialog.dismiss();
          },
        ),
      ],
    ),
  );
}

class MainController extends GetxController with JsonToDartControllerMixin {
  final TextEditingController _textEditingController = ComposingTextEditingController();

  final TextEditingController fileHeaderHelpController = TextEditingController()
    ..text = ConfigSetting().fileHeaderInfo;

  DartObject? dartObject;

  /// API 配置
  final ApiConfig apiConfig = ApiConfig();

  /// API 生成结果
  ApiCodeGenerationResult? apiCodeGenerationResult;

  String get text => _textEditingController.text;

  set text(String value) {
    _textEditingController.text = value;
  }

  TextEditingController get textEditingController => _textEditingController;

  Future<void> formatJsonAndCreateDartObject() async {
    allProperties.clear();
    allObjects.clear();
    if (text.isNullOrEmpty) {
      return;
    }

    SmartDialog.showLoading(
      builder: (BuildContext context) => const Center(
        child: SpinKitCubeGrid(color: Colors.orange),
      ),
    );

    String inputText = text;
    try {
      if (kIsWeb) {
        // fix https://github.com/dart-lang/sdk/issues/34105
        inputText = text.replaceAll('.0', '.1');
      }

      dynamic jsonData = await compute<String, dynamic>(jsonDecode, inputText)
          .onError((Object? error, StackTrace stackTrace) {
        handleError(error, stackTrace);
      });

      // If the JSON data is a Map and contains a valid JSON Schema, convert it
      if (jsonData is Map && JsonSchemaHelper.isJsonSchema(jsonData)) {
        jsonData = JsonSchemaHelper.createJsonWithJsonSchema(
          JsonSchema.create(jsonData),
        );
      }

      final DartObject? extendedObject = dynamicToDartObject(jsonData);
      // final DartObject? extendedObject =
      //     await compute<dynamic, DartObject?>(createDartObject, jsonData)
      //         .onError((Object? error, StackTrace stackTrace) {
      //   handleError(error, stackTrace);
      // });
      if (extendedObject == null) {
        SmartDialog.dismiss();
        showAlertDialog(appLocalizations.illegalJson, Icons.error);
        return;
      }

      dartObject = extendedObject;
      if (ConfigSetting().nullsafety.value &&
          ConfigSetting().nullable.value &&
          !ConfigSetting().smartNullable.value) {
        updateNullable(true);
      }

      final String? formatJsonString = await compute<dynamic, String?>(formatJson, jsonData)
          .onError((Object? error, StackTrace stackTrace) {
        handleError(error, stackTrace);
        return null;
      });
      if (formatJsonString != null) {
        // 保存当前光标位置
        final int cursorPosition = _textEditingController.selection.baseOffset;
        _textEditingController.text = formatJsonString;
        // 恢复光标位置,确保不超出新文本长度
        if (cursorPosition >= 0 && cursorPosition <= formatJsonString.length) {
          _textEditingController.selection = TextSelection.fromPosition(
            TextPosition(offset: cursorPosition),
          );
        }
      }

      update();
    } catch (error, stackTrace) {
      handleError(error, stackTrace);
    }
    SmartDialog.dismiss();
  }

  @override
  String? generateDartCode(DartObject? dartObject) {
    printedObjects.clear();

    if (dartObject != null) {
      final DartObject? errorObject = allObjects.firstOrNullWhere(
          (DartObject element) => element.hasClassError || element.hasPropertyError);
      if (errorObject != null) {
        showAlertDialog(
            errorObject.classError.join('\n') + '\n' + errorObject.propertyError.join('\n'));
        return null;
      }

      final DartProperty? errorProperty =
          allProperties.firstOrNullWhere((DartProperty element) => element.hasPropertyError);

      if (errorProperty != null) {
        showAlertDialog(errorProperty.propertyError.join('\n'));
        return null;
      }

      final CustomStringBuffer sb = CustomStringBuffer();
      try {
        if (ConfigSetting().fileHeaderInfo.isNotEmpty) {
          String info = ConfigSetting().fileHeaderInfo;
          //[Date MM-dd HH:mm]
          try {
            int start = info.indexOf('[Date');
            final int startIndex = start;
            if (start >= 0) {
              start = start + '[Date'.length;
              final int end = info.indexOf(']', start);
              if (end >= start) {
                String format = info.substring(start, end - start).trim();

                final String replaceString = info.substring(startIndex, end - startIndex + 1);
                if (format == '') {
                  format = 'yyyy MM-dd';
                }

                info = info.replaceAll(replaceString, DateFormat(format).format(DateTime.now()));
              }
            }
          } catch (e) {
            showAlertDialog(appLocalizations.timeFormatError, Icons.error);
          }

          sb.writeLine(info);
        }

        sb.writeLine(DartHelper.jsonImport);

        // 添加默认导入 (仅用于 Model)
        for (final String defaultImport in ConfigSetting().defaultImports) {
          if (defaultImport.trim().isNotEmpty) {
            sb.writeLine('import \'$defaultImport\';');
          }
        }

        if (ConfigSetting().addMethod.value) {
          if (ConfigSetting().enableArrayProtection.value) {
            sb.writeLine('import \'dart:developer\';');
            sb.writeLine(ConfigSetting().nullsafety.value
                ? DartHelper.tryCatchMethodNullSafety
                : DartHelper.tryCatchMethod);
          }

          sb.writeLine(ConfigSetting().enableDataProtection.value
              ? ConfigSetting().nullsafety.value
                  ? DartHelper.asTMethodWithDataProtectionNullSafety
                  : DartHelper.asTMethodWithDataProtection
              : ConfigSetting().nullsafety.value
                  ? DartHelper.asTMethodNullSafety
                  : DartHelper.asTMethod);
        }

        sb.writeLine(dartObject.toString());
        String result = sb.toString();

        final DartFormatter formatter = DartFormatter(
          languageVersion: DartFormatter.latestLanguageVersion,
        );

        result = formatter.format(result);

        // _textEditingController.text = result;
        Clipboard.setData(ClipboardData(text: result));
        SmartDialog.showToast(appLocalizations.generateSucceed);

        return result;
      } catch (e, stack) {
        print('$e');
        print('$stack');
        // _textEditingController.text = sb.toString();
        showAlertDialog(appLocalizations.generateFailed, Icons.error);
        Clipboard.setData(ClipboardData(text: '$e\n$stack'));
        return null;
      }
    }
    return null;
  }

  void orderPropeties() {
    if (dartObject != null) {
      dartObject!.orderPropeties();
      update();
    }
  }

  void selectAll() {
    _textEditingController
      ..text = text
      ..selection = TextSelection(baseOffset: 0, extentOffset: text.length - 1);
  }

  void updateNameByNamingConventionsType() {
    if (dartObject != null) {
      dartObject!.updateNameByNamingConventionsType();
      update();
    }
  }

  void updateNullable(bool nullable) {
    if (dartObject != null) {
      dartObject!.updateNullable(nullable);
    }
  }

  void updatePropertyAccessorType() {
    if (dartObject != null) {
      dartObject!.updatePropertyAccessorType();
    }
  }

  @override
  void handleError(Object? e, StackTrace stack) {
    print('$e');
    print('$stack');
    showAlertDialog(appLocalizations.formatErrorInfo, Icons.error);

    Clipboard.setData(ClipboardData(text: '$e\n$stack'));
  }

  /// 生成 API 相关代码 (请求/响应 Model + API 方法)
  Future<void> generateApiCode() async {
    if (apiConfig.methodName.value.isEmpty) {
      showAlertDialog('请输入请求方法名', Icons.error);
      return;
    }

    if (apiConfig.apiUrl.value.isEmpty) {
      showAlertDialog('请输入 API URL', Icons.error);
      return;
    }

    if (apiConfig.requestJson.value.isEmpty) {
      showAlertDialog('请输入请求参数 JSON', Icons.error);
      return;
    }

    if (apiConfig.hasResponse.value && apiConfig.responseJson.value.isEmpty) {
      showAlertDialog('请输入响应参数 JSON', Icons.error);
      return;
    }

    SmartDialog.showLoading(
      builder: (BuildContext context) => const Center(
        child: SpinKitCubeGrid(color: Colors.orange),
      ),
    );

    try {
      // 1. 生成请求参数 Model
      final String? requestModelCode = await _generateModelCode(
        apiConfig.requestJson.value,
        apiConfig.requestClassName,
      );
      if (requestModelCode == null) {
        SmartDialog.dismiss();
        showAlertDialog('请求参数 Model 生成失败', Icons.error);
        return;
      }

      // 2. 生成响应参数 Model (如果需要)
      String? responseModelCode;
      if (apiConfig.hasResponse.value) {
        responseModelCode = await _generateModelCode(
          apiConfig.responseJson.value,
          apiConfig.responseClassName,
        );
        if (responseModelCode == null) {
          SmartDialog.dismiss();
          showAlertDialog('响应参数 Model 生成失败', Icons.error);
          return;
        }
      } else {
        // 无响应参数,使用空字符串
        responseModelCode = '';
      }

      // 3. 生成 API 方法代码
      apiCodeGenerationResult = ApiCodeGenerator.generateApiCode(
        apiConfig: apiConfig,
        requestModelCode: requestModelCode,
        responseModelCode: responseModelCode,
      );

      if (apiCodeGenerationResult != null) {
        // 复制所有代码到剪贴板
        final StringBuffer sb = StringBuffer();
        sb.writeln('// ========== ${apiCodeGenerationResult!.requestFileName} ==========');
        sb.writeln(apiCodeGenerationResult!.requestModelCode);
        sb.writeln();

        // 只在有响应参数时才添加
        if (apiCodeGenerationResult!.responseModelCode.isNotEmpty) {
          sb.writeln('// ========== ${apiCodeGenerationResult!.responseFileName} ==========');
          sb.writeln(apiCodeGenerationResult!.responseModelCode);
          sb.writeln();
        }

        sb.writeln('// ========== ${apiCodeGenerationResult!.apiFileName} ==========');
        sb.writeln(apiCodeGenerationResult!.apiMethodCode);

        Clipboard.setData(ClipboardData(text: sb.toString()));

        SmartDialog.dismiss();
        SmartDialog.showToast('API 代码生成成功,已复制到剪贴板');
        update();
      } else {
        SmartDialog.dismiss();
        showAlertDialog('API 代码生成失败', Icons.error);
      }
    } catch (e, stack) {
      SmartDialog.dismiss();
      handleError(e, stack);
    }
  }

  /// 生成单个 Model 代码的辅助方法
  Future<String?> _generateModelCode(String jsonString, String className) async {
    // 清理 printedObjects,避免影响当前生成
    // (allProperties 和 allObjects 会在 formatJsonAndCreateDartObject 中清理)
    printedObjects.clear();

    // 在解析 JSON 之前，先移除 validErrors 字段
    jsonString = _removeValidErrorsFromJson(jsonString);

    text = jsonString;
    await formatJsonAndCreateDartObject();
    if (dartObject == null) {
      return null;
    }
    dartObject!.className = className;

    // 重命名嵌套类 (Data -> XxxData, Rows -> XxxModel)
    _renameNestedClasses(dartObject!, className);

    // 移除 validErrors 字段（双重保险）
    _removeValidErrorsField(dartObject!);

    // 清除所有对象的错误状态(重要:避免残留的错误状态影响生成)
    for (final DartObject obj in allObjects) {
      obj.classError.clear();
      obj.propertyError.clear();
    }
    for (final DartProperty prop in allProperties) {
      prop.propertyError.clear();
    }

    return _generateModelCodeWithoutHelpers(dartObject);
  }

  /// 生成单个 Model 代码的公共方法 (供批量生成器使用)
  Future<String?> generateModelCodeAsync(String jsonString, String className) async {
    return await _generateModelCode(jsonString, className);
  }

  /// 从 JSON 字符串中移除 validErrors 字段
  String _removeValidErrorsFromJson(String jsonString) {
    try {
      final dynamic jsonData = jsonDecode(jsonString);
      if (jsonData is Map<String, dynamic>) {
        // 移除顶层的 validErrors
        jsonData.remove('validErrors');
        jsonData.remove('validError');

        // 递归移除嵌套对象中的 validErrors
        _removeValidErrorsFromMap(jsonData);

        return const JsonEncoder.withIndent('  ').convert(jsonData);
      } else if (jsonData is List) {
        // 如果是数组，处理每个元素
        for (final dynamic item in jsonData) {
          if (item is Map<String, dynamic>) {
            item.remove('validErrors');
            item.remove('validError');
            _removeValidErrorsFromMap(item);
          }
        }
        return const JsonEncoder.withIndent('  ').convert(jsonData);
      }
    } catch (e) {
      // 如果解析失败，返回原始字符串
      print('移除 validErrors 时出错: $e');
    }
    return jsonString;
  }

  /// 递归移除 Map 中的 validErrors 字段
  void _removeValidErrorsFromMap(Map<String, dynamic> map) {
    map.remove('validErrors');
    map.remove('validError');

    for (final dynamic value in map.values) {
      if (value is Map<String, dynamic>) {
        _removeValidErrorsFromMap(value);
      } else if (value is List) {
        for (final dynamic item in value) {
          if (item is Map<String, dynamic>) {
            _removeValidErrorsFromMap(item);
          }
        }
      }
    }
  }

  /// 重命名嵌套类 (Data -> XxxData, Rows -> XxxModel)
  void _renameNestedClasses(DartObject rootObject, String rootClassName) {
    // 获取根类名的基础部分（移除 Resp/Req 后缀）
    String baseName = rootClassName;
    if (baseName.endsWith('Resp')) {
      baseName = baseName.substring(0, baseName.length - 4);
    } else if (baseName.endsWith('Req')) {
      baseName = baseName.substring(0, baseName.length - 3);
    }

    // 先移除 ValidErrors 类，再进行重命名
    allObjects.removeWhere((DartObject obj) =>
        obj.className == 'ValidErrors' ||
        obj.className == 'ValidError' ||
        obj.className.toLowerCase().contains('validerror'));

    // 遍历所有对象并重命名
    for (final DartObject obj in allObjects) {
      if (obj.className == 'Data') {
        obj.className = '${baseName}Data';
      } else if (obj.className == 'Rows') {
        obj.className = '${baseName}Model';
      }
    }
  }

  /// 生成 Model 代码(不包含辅助函数)
  String? _generateModelCodeWithoutHelpers(DartObject? dartObject) {
    printedObjects.clear();

    if (dartObject != null) {
      // 再次确保移除 ValidErrors 类和相关属性（防止在 toString 生成时被包含）
      allObjects.removeWhere((DartObject obj) =>
          obj.className == 'ValidErrors' ||
          obj.className == 'ValidError' ||
          obj.className.toLowerCase().contains('validerror'));

      final DartObject? errorObject = allObjects.firstOrNullWhere(
          (DartObject element) => element.hasClassError || element.hasPropertyError);
      if (errorObject != null) {
        showAlertDialog(
            errorObject.classError.join('\n') + '\n' + errorObject.propertyError.join('\n'));
        return null;
      }

      final DartProperty? errorProperty =
          allProperties.firstOrNullWhere((DartProperty element) => element.hasPropertyError);

      if (errorProperty != null) {
        showAlertDialog(errorProperty.propertyError.join('\n'));
        return null;
      }

      final CustomStringBuffer sb = CustomStringBuffer();
      try {
        if (ConfigSetting().fileHeaderInfo.isNotEmpty) {
          String info = ConfigSetting().fileHeaderInfo;
          //[Date MM-dd HH:mm]
          try {
            int start = info.indexOf('[Date');
            final int startIndex = start;
            if (start >= 0) {
              start = start + '[Date'.length;
              final int end = info.indexOf(']', start);
              if (end >= start) {
                String format = info.substring(start, end - start).trim();

                final String replaceString = info.substring(startIndex, end - startIndex + 1);
                if (format == '') {
                  format = 'yyyy MM-dd';
                }

                info = info.replaceAll(replaceString, DateFormat(format).format(DateTime.now()));
              }
            }
          } catch (e) {
            showAlertDialog(appLocalizations.timeFormatError, Icons.error);
          }

          sb.writeLine(info);
        }

        sb.writeLine(DartHelper.jsonImport);

        // 添加默认导入 (仅用于 Model)
        for (final String defaultImport in ConfigSetting().defaultImports) {
          if (defaultImport.trim().isNotEmpty) {
            sb.writeLine('import \'$defaultImport\';');
          }
        }

        // API Model 不添加辅助函数 (tryCatch, FFConvert, asT)
        // 这些函数应该由用户在单独的工具类中定义

        sb.writeLine(dartObject.toString());
        String result = sb.toString();

        // 后处理：移除 ValidErrors 类的定义（如果还存在）
        result = _removeValidErrorsClassFromCode(result);

        final DartFormatter formatter = DartFormatter(
          languageVersion: DartFormatter.latestLanguageVersion,
        );

        result = formatter.format(result);

        return result;
      } catch (e, stack) {
        print('$e');
        print('$stack');
        showAlertDialog(appLocalizations.generateFailed, Icons.error);
        Clipboard.setData(ClipboardData(text: '$e\n$stack'));
        return null;
      }
    }
    return null;
  }

  /// 从生成的代码中移除 ValidErrors 类定义
  String _removeValidErrorsClassFromCode(String code) {
    // 使用正则表达式匹配并移除整个 ValidErrors 类
    final RegExp validErrorsClassPattern = RegExp(
      r'class\s+ValidErrors?\s*\{[^}]*\}(?:\s*\n)*',
      multiLine: true,
      dotAll: true,
    );

    // 更精确的正则：匹配完整的类定义（包括所有方法）
    final RegExp validErrorsFullClassPattern = RegExp(
      r'class\s+ValidErrors?\s*\{[\s\S]*?\n\}\s*(?=\nclass|\n*$)',
      multiLine: true,
    );

    String result = code;

    // 先尝试精确匹配
    result = result.replaceAll(validErrorsFullClassPattern, '');

    // 如果还有残留，使用简单匹配
    result = result.replaceAll(validErrorsClassPattern, '');

    return result;
  }

  /// 复制所有 API 代码到剪贴板
  void copyAllApiCode() {
    if (apiCodeGenerationResult == null) {
      return;
    }

    final StringBuffer sb = StringBuffer();
    sb.writeln('// ========== ${apiCodeGenerationResult!.requestFileName} ==========');
    sb.writeln(apiCodeGenerationResult!.requestModelCode);
    sb.writeln();

    // 只在有响应参数时才添加
    if (apiCodeGenerationResult!.responseModelCode.isNotEmpty) {
      sb.writeln('// ========== ${apiCodeGenerationResult!.responseFileName} ==========');
      sb.writeln(apiCodeGenerationResult!.responseModelCode);
      sb.writeln();
    }

    sb.writeln('// ========== ${apiCodeGenerationResult!.apiFileName} ==========');
    sb.writeln(apiCodeGenerationResult!.apiMethodCode);

    Clipboard.setData(ClipboardData(text: sb.toString()));
    SmartDialog.showToast('已复制所有代码到剪贴板');
  }

  /// 复制单个文件代码到剪贴板
  void copyFileCode(String code, String fileName) {
    Clipboard.setData(ClipboardData(text: code));
    SmartDialog.showToast('已复制 $fileName 到剪贴板');
  }

  /// 下载文件到本地
  Future<bool> downloadFile(String content, String fileName,
      {bool showToast = true}) async {
    try {
      await file_download.downloadFile(content, fileName);
      if (showToast) {
        SmartDialog.showToast('已下载 $fileName');
      }
      return true;
    } catch (e) {
      if (showToast) {
        SmartDialog.showToast('下载失败: $e');
      }
      return false;
    }
  }

  /// 导出所有 API 文件
  Future<void> exportAllApiFiles() async {
    if (apiCodeGenerationResult == null) {
      return;
    }

    int successCount = 0;
    final int totalCount = apiCodeGenerationResult!.responseModelCode.isNotEmpty ? 3 : 2;

    // 下载请求参数 Model
    if (await downloadFile(
      apiCodeGenerationResult!.requestModelCode,
      apiCodeGenerationResult!.requestFileName,
      showToast: false,
    )) {
      successCount++;
    }

    // 只在有响应参数时才下载
    if (apiCodeGenerationResult!.responseModelCode.isNotEmpty) {
      if (await downloadFile(
        apiCodeGenerationResult!.responseModelCode,
        apiCodeGenerationResult!.responseFileName,
        showToast: false,
      )) {
        successCount++;
      }
    }

    // 下载 API 方法文件
    if (await downloadFile(
      apiCodeGenerationResult!.apiMethodCode,
      apiCodeGenerationResult!.apiFileName,
      showToast: false,
    )) {
      successCount++;
    }

    // 统一显示一次结果提示
    if (successCount == totalCount) {
      SmartDialog.showToast('成功导出 $successCount 个文件');
    } else if (successCount > 0) {
      SmartDialog.showToast('已导出 $successCount/$totalCount 个文件');
    } else {
      SmartDialog.showToast('导出失败');
    }
  }

  /// 移除 validErrors 字段和 ValidErrors 类 (递归处理所有嵌套对象)
  void _removeValidErrorsField(DartObject dartObject) {
    // 移除当前对象的 validErrors 属性
    dartObject.properties.removeWhere((DartProperty property) => property.name == 'validErrors');

    // 递归处理嵌套对象
    for (final DartProperty property in dartObject.properties) {
      final Object propertyType = property.type;
      if (propertyType is DartObject) {
        _removeValidErrorsField(propertyType);
      }
    }

    // 从 allObjects 中移除所有 ValidErrors 类
    allObjects.removeWhere((DartObject obj) =>
        obj.className == 'ValidErrors' ||
        obj.className == 'ValidError' ||
        obj.className.toLowerCase().contains('validerror'));

    // 处理所有子对象,移除 validErrors 属性
    for (final DartObject child in allObjects) {
      if (child != dartObject) {
        child.properties.removeWhere((DartProperty property) =>
            property.name == 'validErrors' ||
            property.name == 'validError');
      }
    }
  }
}

String? formatJson(dynamic jsonData) {
  Map<String, dynamic>? jsonObject;
  if (jsonData is Map) {
    jsonObject = jsonData as Map<String, dynamic>;
  } else if (jsonData is List) {
    jsonObject = jsonData.first as Map<String, dynamic>;
  }
  if (jsonObject != null) {
    return const JsonEncoder.withIndent('  ').convert(jsonObject);
  }
  return null;
}
