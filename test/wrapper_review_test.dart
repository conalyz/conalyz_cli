import 'dart:convert';
import 'dart:io';

import 'package:conalyz/src/optimized_ast_analyzer.dart';
import 'package:conalyz/src/platform_type.dart';
import 'package:conalyz/src/static_analysis_config.dart';
import 'package:conalyz/src/wrapper_review.dart';
import 'package:conalyz/src/ast_report_generator.dart';
import 'package:conalyz/src/wrapper_discovery.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late String app;
  late String design;
  void write(String file, String text) {
    File(file)
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }

  const wrapper = '''
import 'package:flutter/widgets.dart' as f;
class CompanySemantics extends f.StatelessWidget {
  final String? accessibilityLabel;
  final f.Widget? content;
  const CompanySemantics({this.accessibilityLabel, this.content});
  @override
  f.Widget build(f.BuildContext context) => f.Semantics(label: accessibilityLabel, child: content);
}
''';
  setUp(() {
    temp = Directory.systemTemp.createTempSync('wrapper_setup_');
    app = p.join(temp.path, 'app');
    design = p.join(temp.path, 'design');
    final flutter = p.join(temp.path, 'flutter');
    write(p.join(flutter, 'pubspec.yaml'), 'name: flutter\n');
    write(p.join(flutter, 'lib/widgets.dart'),
        "export 'src/widgets/basic.dart';\n");
    write(p.join(flutter, 'lib/src/widgets/basic.dart'), '''
class Widget { const Widget(); }
class BuildContext {}
abstract class StatelessWidget extends Widget {
  const StatelessWidget();
  Widget build(BuildContext context);
}
class Semantics extends Widget {
  const Semantics({String? label, Widget? child});
}
class Icon extends Widget { const Icon(Object icon); }
class IconButton extends Widget { const IconButton({Widget? icon, Object? onPressed}); }
class Icons { static const add = 1; }
''');
    write(p.join(app, 'pubspec.yaml'),
        'name: app\ndependencies:\n  design:\n    path: ../design\n  flutter:\n    path: ../flutter\n');
    write(p.join(design, 'pubspec.yaml'),
        'name: design\ndependencies:\n  flutter:\n    path: ../flutter\n');
    final packages = jsonEncode({
      'configVersion': 2,
      'packages': [
        for (final entry
            in {'app': app, 'design': design, 'flutter': flutter}.entries)
          {
            'name': entry.key,
            'rootUri': Directory(entry.value).uri.toString(),
            'packageUri': 'lib/',
            'languageVersion': '3.9'
          }
      ],
    });
    for (final root in [app]) {
      write(p.join(root, '.dart_tool/package_config.json'), packages);
    }
    write(p.join(design, 'lib/company.dart'), wrapper);
    write(p.join(design, 'lib/design.dart'), "export 'company.dart';");
    write(p.join(app, 'lib/main.dart'),
        "import 'package:design/design.dart' as ds;\nimport 'package:flutter/widgets.dart';\nWidget build() => ds.CompanySemantics(accessibilityLabel: 'Add', content: IconButton(icon: Icon(Icons.add), onPressed: () {}));\n");
  });
  tearDown(() => temp.deleteSync(recursive: true));

  Future<StaticAnalysisConfig?> review({
    bool interactive = true,
    Future<bool> Function()? again,
    WrapperApproval? approve,
    void Function(String)? output,
    WrapperDiscovery? discovery,
    String? configPath,
  }) =>
      WrapperReview(discovery: discovery).prepare(
        projectRoot: app,
        configPath: configPath,
        interactive: interactive,
        reviewAgain: again ?? () async => true,
        approve: approve ?? (_, previous) async => true,
        output: output ?? (_) {},
      );

  test('discovers app and local packages by implementation, not class names',
      () async {
    write(p.join(app, 'lib/app_wrapper.dart'),
        wrapper.replaceAll('CompanySemantics', 'AppAccessibility'));
    final candidates = await WrapperDiscovery().discover(app);
    expect(
        candidates.map((c) => c.mapping?.identity),
        containsAll([
          'package:app/app_wrapper.dart#AppAccessibility',
          'package:design/company.dart#CompanySemantics',
        ]));
  });

  test(
      'first run reviews each wrapper type once and saves only approvals together',
      () async {
    write(p.join(app, 'lib/other.dart'),
        wrapper.replaceAll('CompanySemantics', 'AccessibleButton'));
    final visited = <String>[];
    final configuration = await review(
      again: () async => fail('First run must not ask to repeat review'),
      approve: (candidate, previous) async {
        expect(previous, isFalse);
        visited.add(candidate.widget);
        return candidate.widget == 'CompanySemantics';
      },
    );
    expect(visited, unorderedEquals(['AccessibleButton', 'CompanySemantics']));
    expect(configuration!.registeredWrappers.keys,
        ['package:design/company.dart#CompanySemantics']);
    expect(configuration.lastReviewedAt, isNotNull);
  });

  test('a completed review with no approvals still creates the review marker',
      () async {
    final configuration = await review(approve: (_, previous) async => false);
    expect(configuration!.registeredWrappers, isEmpty);
    expect(configuration.lastReviewedAt, isNotNull);
    final spy = _DiscoverySpy();
    await review(
        discovery: spy,
        again: () async => false,
        approve: (_, previous) async => fail('No review'));
    expect(spy.calls, 0);
  });

  test('noninteractive runs never discover, prompt, or create files', () async {
    final spy = _DiscoverySpy();
    expect(
        await review(
            interactive: false,
            discovery: spy,
            again: () async => fail('CI prompt'),
            approve: (_, previous) async => fail('CI approval')),
        isNull);
    expect(spy.calls, 0);
    expect(File(p.join(app, 'conalyz.static.yaml')).existsSync(), isFalse);
    final saved = await review();
    final original = File(saved!.path).readAsStringSync();
    final loaded = await review(
        interactive: false,
        discovery: spy,
        again: () async => fail('CI prompt'),
        approve: (_, previous) async => fail('CI approval'));
    expect(loaded!.registeredWrappers.length, 1);
    expect(File(saved.path).readAsStringSync(), original);
    expect(spy.calls, 0);
  });

  test('declining repeat review reads config without discovery or rewrites',
      () async {
    final saved = await review();
    final original = File(saved!.path).readAsStringSync();
    final spy = _DiscoverySpy();
    var prompts = 0;
    final loaded = await review(
        discovery: spy,
        again: () async {
          prompts++;
          return false;
        });
    expect(prompts, 1);
    expect(spy.calls, 0);
    expect(loaded!.registeredWrappers.length, 1);
    expect(File(saved.path).readAsStringSync(), original);
  });

  test(
      'repeat review updates mappings and preserves unrelated settings and comments',
      () async {
    final file = File(p.join(app, 'conalyz.static.yaml'));
    const header =
        '# Keep policy\nrules: {} # policy comment\ncustom: {keep: true}\n';
    file.writeAsStringSync(header);
    await review();
    write(p.join(design, 'lib/company.dart'),
        wrapper.replaceAll('accessibilityLabel', 'caption'));
    final configuration = await review(approve: (candidate, previous) async {
      expect(previous, isFalse,
          reason: 'Changed mappings need explicit approval');
      return true;
    });
    expect(configuration!.registeredWrappers.values.single.label, 'caption');
    expect(file.readAsStringSync(), contains(header));
  });

  test(
      'repeat review keeps approved wrappers by default and allows removing them',
      () async {
    await review();
    await review(approve: (_, previous) async {
      expect(previous, isTrue);
      return previous;
    });
    final result = await review(approve: (_, previous) async => false);
    expect(result!.registeredWrappers, isEmpty);
  });

  test('missing or unsupported definitions are removed during explicit review',
      () async {
    await review();
    write(
        p.join(design, 'lib/company.dart'),
        wrapper.replaceFirst('label: accessibilityLabel',
            "label: accessibilityLabel ?? 'fallback'"));
    final messages = <String>[];
    final result = await review(
        output: messages.add,
        approve: (_, previous) async => fail('Unsupported'));
    expect(result!.registeredWrappers, isEmpty);
    expect(messages.any((m) => m.contains('Unsupported')), isTrue);
    expect(messages.any((m) => m.contains('Removed registration')), isTrue);
  });

  test('approved identity works through re-exports and labels remain checked',
      () async {
    final config = await review();
    final file = File(p.join(app, 'lib/main.dart'));
    final source = file.readAsStringSync();
    Future<AnalysisResult> analyze(String code) async {
      file.writeAsStringSync(code);
      return OptimizedAstFlutterAccessibilityAnalyzer(configuration: config)
          .analyzeFile(file.path, platform: PlatformType.mobile);
    }

    final good = await analyze(source);
    expect(good.issues.where((i) => i.type == 'Missing IconButton Label'),
        isEmpty);
    expect(good.configuration['semanticWrappers'], isNotEmpty);
    for (final label in ["''", "'   '", 'null']) {
      final result = await analyze(source.replaceFirst("'Add'", label));
      expect(result.issues.where((i) => i.type == 'Missing IconButton Label'),
          hasLength(1));
    }
    final missing =
        await analyze(source.replaceFirst("accessibilityLabel: 'Add', ", ''));
    expect(missing.issues.where((i) => i.type == 'Missing IconButton Label'),
        hasLength(1));
    await AstReportGenerator()
        .generateJsonReport(good, p.join(temp.path, 'report.json'));
    final report =
        jsonDecode(File(p.join(temp.path, 'report.json')).readAsStringSync())
            as Map;
    expect(report['configuration'], good.configuration);
    await AstReportGenerator()
        .generateHtmlReport(good, p.join(temp.path, 'report.html'));
    expect(File(p.join(temp.path, 'report.html')).readAsStringSync(),
        contains('package:design/company.dart#CompanySemantics'));
  });

  test('identical class names in other libraries do not inherit registration',
      () async {
    final config = await review();
    write(p.join(app, 'lib/unrelated.dart'),
        "import 'package:flutter/widgets.dart'; class CompanySemantics extends Widget { const CompanySemantics({String? accessibilityLabel, Widget? content}); }");
    final file = File(p.join(app, 'lib/main.dart'));
    file.writeAsStringSync(file
        .readAsStringSync()
        .replaceFirst('package:design/design.dart', 'unrelated.dart'));
    final result =
        await OptimizedAstFlutterAccessibilityAnalyzer(configuration: config)
            .analyzeFile(file.path, platform: PlatformType.mobile);
    expect(result.issues.where((i) => i.type == 'Missing IconButton Label'),
        hasLength(1));
  });

  test('wrapper labels apply only inside the mapped child argument', () async {
    write(
        p.join(design, 'lib/company.dart'),
        wrapper
            .replaceFirst('final f.Widget? content;',
                'final f.Widget? content; final f.Widget? accessory;')
            .replaceFirst('this.content}', 'this.content, this.accessory}'));
    final config = await review();
    final file = File(p.join(app, 'lib/main.dart'));
    file.writeAsStringSync(file.readAsStringSync().replaceFirst(
        'content: IconButton',
        'content: const Widget(), accessory: IconButton'));
    final result =
        await OptimizedAstFlutterAccessibilityAnalyzer(configuration: config)
            .analyzeFile(file.path, platform: PlatformType.mobile);
    expect(result.issues.where((i) => i.type == 'Missing IconButton Label'),
        hasLength(1));
  });

  test('hosted and git packages are not scanned, local cycles are deduplicated',
      () async {
    write(p.join(design, 'pubspec.yaml'),
        'name: design\ndependencies:\n  app:\n    path: ../app\n  remote:\n    git: https://example.invalid/design.git\n  hosted: ^1.0.0\n');
    expect((await WrapperDiscovery().discover(app)).length, 1);
    write(
        p.join(design, 'lib/company.dart'),
        wrapper.replaceFirst("import 'package:flutter/widgets.dart' as f;",
            "import 'fake.dart' as f;"));
    write(p.join(design, 'lib/fake.dart'),
        'class Semantics { Semantics({Object? label, Object? child}); }');
    expect(await WrapperDiscovery().discover(app), isEmpty);
  });

  test('screen state classes containing Semantics are not wrapper candidates',
      () async {
    write(p.join(app, 'lib/page_state.dart'),
        "import 'package:flutter/widgets.dart'; class PageState { Widget build(BuildContext context) => Semantics(label: 'Screen', child: const Widget()); }");
    final candidates = await WrapperDiscovery().discover(app);
    expect(
        candidates.map((candidate) => candidate.widget), ['CompanySemantics']);
  });

  test('unsupported conditional wrappers are not offered for approval',
      () async {
    write(
        p.join(design, 'lib/company.dart'),
        wrapper.replaceFirst(
            '=> f.Semantics', '=> true ? const f.Widget() : f.Semantics'));
    final result =
        await review(approve: (_, previous) async => fail('Unsupported'));
    expect(result!.registeredWrappers, isEmpty);
  });

  test(
      'malformed config fails without modification; cancelled approval saves nothing',
      () async {
    final file = File(p.join(app, 'conalyz.static.yaml'));
    file.writeAsStringSync('semanticWrappers: [bad');
    await expectLater(review(), throwsA(isA<Exception>()));
    expect(file.readAsStringSync(), 'semanticWrappers: [bad');
    file.deleteSync();
    await expectLater(
        review(
            approve: (_, previous) async =>
                throw const FormatException('cancelled')),
        throwsFormatException);
    expect(file.existsSync(), isFalse);
  });

  test('write failures and concurrent edits leave destination intact',
      () async {
    await expectLater(review(configPath: p.join(app, 'missing/policy.yaml')),
        throwsA(isA<FileSystemException>()));
    expect(File(p.join(app, 'missing/policy.yaml')).existsSync(), isFalse);
    final file = File(p.join(app, 'conalyz.static.yaml'));
    await expectLater(review(approve: (_, previous) async {
      file.writeAsStringSync('# changed elsewhere\ncustom: true\n');
      return true;
    }), throwsA(isA<FileSystemException>()));
    expect(file.readAsStringSync(), '# changed elsewhere\ncustom: true\n');
    expect(Directory(app).listSync().where((f) => f.path.contains('.tmp-')),
        isEmpty);
  });

  test(
      'flow-style configuration and nested unknown wrapper fields survive review',
      () async {
    final config = await review();
    final file = File(config!.path);
    final document = jsonDecode(jsonEncode({
      'custom': true,
      'semanticWrappers': {
        for (final entry in config.registeredWrappers.entries)
          entry.key: {...entry.value.toJson(), 'owner': 'design team'}
      },
    }));
    file.writeAsStringSync('${jsonEncode(document)} # keep this comment\n');
    write(p.join(design, 'lib/company.dart'),
        wrapper.replaceAll('accessibilityLabel', 'caption'));
    final updated = await review();
    expect(updated!.registeredWrappers.values.single.label, 'caption');
    expect(file.readAsStringSync(), contains('design team'));
    expect(file.readAsStringSync(), contains('# keep this comment'));
  });

  test('discovery handles package configuration shared by a workspace',
      () async {
    File(p.join(app, '.dart_tool/package_config.json'))
        .renameSync(p.join(temp.path, 'workspace-package-config.json'));
    Directory(p.join(temp.path, '.dart_tool')).createSync();
    File(p.join(temp.path, 'workspace-package-config.json'))
        .renameSync(p.join(temp.path, '.dart_tool/package_config.json'));
    expect((await WrapperDiscovery().discover(app)).single.mapping, isNotNull);
  });

  test(
      'unavailable package resolution warns and does not record a completed review',
      () async {
    File(p.join(app, '.dart_tool/package_config.json')).deleteSync();
    final messages = <String>[];
    expect(await review(output: messages.add), isNull);
    expect(messages.join(' '), contains('flutter pub get'));
    expect(File(p.join(app, 'conalyz.static.yaml')).existsSync(), isFalse);
  });

  test('CLI noninteractive analysis reads config without discovery or prompts',
      () async {
    final cli = Directory.current.path;
    Future<ProcessResult> command(String output) => Process.run(
        Platform.resolvedExecutable,
        [
          '--packages=${p.join(cli, '.dart_tool/package_config.json')}',
          p.join(cli, 'bin/conalyz.dart'),
          '--dir',
          app,
          '--output',
          output,
          '--no-html'
        ],
        workingDirectory: app,
        environment: {
          'HOME': temp.path,
          'CI': 'true',
          'CONALYZ_NO_ANALYTICS': 'true'
        });
    final first = await command(p.join(temp.path, 'without'));
    expect(first.exitCode, 1, reason: '${first.stdout} ${first.stderr}');
    expect(File(p.join(app, 'conalyz.static.yaml')).existsSync(), isFalse);
    final config = await review();
    final original = File(config!.path).readAsStringSync();
    final result = await command(p.join(temp.path, 'with'));
    expect(result.exitCode, 0, reason: '${result.stdout} ${result.stderr}');
    expect(result.stdout, isNot(contains('Review custom semantics')));
    expect(result.stdout, isNot(contains('Discovering custom')));
    expect(File(config.path).readAsStringSync(), original);
    final report = jsonDecode(
        File(p.join(temp.path, 'with/accessibility_report.json'))
            .readAsStringSync()) as Map;
    expect((report['configuration'] as Map)['semanticWrappers'], isNotEmpty);
  }, timeout: const Timeout(Duration(minutes: 2)));
}

class _DiscoverySpy extends WrapperDiscovery {
  int calls = 0;
  @override
  Future<List<WrapperCandidate>> discover(String projectRoot) async {
    calls++;
    throw StateError('Discovery must not run here');
  }
}
