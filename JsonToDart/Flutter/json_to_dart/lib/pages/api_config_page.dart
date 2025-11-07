import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:json_to_dart/main_controller.dart';
import 'package:json_to_dart/models/api_config.dart';

/// API 配置输入界面
class ApiConfigPage extends StatelessWidget {
  const ApiConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    final MainController controller = Get.find<MainController>();

    return Container(
      padding: const EdgeInsets.all(12.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 标题和模式切换
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'API 代码生成',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 返回普通模式按钮
                TextButton.icon(
                  onPressed: () {
                    controller.apiConfig.apiMode.value = false;
                    controller.update();
                  },
                  icon: const Icon(Icons.arrow_back, size: 18.0),
                  label: const Text('返回', style: TextStyle(fontSize: 13.0)),
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            // 基础配置
            _buildCompactTextField(
              label: '方法名',
              hint: '例如: list',
              controller: controller.apiConfig.methodName,
            ),
            const SizedBox(height: 10.0),

            _buildCompactTextField(
              label: '方法注释',
              hint: '例如: 列表',
              controller: controller.apiConfig.methodComment,
            ),
            const SizedBox(height: 10.0),

            _buildCompactTextField(
              label: 'API URL',
              hint: '例如: /api/v1/user/login',
              controller: controller.apiConfig.apiUrl,
            ),
            const SizedBox(height: 10.0),

            _buildCompactTextField(
              label: 'Base URL',
              hint: "例如: MyEnvConfig.bizUrl + '/api/v1'",
              controller: controller.apiConfig.baseUrl,
            ),
            const SizedBox(height: 12.0),

            // HTTP 方法和请求模式 (紧凑显示)
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('HTTP 方法', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4.0),
                      Obx(() => _buildHttpMethodDropdown(controller)),
                    ],
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('请求模式', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4.0),
                      Obx(() => _buildRequestModeDropdown(controller)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            // Form 提示文本预设 (只在 Form 模式下显示)
            Obx(() {
              if (controller.apiConfig.requestMode.value == ApiRequestMode.form) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('提示文本', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4.0),
                    _buildFormTextPresetSelector(controller),
                    const SizedBox(height: 12.0),
                  ],
                );
              }
              return const SizedBox.shrink();
            }),

            // 选项复选框 (紧凑布局)
            Obx(() => Row(
              children: <Widget>[
                Expanded(
                  child: _buildCompactCheckbox(
                    label: 'sprintf URL',
                    value: controller.apiConfig.useSprintfUrl.value,
                    onChanged: (bool? value) {
                      controller.apiConfig.useSprintfUrl.value = value ?? false;
                    },
                  ),
                ),
                Expanded(
                  child: _buildCompactCheckbox(
                    label: '有响应',
                    value: controller.apiConfig.hasResponse.value,
                    onChanged: (bool? value) {
                      controller.apiConfig.hasResponse.value = value ?? true;
                    },
                  ),
                ),
              ],
            )),
            const SizedBox(height: 12.0),

            // 请求参数 JSON
            _buildCompactJsonTextField(
              label: '请求参数 JSON',
              hint: '请输入请求参数的 JSON 示例',
              controller: controller.apiConfig.requestJson,
              maxLines: 6,
            ),
            const SizedBox(height: 10.0),

            // 响应参数 JSON (根据 hasResponse 显示/隐藏)
            Obx(() {
              if (controller.apiConfig.hasResponse.value) {
                return Column(
                  children: <Widget>[
                    _buildCompactJsonTextField(
                      label: '响应参数 JSON',
                      hint: '请输入响应参数的 JSON 示例',
                      controller: controller.apiConfig.responseJson,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 12.0),
                  ],
                );
              }
              return const SizedBox.shrink();
            }),

            // 生成按钮
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await controller.generateApiCode();
                },
                icon: const Icon(Icons.code, size: 18.0),
                label: const Text('生成 API 代码'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 12.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 紧凑型文本输入框
  Widget _buildCompactTextField({
    required String label,
    required String hint,
    required RxString controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12.0,
          ),
        ),
        const SizedBox(height: 4.0),
        Obx(() => TextField(
          controller: TextEditingController(text: controller.value)
            ..selection = TextSelection.collapsed(offset: controller.value.length),
          onChanged: (String value) => controller.value = value,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 8.0,
            ),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13.0),
        )),
      ],
    );
  }

  // 紧凑型 JSON 输入框
  Widget _buildCompactJsonTextField({
    required String label,
    required String hint,
    required RxString controller,
    int maxLines = 8,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12.0,
          ),
        ),
        const SizedBox(height: 4.0),
        Obx(() => TextField(
          controller: TextEditingController(text: controller.value)
            ..selection = TextSelection.collapsed(offset: controller.value.length),
          onChanged: (String value) => controller.value = value,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.all(10.0),
            isDense: true,
          ),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11.0,
          ),
        )),
      ],
    );
  }

  // 紧凑型复选框
  Widget _buildCompactCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Checkbox(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Text(label, style: const TextStyle(fontSize: 12.0)),
        ],
      ),
    );
  }

  // Form 提示文本预设选择器
  Widget _buildFormTextPresetSelector(MainController controller) {
    return Column(
      children: <Widget>[
        // 预设选择
        Wrap(
          spacing: 8.0,
          children: FormTextPreset.values.map((FormTextPreset preset) {
            return Obx(() => ChoiceChip(
              label: Text(preset.displayName),
              selected: controller.apiConfig.formTextPreset.value == preset,
              onSelected: (bool selected) {
                if (selected) {
                  controller.apiConfig.formTextPreset.value = preset;
                  // 自动填充预设文本
                  if (preset != FormTextPreset.custom) {
                    controller.apiConfig.formLoadText.value = preset.loadText;
                    controller.apiConfig.formSuccessText.value = preset.successText;
                    controller.apiConfig.formErrorText.value = preset.errorText;
                  }
                }
              },
              labelStyle: const TextStyle(fontSize: 12.0),
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0.0),
            ));
          }).toList(),
        ),
        const SizedBox(height: 8.0),
        // 自定义输入框 (只在选择"自定义"时显示)
        Obx(() {
          if (controller.apiConfig.formTextPreset.value == FormTextPreset.custom) {
            return Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: controller.apiConfig.formLoadText.value)
                          ..selection = TextSelection.collapsed(offset: controller.apiConfig.formLoadText.value.length),
                        onChanged: (String value) => controller.apiConfig.formLoadText.value = value,
                        decoration: const InputDecoration(
                          labelText: '加载中',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                          isDense: true,
                          labelStyle: TextStyle(fontSize: 11.0),
                        ),
                        style: const TextStyle(fontSize: 12.0),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: controller.apiConfig.formSuccessText.value)
                          ..selection = TextSelection.collapsed(offset: controller.apiConfig.formSuccessText.value.length),
                        onChanged: (String value) => controller.apiConfig.formSuccessText.value = value,
                        decoration: const InputDecoration(
                          labelText: '成功',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                          isDense: true,
                          labelStyle: TextStyle(fontSize: 11.0),
                        ),
                        style: const TextStyle(fontSize: 12.0),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: controller.apiConfig.formErrorText.value)
                          ..selection = TextSelection.collapsed(offset: controller.apiConfig.formErrorText.value.length),
                        onChanged: (String value) => controller.apiConfig.formErrorText.value = value,
                        decoration: const InputDecoration(
                          labelText: '失败',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                          isDense: true,
                          labelStyle: TextStyle(fontSize: 11.0),
                        ),
                        style: const TextStyle(fontSize: 12.0),
                      ),
                    ),
                  ],
                ),
              ],
            );
          }
          // 显示当前预设的文本
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              '${controller.apiConfig.formLoadText.value} / ${controller.apiConfig.formSuccessText.value} / ${controller.apiConfig.formErrorText.value}',
              style: const TextStyle(fontSize: 11.0, color: Colors.grey),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildHttpMethodDropdown(MainController controller) {
    return SizedBox(
      width: double.infinity,
      child: DropdownButtonFormField<HttpMethod>(
        value: controller.apiConfig.httpMethod.value,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          isDense: true,
        ),
        onChanged: (HttpMethod? newValue) {
          if (newValue != null) {
            controller.apiConfig.httpMethod.value = newValue;
            _autoSetRequestMode(controller, newValue);
          }
        },
        items: HttpMethod.values.map<DropdownMenuItem<HttpMethod>>((HttpMethod method) {
          return DropdownMenuItem<HttpMethod>(
            value: method,
            child: Text(method.name, style: const TextStyle(fontSize: 13.0)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRequestModeDropdown(MainController controller) {
    return SizedBox(
      width: double.infinity,
      child: DropdownButtonFormField<ApiRequestMode>(
        value: controller.apiConfig.requestMode.value,
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          isDense: true,
        ),
        onChanged: (ApiRequestMode? newValue) {
          if (newValue != null) {
            controller.apiConfig.requestMode.value = newValue;
          }
        },
        items: ApiRequestMode.values.map<DropdownMenuItem<ApiRequestMode>>((ApiRequestMode mode) {
          return DropdownMenuItem<ApiRequestMode>(
            value: mode,
            child: Text(mode.displayName, style: const TextStyle(fontSize: 13.0)),
          );
        }).toList(),
      ),
    );
  }

  /// 根据 HTTP 方法智能设置请求模式
  void _autoSetRequestMode(MainController controller, HttpMethod method) {
    switch (method) {
      case HttpMethod.get:
        // GET 通常用于查询,使用直接请求模式
        controller.apiConfig.requestMode.value = ApiRequestMode.direct;
        break;
      case HttpMethod.post:
        // POST 可能是查询或添加,保持当前选择
        break;
      case HttpMethod.put:
      case HttpMethod.delete:
        // PUT 和 DELETE 通常用于修改和删除,使用 Form 模式
        controller.apiConfig.requestMode.value = ApiRequestMode.form;
        // 根据方法设置预设
        if (method == HttpMethod.delete) {
          controller.apiConfig.formTextPreset.value = FormTextPreset.delete;
        } else {
          controller.apiConfig.formTextPreset.value = FormTextPreset.submit;
        }
        // 应用预设文本
        final FormTextPreset preset = controller.apiConfig.formTextPreset.value;
        controller.apiConfig.formLoadText.value = preset.loadText;
        controller.apiConfig.formSuccessText.value = preset.successText;
        controller.apiConfig.formErrorText.value = preset.errorText;
        break;
    }
  }
}
