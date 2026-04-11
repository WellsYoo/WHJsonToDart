import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_to_dart/utils/openapi_parser.dart';

void main() {
  group('OpenApiParser inline schema support', () {
    late OpenApiParser parser;

    setUpAll(() async {
      final String jsonString =
          await File('test/fixtures/openapi_inline_schema.json').readAsString();
      parser = OpenApiParser.fromJson(jsonString);
    });

    test('resolves inline object response schema into json example', () {
      final Map<String, dynamic>? schemaJson =
          parser.resolveResponseSchemaToJson('/api/servicePlan/purchaseList', 'get');

      expect(schemaJson, isNotNull);
      expect(schemaJson!['status'], false);
      expect(schemaJson['code'], 0);
      expect(schemaJson['msg'], '');
      expect(schemaJson['data'], isA<Map<String, dynamic>>());
      expect(schemaJson['data']['data'], isA<List<dynamic>>());
      expect(schemaJson['data']['page'], 0);
    });

    test('resolves inline array response schema under data', () {
      final Map<String, dynamic>? schemaJson =
          parser.resolveResponseSchemaToJson('/api/servicePlan/getPurchase', 'get');

      expect(schemaJson, isNotNull);
      expect(schemaJson!['data'], isA<List<dynamic>>());
      expect(schemaJson['data'].first, isA<Map<String, dynamic>>());
      expect(schemaJson['data'].first['type'], 0);
      expect(schemaJson['data'].first['name'], '');
    });

    test('returns empty object for empty inline schema', () {
      final Map<String, dynamic>? schemaJson =
          parser.resolveResponseSchemaToJson('/api/servicePlan/submit', 'post');

      expect(schemaJson, isNotNull);
      expect(schemaJson, isEmpty);
    });
  });
}
