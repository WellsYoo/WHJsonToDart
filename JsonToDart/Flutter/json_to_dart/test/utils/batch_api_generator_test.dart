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

    test('inlines request parameters when fewer than three and skips request model when no parameters', () async {
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

      expect(result.respFiles.keys, contains('serviceplan_purchaselist_resp.dart'));
      expect(result.respFiles.keys, contains('serviceplan_getpurchase_resp.dart'));
      expect(result.respFiles.keys, isNot(contains('serviceplan_submit_resp.dart')));
      expect(result.reqFiles.keys, isNot(contains('serviceplan_purchaselist_req.dart')));
      expect(result.reqFiles.keys, isNot(contains('serviceplan_getpurchase_req.dart')));
      expect(result.reqFiles.keys, isNot(contains('serviceplan_submit_req.dart')));
      expect(result.apiFileContent, contains('Future<ServiceplanPurchaselistResp?> servicePlanPurchaseListReq({'));
      expect(result.apiFileContent, contains('required String? type,'));
      expect(result.apiFileContent, contains("'type': type,"));
      expect(result.apiFileContent, contains('Future<ServiceplanGetpurchaseResp?> servicePlanGetPurchaseReq() async {'));
      expect(result.apiFileContent, contains('Future<void> servicePlanSubmitReq() async {'));
    });
  });

  group('BatchApiCodeGenerator query parameter mutation endpoints', () {
    late OpenApiParser parser;
    late List<ParsedApiEndpoint> endpoints;

    setUpAll(() async {
      final String jsonString =
          await File('test/fixtures/openapi_query_params_mutation.json').readAsString();
      parser = OpenApiParser.fromJson(jsonString);
      endpoints = parser.parseEndpoints();
    });

    test('inlines fewer than three request parameters and keeps larger request lists as models', () async {
      final BatchApiCodeGenerator generator = BatchApiCodeGenerator(
        parser: parser,
        endpoints: endpoints,
        baseUrl: "'https://example.com'",
        apiClassName: 'QueryParamsMutationApi',
        modelGenerator: (String jsonString, String className) async {
          return 'class $className {}';
        },
      );

      final BatchApiCodeResult result = await generator.generateAll();

      expect(result.reqFiles.keys, contains('serviceplan_listsubmit_req.dart'));
      expect(result.reqFiles.keys, isNot(contains('serviceplan_listupdate_req.dart')));
      expect(result.reqFiles.keys, isNot(contains('serviceplan_listdelete_req.dart')));
      expect(result.reqFiles.keys, isNot(contains('api_serviceplan_listsubmit_req.dart')));

      expect(result.apiFileContent, contains('required ServiceplanListsubmitReq req,'));
      expect(result.apiFileContent, isNot(contains('ServiceplanListupdateReq req')));
      expect(result.apiFileContent, isNot(contains('ServiceplanListdeleteReq req')));
      expect(result.apiFileContent, isNot(contains('ApiServiceplanListsubmitReq')));

      expect(result.apiFileContent, contains('Future<void> servicePlanListSubmitReq({'));
      expect(result.apiFileContent, contains('Future<void> servicePlanListUpdateReq({'));
      expect(result.apiFileContent, contains('required String? type,'));
      expect(result.apiFileContent, contains('required String? planId,'));
      expect(result.apiFileContent, contains('Future<void> servicePlanListDeleteReq({'));
      expect(result.apiFileContent, contains('required String? id,'));

      expect(result.apiFileContent, contains('await MyHttpUtil().post(servicePlanListSubmitUrl,'));
      expect(result.apiFileContent, contains('await MyHttpUtil().put(servicePlanListUpdateUrl,'));
      expect(result.apiFileContent, contains('await MyHttpUtil().delete(servicePlanListDeleteUrl,'));
      expect(result.apiFileContent, contains('queryParameters: <String, dynamic>{'));
      expect(result.apiFileContent, contains("'type': type,"));
      expect(result.apiFileContent, contains("'plan_id': planId,"));
      expect(result.apiFileContent, contains("'id': id,"));
      expect(result.apiFileContent, isNot(contains('data: req.toJson()..removeWhere((key, value) => value == null)')));
    });
  });

  group('BatchApiCodeGenerator inline query parameters for get endpoints', () {
    test('adds inline parameters to get method signature when fewer than three query parameters', () async {
      final OpenApiDocument document = OpenApiDocument.fromJson(<String, dynamic>{
        'openapi': '3.1.0',
        'info': <String, dynamic>{'title': 'get-inline', 'version': '1.0.0'},
        'paths': <String, dynamic>{
          '/api/servicePlan/search': <String, dynamic>{
            'get': <String, dynamic>{
              'summary': '查询服务计划',
              'parameters': <dynamic>[
                <String, dynamic>{
                  'name': 'type',
                  'in': 'query',
                  'required': true,
                  'schema': <String, dynamic>{'type': 'string'},
                },
                <String, dynamic>{
                  'name': 'plan_id',
                  'in': 'query',
                  'required': false,
                  'schema': <String, dynamic>{'type': 'string'},
                },
              ],
              'responses': <String, dynamic>{
                '200': <String, dynamic>{
                  'description': '成功',
                  'content': <String, dynamic>{
                    'application/json': <String, dynamic>{
                      'schema': <String, dynamic>{
                        'type': 'object',
                        'properties': <String, dynamic>{
                          'data': <String, dynamic>{
                            'type': 'object',
                            'properties': <String, dynamic>{
                              'id': <String, dynamic>{'type': 'string'},
                            },
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        },
        'components': <String, dynamic>{'schemas': <String, dynamic>{}},
      });

      final OpenApiParser parser = OpenApiParser(document);
      final List<ParsedApiEndpoint> endpoints = parser.parseEndpoints();
      final BatchApiCodeGenerator generator = BatchApiCodeGenerator(
        parser: parser,
        endpoints: endpoints,
        baseUrl: "'https://example.com'",
        apiClassName: 'GetInlineApi',
        modelGenerator: (String jsonString, String className) async {
          return 'class $className { $className.fromJson(dynamic json); }';
        },
      );

      final BatchApiCodeResult result = await generator.generateAll();

      expect(result.reqFiles.keys, isNot(contains('serviceplan_search_req.dart')));
      expect(result.apiFileContent, contains('Future<ServiceplanSearchResp?> servicePlanSearchReq({'));
      expect(result.apiFileContent, contains('required String? type,'));
      expect(result.apiFileContent, contains('String? planId,'));
      expect(result.apiFileContent, contains("'type': type,"));
      expect(result.apiFileContent, contains("'plan_id': planId,"));
      expect(result.apiFileContent, isNot(contains('required ServiceplanSearchReq req,')));
    });
  });
}
