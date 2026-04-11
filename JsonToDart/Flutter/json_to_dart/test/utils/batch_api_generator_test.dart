import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_to_dart/models/openapi_document.dart';
import 'package:json_to_dart/utils/batch_api_generator.dart';
import 'package:json_to_dart/utils/openapi_parser.dart';

void main() {
  group('BatchApiCodeGenerator inline response models', () {
    late OpenApiParser parser;
    late List<ParsedApiEndpoint> endpoints;

    setUpAll(() async {
      final String jsonString =
          await File('test/fixtures/openapi_inline_schema.json').readAsString();
      parser = OpenApiParser.fromJson(jsonString);
      endpoints = parser.parseEndpoints();
    });

    test('generates response files for inline response schemas', () async {
      final BatchApiCodeGenerator generator = BatchApiCodeGenerator(
        parser: parser,
        endpoints: endpoints,
        baseUrl: "'https://example.com'",
        apiClassName: 'InlineSchemaApi',
        modelGenerator: (String jsonString, String className) async {
          return 'class $className {}';
        },
      );

      final BatchApiCodeResult result = await generator.generateAll();

      expect(result.respFiles.keys, contains('api_serviceplan_purchaselist_resp.dart'));
      expect(result.respFiles.keys, contains('api_serviceplan_getpurchase_resp.dart'));
      expect(result.respFiles.keys, isNot(contains('api_serviceplan_submit_resp.dart')));
      expect(result.apiFileContent, isNot(contains('ApiServiceplanSubmitResp')));
      expect(result.apiFileContent, contains('Future<dynamic> servicePlanSubmitReq({'));
    });
  });
}
