import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'static_analysis_config.dart';
import 'wrapper_discovery.dart';

typedef WrapperApproval = Future<bool> Function(
    WrapperCandidate candidate, bool previouslyApproved);

/// Prepares source analysis. Without interaction, only the saved config is read.
class WrapperReview {
  final WrapperDiscovery discovery;
  final DateTime Function() now;
  WrapperReview({WrapperDiscovery? discovery, DateTime Function()? now})
      : discovery = discovery ?? WrapperDiscovery(),
        now = now ?? DateTime.now;

  Future<StaticAnalysisConfig?> prepare({
    required String projectRoot,
    String? configPath,
    required bool interactive,
    required Future<bool> Function() reviewAgain,
    required WrapperApproval approve,
    required void Function(String) output,
  }) async {
    final root = p.normalize(p.absolute(projectRoot));
    final target = File(configPath == null
        ? StaticAnalysisConfig.defaultPathForProjectRoot(root)
        : p.absolute(configPath));
    final original = target.existsSync() ? target.readAsStringSync() : null;
    final existing =
        await StaticAnalysisConfig.load(target.path, projectRoot: root);
    if (!interactive) {
      if (configPath != null && existing == null) {
        throw FormatException('Config file not found: ${target.path}');
      }
      return existing;
    }
    if (existing != null && !await reviewAgain()) return existing;

    output('\nCustom semantics wrappers\n-------------------------');
    output('Searching the project and local path packages...');
    List<WrapperCandidate> candidates;
    try {
      candidates = await discovery.discover(root);
    } on Exception catch (error) {
      output('\nWrapper discovery unavailable: $error');
      output('Continuing analysis with saved mappings.\n');
      return existing;
    }
    final editor =
        YamlEditor(original ?? '# Static accessibility configuration\n');
    if (original == null) editor.update([], <String, dynamic>{});
    final document = loadYaml(original ?? '{}') as YamlMap;
    if (document['semanticWrappers'] == null) {
      editor.update(['semanticWrappers'], <String, dynamic>{});
    }
    final supported =
        candidates.where((candidate) => candidate.mapping != null).length;
    output(
        'Found ${candidates.length} ${candidates.length == 1 ? 'candidate' : 'candidates'}: $supported supported, ${candidates.length - supported} unsupported.');
    final selected = <String>{};
    var number = 0;
    for (final candidate in candidates) {
      number++;
      final mapping = candidate.mapping;
      output('\n  $number. ${candidate.widget}');
      output(
          '     Source: ${p.relative(candidate.file, from: root)}:${candidate.line}');
      if (mapping == null) {
        output('     Status: Unsupported');
        output(_wrapReason(candidate.unsupportedReason ??
            'No supported mapping could be determined.'));
        continue;
      }
      final previous = existing?.registeredWrappers[mapping.identity];
      final unchanged = previous != null &&
          jsonEncode(previous.toJson()) == jsonEncode(mapping.toJson());
      output('     Library: ${mapping.library}');
      output('     Parameters:');
      output('       • ${mapping.label} → Semantics.label');
      output('       • ${mapping.child} → Semantics.child');
      if (previous != null && !unchanged) {
        output(
            '     Mapping changed. Review the updated parameters before including.');
      }
      if (await approve(candidate, unchanged)) {
        output('     Decision: Included');
        selected.add(mapping.identity);
        if (!unchanged) {
          if (previous == null) {
            editor.update(
                ['semanticWrappers', mapping.identity], mapping.toJson());
          } else {
            for (final field in mapping.toJson().entries) {
              editor.update(['semanticWrappers', mapping.identity, field.key],
                  field.value);
            }
          }
        }
      } else {
        output('     Decision: Skipped');
      }
    }
    for (final identity
        in existing?.registeredWrappers.keys ?? const <String>[]) {
      if (!selected.contains(identity)) {
        editor.remove(['semanticWrappers', identity]);
        output(
            '\nRemoved registration: $identity\n  Reason: declined, missing, or unsupported.');
      }
    }
    final timestamp = now().toUtc().toIso8601String();
    if (document['wrapper_review'] == null) {
      editor.update(['wrapper_review'], <String, dynamic>{});
    }
    editor.update(['wrapper_review', 'last_reviewed_at'], timestamp);
    if (original == null) {
      editor.update(
          [],
          wrapAsYamlNode({
            'semanticWrappers': {
              for (final candidate in candidates)
                if (candidate.mapping != null &&
                    selected.contains(candidate.mapping!.identity))
                  candidate.mapping!.identity: candidate.mapping!.toJson(),
            },
            'wrapper_review': {'last_reviewed_at': timestamp},
          }, collectionStyle: CollectionStyle.BLOCK));
    }
    final temporary = await File(
            '${target.path}.tmp-$pid-${DateTime.now().microsecondsSinceEpoch}')
        .create(exclusive: true);
    try {
      await temporary.writeAsString(editor.toString(), flush: true);
      await StaticAnalysisConfig.load(temporary.path, projectRoot: root);
      if ((target.existsSync() ? target.readAsStringSync() : null) !=
          original) {
        throw const FileSystemException(
            'Static configuration changed during review; rerun analysis');
      }
      await temporary.rename(target.path);
    } finally {
      if (temporary.existsSync()) await temporary.delete();
    }
    output('\nWrapper configuration saved');
    output('  Approved: ${selected.length}');
    output('  File:\n    ${target.path}');
    return StaticAnalysisConfig.load(target.path, projectRoot: root);
  }
}

/// Shared terminal adapter for standalone and unified static analysis entrypoints.
Future<StaticAnalysisConfig?> prepareStaticAnalysis(
        {required String projectRoot, String? configPath}) =>
    WrapperReview().prepare(
      projectRoot: projectRoot,
      configPath: configPath,
      interactive: stdin.hasTerminal &&
          stdout.hasTerminal &&
          !Platform.environment.containsKey('CI'),
      reviewAgain: () async {
        stdout.write('\nReview custom semantics wrappers again? [y/N] ');
        final input = stdin.readLineSync();
        if (input == null) {
          throw const FormatException(
              'Wrapper review cancelled; configuration unchanged.');
        }
        final answer = input.trim().toLowerCase();
        return answer == 'y' || answer == 'yes';
      },
      approve: (candidate, previouslyApproved) async {
        stdout.write(
            '\n     Include this wrapper in static analysis? ${previouslyApproved ? '[Y/n]' : '[y/N]'} ');
        final input = stdin.readLineSync();
        if (input == null) {
          throw const FormatException(
              'Wrapper review cancelled; configuration unchanged.');
        }
        final answer = input.trim().toLowerCase();
        return answer == 'y' ||
            answer == 'yes' ||
            (answer.isEmpty && previouslyApproved);
      },
      output: stdout.writeln,
    );

/// Keep the explanatory text readable without splitting paths or parameter names.
String _wrapReason(String reason) {
  const first = '     Reason: ';
  const continuation = '             ';
  final lines = <String>[];
  var line = first;
  for (final word in reason.split(RegExp(r'\s+'))) {
    if (line.length + word.length + 1 > 80 && line.trim() != 'Reason:') {
      lines.add(line.trimRight());
      line = continuation;
    }
    line += '${line.endsWith(' ') ? '' : ' '}$word';
  }
  lines.add(line.trimRight());
  return lines.join('\n');
}
