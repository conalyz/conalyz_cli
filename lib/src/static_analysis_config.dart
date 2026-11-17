import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'semantic_wrapper.dart';

/// Static wrapper configuration; rule policy is a separate feature.
class StaticAnalysisConfig {
  final String path;
  final String projectRoot;
  final Map<String, SemanticWrapper> registeredWrappers;
  final DateTime? lastReviewedAt;

  const StaticAnalysisConfig({
    required this.path,
    required this.projectRoot,
    this.registeredWrappers = const {},
    this.lastReviewedAt,
  });

  static Future<StaticAnalysisConfig?> load(String filePath,
      {required String projectRoot}) async {
    final file = File(filePath);
    if (!await file.exists()) return null;
    final document = loadYaml(await file.readAsString());
    if (document is! YamlMap) {
      throw const FormatException(
          'Static configuration root must be a mapping');
    }
    final wrappers = <String, SemanticWrapper>{};
    final raw = document['semanticWrappers'];
    if (raw != null) {
      if (raw is! YamlMap) {
        throw const FormatException('semanticWrappers must be a mapping');
      }
      for (final entry in raw.entries) {
        final value = entry.value;
        if (entry.key is! String || value is! YamlMap) {
          throw const FormatException('Each wrapper must be a mapping');
        }
        for (final field in ['widget', 'library', 'label', 'child']) {
          if (value[field] is! String ||
              (value[field] as String).trim().isEmpty) {
            throw FormatException(
                '${entry.key}.$field must be a nonempty string');
          }
        }
        final wrapper = SemanticWrapper(
          widget: value['widget'] as String,
          library: value['library'] as String,
          label: value['label'] as String,
          child: value['child'] as String,
        );
        final uri = Uri.tryParse(wrapper.library);
        if (entry.key != wrapper.identity ||
            uri?.scheme != 'package' ||
            !uri!.path.contains('/') ||
            wrapper.label == wrapper.child ||
            [wrapper.widget, wrapper.label, wrapper.child].any((name) =>
                !RegExp(r'^[a-zA-Z_$][a-zA-Z0-9_$]*$').hasMatch(name))) {
          throw FormatException(
              'Invalid wrapper identity or parameters: ${entry.key}');
        }
        wrappers[wrapper.identity] = wrapper;
      }
    }
    DateTime? reviewed;
    final review = document['wrapper_review'];
    if (review != null) {
      if (review is! YamlMap ||
          review['last_reviewed_at'] is! String ||
          (reviewed =
                  DateTime.tryParse(review['last_reviewed_at'] as String)) ==
              null) {
        throw const FormatException(
            'wrapper_review.last_reviewed_at must be an ISO timestamp');
      }
    }
    return StaticAnalysisConfig(
        path: p.absolute(filePath),
        projectRoot: p.absolute(projectRoot),
        registeredWrappers: Map.unmodifiable(wrappers),
        lastReviewedAt: reviewed);
  }

  static String defaultPathForProjectRoot(String root) =>
      p.join(p.absolute(root), 'conalyz.static.yaml');

  static String resolveProjectRootForFile(String filePath) {
    var root = FileSystemEntity.isDirectorySync(filePath)
        ? p.absolute(filePath)
        : p.dirname(p.absolute(filePath));
    final fallback = root;
    while (!File(p.join(root, 'pubspec.yaml')).existsSync()) {
      final parent = p.dirname(root);
      if (parent == root) return fallback;
      root = parent;
    }
    return root;
  }

  Map<String, dynamic> toMetadata() => {
        'path': p.relative(path, from: projectRoot),
        if (lastReviewedAt != null)
          'wrapper_review': {
            'last_reviewed_at': lastReviewedAt!.toUtc().toIso8601String()
          },
        'semanticWrappers': {
          for (final entry in registeredWrappers.entries)
            entry.key: entry.value.toJson()
        },
      };
}
