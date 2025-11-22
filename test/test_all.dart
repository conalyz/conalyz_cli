import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'flutter_specific_rules_test.dart' as flutter_specific_rules_test;
import 'optimized_ast_analyzer_test.dart' as optimized_ast_analyzer_test;
import 'web_rules_test.dart' as web_rules_test;
import 'usage_storage_service_test.dart' as usage_storage_service_test;
import 'usage_models_test.dart' as usage_models_test;
import 'integration_test.dart' as integration_test;

void main() {
  group('Flutter Access Advisor CLI Tests', () {
    group('Flutter Specific Rules', flutter_specific_rules_test.main);
    group('Optimized AST Analyzer', optimized_ast_analyzer_test.main);
    group('Web Rules', web_rules_test.main);
    group('Usage Storage Service', usage_storage_service_test.main);
    group('Usage Models', usage_models_test.main);
    group('Integration Tests', integration_test.main);
  });
}