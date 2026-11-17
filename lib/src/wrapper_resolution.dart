import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:yaml/yaml.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;

import 'semantic_wrapper.dart';

/// Resolves constructor identities only; never discovers wrapper implementations.
class WrapperResolution {
  final AnalysisContextCollection _contexts;
  final String _root;

  WrapperResolution(String root)
      : _root = p.normalize(p.absolute(root)),
        _contexts = AnalysisContextCollection(
            includedPaths: [p.normalize(p.absolute(root))]);

  Future<ResolvedUnitResult?> resolve(String file) async {
    final absolute = p.normalize(p.absolute(file));
    final result = await _contexts
        .contextFor(_root)
        .currentSession
        .getResolvedUnit(absolute);
    return result is ResolvedUnitResult ? result : null;
  }

  Future<Map<int, SemanticWrapper>> calls(
      String file, Map<String, SemanticWrapper> wrappers) async {
    final unit = await resolve(file);
    if (unit == null) return {};
    final visitor = _Calls(wrappers);
    unit.unit.accept(visitor);
    return visitor.matches;
  }

  Future<void> dispose() => _contexts.dispose();
}

class _Calls extends RecursiveAstVisitor<void> {
  final Map<String, SemanticWrapper> wrappers;
  final matches = <int, SemanticWrapper>{};
  _Calls(this.wrappers);

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final element = node.constructorName.element?.enclosingElement;
    final identity =
        '${element == null ? null : wrapperLibraryIdentity(element.library)}#${element?.name}';
    final wrapper = wrappers[identity];
    if (wrapper != null &&
        (node.constructorName.name == null ||
            node.constructorName.name!.name == 'new')) {
      matches[node.offset] = wrapper;
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Analyzer uses file: URIs for units opened by path and package: URIs for imports.
String? wrapperLibraryIdentity(LibraryElement library) {
  if (library.uri.scheme == 'package') return library.uri.toString();
  if (library.uri.scheme != 'file') return null;
  final file = library.uri.toFilePath();
  var directory = p.dirname(file);
  while (true) {
    final pubspec = File(p.join(directory, 'pubspec.yaml'));
    if (pubspec.existsSync()) {
      final manifest = loadYaml(pubspec.readAsStringSync());
      final lib = p.join(directory, 'lib');
      if (manifest is YamlMap &&
          manifest['name'] is String &&
          p.isWithin(lib, file)) {
        return 'package:${manifest['name']}/${p.split(p.relative(file, from: lib)).join('/')}';
      }
      return null;
    }
    final parent = p.dirname(directory);
    if (parent == directory) return null;
    directory = parent;
  }
}
