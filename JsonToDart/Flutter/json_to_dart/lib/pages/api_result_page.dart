import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:json_to_dart/main_controller.dart';
import 'package:json_to_dart/utils/api_code_generator.dart';

/// API 生成结果展示界面
class ApiResultPage extends StatelessWidget {
  const ApiResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final MainController controller = Get.find<MainController>();

    return GetBuilder<MainController>(
      builder: (MainController c) {
        final ApiCodeGenerationResult? result = c.apiCodeGenerationResult;

        if (result == null) {
          return const Center(
            child: Text(
              '请先配置并生成 API 代码',
              style: TextStyle(fontSize: 14.0, color: Colors.grey),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // 顶部操作栏 (紧凑)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    '生成结果',
                    style: TextStyle(
                      fontSize: 16.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => controller.copyAllApiCode(),
                    icon: const Icon(Icons.copy_all, size: 16.0),
                    label: const Text('复制所有', style: TextStyle(fontSize: 12.0)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              // 文件列表 (紧凑展示)
              Expanded(
                child: ListView(
                  children: <Widget>[
                    // 请求参数 Model
                    _buildCompactCodeCard(
                      title: result.requestFileName,
                      code: result.requestModelCode,
                      onCopy: () => controller.copyFileCode(
                        result.requestModelCode,
                        result.requestFileName,
                      ),
                    ),
                    const SizedBox(height: 10.0),

                    // 响应参数 Model (如果有)
                    if (result.responseModelCode.isNotEmpty) ...<Widget>[
                      _buildCompactCodeCard(
                        title: result.responseFileName,
                        code: result.responseModelCode,
                        onCopy: () => controller.copyFileCode(
                          result.responseModelCode,
                          result.responseFileName,
                        ),
                      ),
                      const SizedBox(height: 10.0),
                    ],

                    // API 方法
                    _buildCompactCodeCard(
                      title: result.apiFileName,
                      code: result.apiMethodCode,
                      onCopy: () => controller.copyFileCode(
                        result.apiMethodCode,
                        result.apiFileName,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactCodeCard({
    required String title,
    required String code,
    required VoidCallback onCopy,
  }) {
    return Card(
      elevation: 1.0,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 文件头部 (紧凑)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4.0),
                topRight: Radius.circular(4.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16.0),
                  onPressed: onCopy,
                  tooltip: '复制代码',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // 代码内容 (缩小高度)
          Container(
            constraints: const BoxConstraints(maxHeight: 150.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
