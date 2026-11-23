import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('explicit SDK supports AOT discovery, review and registered labels',
      () async {
    final temp = Directory(Directory.systemTemp
        .createTempSync('compiled_wrappers_')
        .resolveSymbolicLinksSync());
    addTearDown(() => temp.delete(recursive: true));
    void write(String path, String content) {
      File(path)
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    final project = p.join(temp.path, 'app');
    final flutter = p.join(temp.path, 'flutter');
    write(p.join(project, 'pubspec.yaml'), 'name: demo\n');
    write(
        p.join(project, '.dart_tool/package_config.json'),
        jsonEncode({
          'configVersion': 2,
          'packages': [
            for (final entry in {'demo': project, 'flutter': flutter}.entries)
              {
                'name': entry.key,
                'rootUri': Directory(entry.value).uri.toString(),
                'packageUri': 'lib/',
                'languageVersion': '3.9'
              }
          ],
        }));
    write(p.join(flutter, 'pubspec.yaml'), 'name: flutter\n');
    write(p.join(flutter, 'lib/widgets.dart'),
        "export 'src/widgets/basic.dart';");
    write(p.join(flutter, 'lib/src/widgets/basic.dart'), '''
class Widget { const Widget(); }
class BuildContext {}
abstract class StatelessWidget extends Widget {
  const StatelessWidget();
  Widget build(BuildContext context);
}
class Semantics extends Widget { const Semantics({String? label, Widget? child}); }
class Icon extends Widget { const Icon(Object icon); }
class IconButton extends Widget { const IconButton({Widget? icon, Object? onPressed}); }
class Icons { static const add = 1; }
''');
    write(p.join(project, 'lib/wrapper.dart'), '''
import 'package:flutter/widgets.dart';
class CompanySemantics extends StatelessWidget {
  final String? caption;
  final Widget? content;
  const CompanySemantics({this.caption, this.content});
  Widget build(BuildContext context) => Semantics(label: caption, child: content);
}
''');
    final mainFile = p.join(project, 'lib/main.dart');
    const source =
        "import 'wrapper.dart';\nimport 'package:flutter/widgets.dart';\nWidget build() => CompanySemantics(caption: 'Add', content: IconButton(icon: Icon(Icons.add), onPressed: () {}));";
    write(mainFile, source);
    final probe = p.join(temp.path, 'probe.dart');
    write(probe, r'''
import 'dart:convert';
import 'package:conalyz/src/wrapper_discovery.dart';
import 'package:conalyz/src/wrapper_review.dart';
import 'package:conalyz/src/optimized_ast_analyzer.dart';
import 'package:conalyz/src/platform_type.dart';
Future<void> main(List<String> args) async {
  final root = args[0];
  final sdkPath = args[1];
  final candidates = await WrapperDiscovery(sdkPath: sdkPath).discover(root);
  final wrapper = candidates.single.mapping!;
  final config = await WrapperReview(sdkPath: sdkPath).prepare(
      projectRoot: root, interactive: true, reviewAgain: () async => true,
      approve: (_, __) async => true, output: (_) {});
  final engine = OptimizedAstFlutterAccessibilityAnalyzer(configuration: config, sdkPath: sdkPath);
  final result = await engine.analyzeFile('$root/lib/main.dart', platform: PlatformType.mobile);
  final projectResult = await engine.analyzeProject('$root/lib', platform: PlatformType.mobile);
  if (result.issues.length != projectResult.issues.length) throw StateError('File/project mismatch');
  print(jsonEncode({'wrapper': wrapper.identity, 'lines': result.linesScanned,
    'missingLabels': result.issues.where((issue) => issue.rule == 'iconbutton-accessibility').length}));
}
''');
    final binary =
        p.join(temp.path, Platform.isWindows ? 'probe.exe' : 'probe');
    final compilation = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'exe',
      '--packages=${p.absolute('.dart_tool/package_config.json')}',
      probe,
      '-o',
      binary,
    ]);
    expect(compilation.exitCode, 0,
        reason: '${compilation.stdout}\n${compilation.stderr}');
    final sdkBin =
        p.dirname(File(Platform.resolvedExecutable).resolveSymbolicLinksSync());
    Future<Map<String, dynamic>> run() async {
      final result = await Process.run(binary, [project, p.dirname(sdkBin)],
          environment: {'PATH': ''});
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stderr.toString(), isEmpty);
      return jsonDecode(result.stdout.toString().trim())
          as Map<String, dynamic>;
    }

    final labeled = await run();
    expect(File(p.join(project, 'conalyz.static.yaml')).readAsStringSync(),
        isNot(contains(p.dirname(sdkBin))));
    expect(labeled['wrapper'], 'package:demo/wrapper.dart#CompanySemantics');
    expect(labeled['lines'], greaterThan(0));
    expect(labeled['missingLabels'], 0);
    write(mainFile, source.replaceFirst("caption: 'Add', ", ''));
    expect((await run())['missingLabels'], 1);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
