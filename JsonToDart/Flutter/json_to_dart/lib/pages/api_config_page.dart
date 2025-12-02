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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 顶部：标题栏
          _buildHeader(controller),
          const SizedBox(height: 16.0),

          // 配置表单（可滚动）
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 基础配置卡片
                  _buildSection(
                    title: '基础配置',
                    icon: Icons.settings_outlined,
                    child: Column(
                      children: <Widget>[
                        _buildCompactTextField(
                          label: '方法名',
                          hint: '例如: list',
                          controller: controller.apiConfig.methodName,
                        ),
                        const SizedBox(height: 12.0),
                        _buildCompactTextField(
                          label: '方法注释',
                          hint: '例如: 列表',
                          controller: controller.apiConfig.methodComment,
                        ),
                        const SizedBox(height: 12.0),
                        _buildCompactTextField(
                          label: 'API URL',
                          hint: '例如: /api/v1/user/login',
                          controller: controller.apiConfig.apiUrl,
                        ),
                        const SizedBox(height: 12.0),
                        _buildCompactTextField(
                          label: 'Base URL',
                          hint: "例如: MyEnvConfig.bizUrl + '/api/v1'",
                          controller: controller.apiConfig.baseUrl,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // 请求配置卡片
                  _buildSection(
                    title: '请求配置',
                    icon: Icons.http_outlined,
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  const Text('HTTP 方法', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 6.0),
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
                                  const SizedBox(height: 6.0),
                                  Obx(() => _buildRequestModeDropdown(controller)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12.0),
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
                        const SizedBox(height: 8.0),
                        // Form 提示文本预设
                        Obx(() {
                          if (controller.apiConfig.requestMode.value == ApiRequestMode.form) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Divider(height: 20.0),
                                const Text('提示文本', style: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 8.0),
                                _buildFormTextPresetSelector(controller),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16.0),

                  // JSON 数据卡片
                  _buildSection(
                    title: 'JSON 数据',
                    icon: Icons.code_outlined,
                    child: Column(
                      children: <Widget>[
                        _buildCompactJsonTextField(
                          label: '请求参数 JSON',
                          hint: '请输入请求参数的 JSON 示例',
                          controller: controller.apiConfig.requestJson,
                          maxLines: 5,
                        ),
                        const SizedBox(height: 12.0),
                        Obx(() {
                          if (controller.apiConfig.hasResponse.value) {
                            return _buildCompactJsonTextField(
                              label: '响应参数 JSON',
                              hint: '请输入响应参数的 JSON 示例',
                              controller: controller.apiConfig.responseJson,
                              maxLines: 5,
                            );
                          }
                          return const SizedBox.shrink();
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16.0),
                ],
              ),
            ),
          ),

          // 生成按钮（底部固定）
          const SizedBox(height: 16.0),
          _buildGenerateButton(controller),
        ],
      ),
    );
  }

  // 头部标题栏
  Widget _buildHeader(MainController controller) {
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Icon(Icons.api, color: Colors.blue.shade700, size: 20.0),
        ),
        const SizedBox(width: 12.0),
        const Text(
          'API 代码生成',
          style: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () {
            controller.apiConfig.apiMode.value = false;
            controller.update();
          },
          icon: const Icon(Icons.arrow_back, size: 16.0),
          label: const Text('返回', style: TextStyle(fontSize: 13.0)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          ),
        ),
      ],
    );
  }

  // 生成按钮
  Widget _buildGenerateButton(MainController controller) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await controller.generateApiCode();
        },
        icon: const Icon(Icons.code, size: 20.0),
        label: const Text('生成 API 代码', style: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
    );
  }

  // 分组卡片
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16.0, color: Colors.grey.shade700),
              const SizedBox(width: 8.0),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          child,
        ],
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
        const SizedBox(height: 6.0),
        Obx(() => TextField(
          controller: TextEditingController(text: controller.value)
            ..selection = TextSelection.collapsed(offset: controller.value.length),
          onChanged: (String value) => controller.value = value,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12.0, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
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
        const SizedBox(height: 6.0),
        Obx(() => TextField(
          controller: TextEditingController(text: controller.value)
            ..selection = TextSelection.collapsed(offset: controller.value.length),
          onChanged: (String value) => controller.value = value,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 11.0, color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6.0),
              borderSide: const BorderSide(color: Colors.blue, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12.0),
            isDense: true,
          ),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.0,
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
      borderRadius: BorderRadius.circular(6.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: value ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: value ? Colors.blue.shade200 : Colors.grey.shade300,
          ),
        ),
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
      ),
    );
  }

  // Form 提示文本预设选择器
  Widget _buildFormTextPresetSelector(MainController controller) {
    return Column(
      children: <Widget>[
        Wrap(
          spacing: 6.0,
          runSpacing: 6.0,
          children: FormTextPreset.values.map((FormTextPreset preset) {
            return Obx(() => ChoiceChip(
              label: Text(preset.displayName),
              selected: controller.apiConfig.formTextPreset.value == preset,
              onSelected: (bool selected) {
                if (selected) {
                  controller.apiConfig.formTextPreset.value = preset;
                  if (preset != FormTextPreset.custom) {
                    controller.apiConfig.formLoadText.value = preset.loadText;
                    controller.apiConfig.formSuccessText.value = preset.successText;
                    controller.apiConfig.formErrorText.value = preset.errorText;
                  }
                }
              },
              labelStyle: const TextStyle(fontSize: 11.0),
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 0.0),
            ));
          }).toList(),
        ),
        const SizedBox(height: 10.0),
        Obx(() {
          if (controller.apiConfig.formTextPreset.value == FormTextPreset.custom) {
            return Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: controller.apiConfig.formLoadText.value)
                      ..selection = TextSelection.collapsed(offset: controller.apiConfig.formLoadText.value.length),
                    onChanged: (String value) => controller.apiConfig.formLoadText.value = value,
                    decoration: InputDecoration(
                      labelText: '加载中',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      isDense: true,
                      labelStyle: const TextStyle(fontSize: 11.0),
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
                    decoration: InputDecoration(
                      labelText: '成功',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      isDense: true,
                      labelStyle: const TextStyle(fontSize: 11.0),
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
                    decoration: InputDecoration(
                      labelText: '失败',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      isDense: true,
                      labelStyle: const TextStyle(fontSize: 11.0),
                    ),
                    style: const TextStyle(fontSize: 12.0),
                  ),
                ),
              ],
            );
          }
          return Container(
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.info_outline, size: 14.0, color: Colors.blue.shade700),
                const SizedBox(width: 6.0),
                Expanded(
                  child: Text(
                    '${controller.apiConfig.formLoadText.value} / ${controller.apiConfig.formSuccessText.value} / ${controller.apiConfig.formErrorText.value}',
                    style: TextStyle(fontSize: 11.0, color: Colors.blue.shade900),
                  ),
                ),
              ],
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
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.0),
            borderSide: const BorderSide(color: Colors.blue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
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
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6.0),
            borderSide: const BorderSide(color: Colors.blue, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
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
        controller.apiConfig.requestMode.value = ApiRequestMode.direct;
        break;
      case HttpMethod.post:
        break;
      case HttpMethod.put:
      case HttpMethod.delete:
        controller.apiConfig.requestMode.value = ApiRequestMode.form;
        if (method == HttpMethod.delete) {
          controller.apiConfig.formTextPreset.value = FormTextPreset.delete;
        } else {
          controller.apiConfig.formTextPreset.value = FormTextPreset.submit;
        }
        final FormTextPreset preset = controller.apiConfig.formTextPreset.value;
        controller.apiConfig.formLoadText.value = preset.loadText;
        controller.apiConfig.formSuccessText.value = preset.successText;
        controller.apiConfig.formErrorText.value = preset.errorText;
        break;
    }
  }
}
