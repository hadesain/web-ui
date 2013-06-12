// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This is a helper for run.sh. We try to run all of the Dart code in one
 * instance of the Dart VM to reduce warm-up time.
 */
library web_ui.testing.render_test;

import 'dart:io';
import 'dart:math' show min;
import 'package:args/args.dart';
import 'package:pathos/path.dart' as path;
import 'package:unittest/unittest.dart';
import 'package:web_ui/dwc.dart' as dwc;

void renderTests(String baseDir, String inputDir, String expectedDir,
    String outDir, [List<String> arguments, String script]) {

  if (arguments == null) arguments = new Options().arguments;
  if (script == null) script = new Options().script;

  var args = _parseArgs(arguments, script);
  if (args == null) exit(1);

  var pattern = new RegExp(args.rest.length > 0 ? args.rest[0] : '.');

  var scriptDir = path.absolute(path.dirname(script));
  baseDir = path.join(scriptDir, baseDir);
  inputDir = path.join(scriptDir, inputDir);
  expectedDir = path.join(scriptDir, expectedDir);
  outDir = path.join(scriptDir, outDir);

  var paths = new Directory(inputDir).listSync()
      .where((f) => f is File).map((f) => f.path)
      .where((p) => p.endsWith('_test.html') && pattern.hasMatch(p));

  if (paths.isEmpty) return;

  // First clear the output folder. Otherwise we can miss bugs when we fail to
  // generate a file.
  var dir = new Directory(outDir);
  if (dir.existsSync()) {
    print('Cleaning old output for ${path.normalize(outDir)}');
    dir.deleteSync(recursive: true);
  }
  dir.createSync();

  for (var filePath in paths) {
    var filename = path.basename(filePath);
    test('compile $filename', () {
      expect(dwc.run(['-o', outDir, '--basedir', baseDir, filePath],
        printTime: false)
        .then((res) {
          expect(res.messages.length, 0, reason: res.messages.join('\n'));
        }), completes);
    });
  }

  var filenames = paths.map(path.basename).toList();
  // Sort files to match the order in which run.sh runs diff.
  filenames.sort();

  // Get the path from "input" relative to "baseDir"
  var relativeToBase = path.relative(inputDir, from: baseDir);
  var finalOutDir = path.join(outDir, relativeToBase);

  runTests(String search) {
    var outs;

    test('content_shell run $search', () {
      var args = ['--dump-render-tree'];
      args.addAll(filenames.map((name) => 'file://$finalOutDir/$name$search'));
      expect(Process.run('content_shell', args).then((res) {
        expect(res.exitCode, 0, reason: 'content_shell exit code: '
            '${res.exitCode}. Contents of stderr: \n${res.stderr}');
        outs = res.stdout.split('#EOF\n')
          .where((s) => !s.trim().isEmpty).toList();
        expect(outs.length, filenames.length);
      }), completes);
    });

    for (int i = 0; i < filenames.length; i++) {
      var filename = filenames[i];
      // TODO(sigmund): remove this extra variable dartbug.com/8698
      int j = i;
      test('verify $filename $search', () {
        expect(outs, isNotNull, reason:
          'Output not available, maybe content_shell failed to run.');
        var output = outs[j];
        var outPath = path.join(outDir, '$filename.txt');
        var expectedPath = path.join(expectedDir, '$filename.txt');
        new File(outPath).writeAsStringSync(output);
        var expected = new File(expectedPath).readAsStringSync();
        expect(output, new SmartStringMatcher(expected),
          reason: 'unexpected output for <$filename>');
      });
    }
  }

  bool compiled = false;
  ensureCompileToJs() {
    if (compiled) return;
    compiled = true;

    for (var filename in filenames) {
      test('dart2js $filename', () {
        // TODO(jmesserly): this depends on web_ui's output scheme.
        // Alternatively we could use html5lib to find the script tag.
        var inPath = '${filename}_bootstrap.dart';
        var outPath = '${inPath}.js';

        inPath = path.join(finalOutDir, inPath);
        outPath = path.join(finalOutDir, outPath);

        expect(Process.run('dart2js', ['-o$outPath', inPath]).then((res) {
          expect(res.exitCode, 0, reason: 'dart2js exit code: '
            '${res.exitCode}. Contents of stderr: \n${res.stderr}. '
            'Contents of stdout: \n${res.stdout}.');
          expect(new File(outPath).existsSync(), true, reason: 'input file '
            '$inPath should have been compiled to $outPath.');
        }), completes);
      });
    }
  }

  if (args['dart'] == true) {
    runTests('');
  }
  if (args['js'] == true) {
    ensureCompileToJs();
    runTests('?js=1');
  }
  if (args['shadowdom'] == true) {
    ensureCompileToJs();
    runTests('?js=1&shadowdomjs=1');
  }
}

// TODO(jmesserly): we need a full diff tool.
// TODO(sigmund): consider moving this matcher to unittest
class SmartStringMatcher extends BaseMatcher {
  final String _value;

  SmartStringMatcher(this._value);

  bool matches(item, MatchState mismatchState) => _value == item;

  Description describe(Description description) =>
      description.addDescriptionOf(_value);

  Description describeMismatch(item, Description mismatchDescription,
      MatchState matchState, bool verbose) {
    if (item is! String) {
      return mismatchDescription.addDescriptionOf(item).add(' not a string');
    } else {
      var buff = new StringBuffer();
      buff.write('Strings are not equal.');
      var escapedItem = _escape(item);
      var escapedValue = _escape(_value);
      int minLength = min(escapedItem.length, escapedValue.length);
      int start;
      for (start = 0; start < minLength; start++) {
        if (escapedValue.codeUnitAt(start) != escapedItem.codeUnitAt(start)) {
          break;
        }
      }
      if (start == minLength) {
        if (escapedValue.length < escapedItem.length) {
          buff.write(' Both strings start the same, but the given value also'
              ' has the following trailing characters: ');
          _writeTrailing(buff, escapedItem, escapedValue.length);
        } else {
          buff.write(' Both strings start the same, but the given value is'
              ' missing the following trailing characters: ');
          _writeTrailing(buff, escapedValue, escapedItem.length);
        }
      } else {
        buff.write('\nExpected: ');
        _writeLeading(buff, escapedValue, start);
        buff.write('[32m');
        buff.write(escapedValue[start]);
        buff.write('[0m');
        _writeTrailing(buff, escapedValue, start + 1);
        buff.write('\n But was: ');
        _writeLeading(buff, escapedItem, start);
        buff.write('[31m');
        buff.write(escapedItem[start]);
        buff.write('[0m');
        _writeTrailing(buff, escapedItem, start + 1);
        buff.write('[32;1m');
        buff.write('\n          ');
        for (int i = (start > 10 ? 14 : start); i > 0; i--) buff.write(' ');
        buff.write('^  [0m');
      }

      return mismatchDescription.replace(buff.toString());
    }
  }

  static String _escape(String s) =>
      s.replaceAll('\n', '\\n').replaceAll('\r', '\\r').replaceAll('\t', '\\t');

  static String _writeLeading(StringBuffer buff, String s, int start) {
    if (start > 10) {
      buff.write('... ');
      buff.write(s.substring(start - 10, start));
    } else {
      buff.write(s.substring(0, start));
    }
  }

  static String _writeTrailing(StringBuffer buff, String s, int start) {
    if (start + 10 > s.length) {
      buff.write(s.substring(start));
    } else {
      buff.write(s.substring(start, start + 10));
      buff.write(' ...');
    }
  }
}

ArgResults _parseArgs(List<String> arguments, String script) {
  var parser = new ArgParser()
    ..addFlag('dart', abbr: 'd', help: 'run on Dart VM', defaultsTo: true)
    ..addFlag('js', abbr: 'j', help: 'run compiled dart2js', defaultsTo: true)
    ..addFlag('shadowdom', abbr: 's',
        help: 'run dart2js and polyfilled ShadowDOM', defaultsTo: true)
    ..addFlag('help', abbr: 'h', help: 'Displays this help message',
        defaultsTo: false, negatable: false);

  showUsage() {
    print('Usage: $script [options...] [test_name_regexp]');
    print(parser.getUsage());
    return null;
  }

  try {
    var results = parser.parse(arguments);
    if (results['help']) return showUsage();
    return results;
  } on FormatException catch (e) {
    print(e.message);
    return showUsage();
  }
}
