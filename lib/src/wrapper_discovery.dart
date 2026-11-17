import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'semantic_wrapper.dart';
import 'wrapper_resolution.dart';

class WrapperCandidate {
  final String widget;
  final String file;
  final int line;
  final SemanticWrapper? mapping;
  final String? unsupportedReason;
  const WrapperCandidate(this.widget, this.file, this.line,
      {this.mapping, this.unsupportedReason});
}

class WrapperDiscovery {
  Future<List<WrapperCandidate>> discover(String projectRoot) async {
    var configRoot = p.absolute(projectRoot);
    while (!File(p.join(configRoot, '.dart_tool', 'package_config.json'))
        .existsSync()) {
      final parent = p.dirname(configRoot);
      if (parent == configRoot) {
        throw const FormatException(
            'Run flutter pub get in the target project before reviewing wrappers.');
      }
      configRoot = parent;
    }
    final roots = <String>{};
    void visit(String root) {
      root = Directory(root).resolveSymbolicLinksSync();
      if (!roots.add(root)) return;
      final manifest = File(p.join(root, 'pubspec.yaml'));
      if (!manifest.existsSync()) {
        throw FormatException('No pubspec.yaml in $root');
      }
      final yaml = loadYaml(manifest.readAsStringSync());
      if (yaml is! YamlMap) {
        throw FormatException('Invalid pubspec.yaml in $root');
      }
      final dependencies = <String, dynamic>{};
      for (final section in [
        'dependencies',
        'dev_dependencies',
        'dependency_overrides'
      ]) {
        final values = yaml[section];
        if (values is YamlMap) {
          for (final entry in values.entries) {
            dependencies[entry.key as String] = entry.value;
          }
        }
      }
      for (final dependency in dependencies.values) {
        if (dependency is YamlMap && dependency['path'] is String) {
          visit(p.normalize(p.join(root, dependency['path'] as String)));
        }
      }
    }

    visit(p.absolute(projectRoot));
    final candidates = <WrapperCandidate>[];
    final resolver = WrapperResolution(projectRoot);
    try {
      for (final root in roots) {
        final lib = Directory(p.join(root, 'lib'));
        if (!lib.existsSync()) continue;
        final files = lib
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
        for (final file in files) {
          final result = await resolver.resolve(file.path);
          if (result == null) continue;
          for (final declaration
              in result.unit.declarations.whereType<ClassDeclaration>()) {
            final element = declaration.declaredFragment?.element;
            // Screens' State objects can contain Semantics without being
            // reusable widget wrappers themselves.
            if (element == null ||
                !element.allSupertypes.any((type) =>
                    const {'StatelessWidget', 'StatefulWidget'}
                        .contains(type.element.name) &&
                    type.element.library.uri
                        .toString()
                        .startsWith('package:flutter/'))) {
              continue;
            }
            final semantics = _SemanticsCalls();
            declaration.accept(semantics);
            if (semantics.calls.isEmpty) continue;
            final name = element.name ?? '<unknown>';
            SemanticWrapper? mapping;
            if (wrapperLibraryIdentity(element.library) != null &&
                semantics.calls.length == 1) {
              final members =
                  declaration.body.childEntities.whereType<AstNode>().toList();
              final builds = members
                  .whereType<MethodDeclaration>()
                  .where((m) => m.name.lexeme == 'build')
                  .toList();
              Expression? returned;
              if (builds.length == 1 && !builds.single.isStatic) {
                final body = builds.single.body;
                if (body is ExpressionFunctionBody) returned = body.expression;
                if (body is BlockFunctionBody &&
                    body.block.statements.length == 1 &&
                    body.block.statements.single is ReturnStatement) {
                  returned = (body.block.statements.single as ReturnStatement)
                      .expression;
                }
              }
              final call = semantics.calls.single;
              final arguments = <String, Expression>{
                for (final arg
                    in call.argumentList.arguments.whereType<NamedArgument>())
                  arg.name.lexeme: arg.argumentExpression,
              };
              String? field(Expression? expression) {
                final identifier = expression is SimpleIdentifier
                    ? expression
                    : expression is PropertyAccess &&
                            expression.target is ThisExpression
                        ? expression.propertyName
                        : null;
                final getter = identifier?.element;
                if (getter is GetterElement &&
                    getter.variable is FieldElement &&
                    getter.enclosingElement == element) {
                  return getter.name;
                }
                return null;
              }

              final label = field(arguments['label']);
              final child = field(arguments['child']);
              final constructors =
                  members.whereType<ConstructorDeclaration>().toList();
              final fields = members
                  .whereType<FieldDeclaration>()
                  .where((f) => f.fields.isFinal)
                  .expand((f) => f.fields.variables)
                  .map((v) => v.name.lexeme)
                  .toSet();
              bool directConstructor = constructors.length == 1;
              if (directConstructor) {
                final constructor = constructors.single;
                final parameters = constructor.parameters.parameters;
                directConstructor = constructor.factoryKeyword == null &&
                    constructor.name == null &&
                    constructor.body is EmptyFunctionBody &&
                    constructor.initializers
                        .every((i) => i is SuperConstructorInvocation) &&
                    [label, child].every((name) =>
                        name != null &&
                        fields.contains(name) &&
                        parameters.any((param) =>
                            param is FieldFormalParameter &&
                            param.isNamed &&
                            param.name.lexeme == name));
              }
              if (identical(returned, call) &&
                  label != null &&
                  child != null &&
                  label != child &&
                  directConstructor &&
                  element.allSupertypes.any((type) =>
                      type.element.name == 'StatelessWidget' &&
                      type.element.library.uri
                          .toString()
                          .startsWith('package:flutter/'))) {
                mapping = SemanticWrapper(
                    widget: name,
                    library: wrapperLibraryIdentity(element.library)!,
                    label: label,
                    child: child);
              }
            }
            candidates.add(WrapperCandidate(name, file.path,
                result.lineInfo.getLocation(declaration.offset).lineNumber,
                mapping: mapping,
                unsupportedReason: mapping == null
                    ? 'Only an unconditional, direct Semantics return with final label/child fields and one unnamed forwarding constructor is supported.'
                    : null));
          }
        }
      }
    } finally {
      await resolver.dispose();
    }
    return candidates;
  }
}

class _SemanticsCalls extends RecursiveAstVisitor<void> {
  final calls = <InstanceCreationExpression>[];
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.element?.enclosingElement;
    if (type?.name == 'Semantics' &&
        type!.library.uri.toString() ==
            'package:flutter/src/widgets/basic.dart') {
      calls.add(node);
    }
    super.visitInstanceCreationExpression(node);
  }
}
