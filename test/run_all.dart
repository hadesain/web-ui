// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This is a helper for run.sh. We try to run all of the Dart code in one
 * instance of the Dart VM to reduce warm-up time.
 */
library run_impl;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' show min;
import 'dart:utf' show encodeUtf8;
import 'package:pathos/path.dart' as path;
import 'package:unittest/compact_vm_config.dart';
import 'package:unittest/unittest.dart';
import 'package:polymer/dwc.dart' as dwc;
import 'package:polymer/testing/content_shell_test.dart';

import 'css_test.dart' as css_test;
import 'compiler_test.dart' as compiler_test;
import 'paths_test.dart' as paths_test;
import 'refactor_test.dart' as refactor_test;
import 'utils_test.dart' as utils_test;

main() {
  var args = new Options().arguments;
  var pattern = new RegExp(args.length > 0 ? args[0] : '.');

  useCompactVMConfiguration();

  void addGroup(testFile, testMain) {
    if (pattern.hasMatch(testFile)) {
      group(testFile.replaceAll('_test.dart', ':'), testMain);
    }
  }

  addGroup('compiler_test.dart', compiler_test.main);
  addGroup('css_test.dart', css_test.main);
  addGroup('paths_test.dart', paths_test.main);
  addGroup('refactor_test.dart', refactor_test.main);
  addGroup('utils_test.dart', utils_test.main);

  // TODO(jmessery): consider restoring these where applicable.
  // We'll probably want to use fancy-syntax support.
  //renderTests('data/input', 'data/input', 'data/expected', 'data/out',
      // TODO(jmesserly): make these configurable
  //    ['--no-js', '--no-shadowdom']..addAll(args));

  endToEndTests('data/unit/', 'data/out');

  // Note: if you're adding more render test suites, make sure to update run.sh
  // as well for convenient baseline diff/updating.

  // TODO(jmesserly): figure out why this fails in content_shell but works in
  // Dartium and Firefox when using the ShadowDOM polyfill.
  exampleTest('../example/component/news', ['--no-shadowdom']..addAll(args));

  exampleTest('../example/todomvc');

  // cssCompilePolyFillTest('data/input/css_compile', 'index_test\.html',
  //     'reset.css');
  // cssCompilePolyFillTest('data/input/css_compile', 'index_reset_test\.html',
  //     'full_reset.css', false);
  // cssCompileShadowDOMTest('data/input/css_compile',
  //     'index_shadow_dom_test\.html', false);
  // cssCompileMangleTest('data/input/css_compile', 'index_mangle_test\.html',
  //     false);
  // cssCompilePolyFillTest('data/input/css_compile', 'index_apply_test\.html',
  //     'reset.css', false);
  // cssCompileShadowDOMTest('data/input/css_compile',
  //     'index_apply_shadow_dom_test\.html', false);
}

void exampleTest(String path, [List<String> args]) {
  renderTests(path, '$path/test', '$path/test/expected', '$path/test/out',
      arguments: args);
}

void cssCompileMangleTest(String path, String pattern,
    [bool deleteDirectory = true]) {
  renderTests(path, path, '$path/expected', '$path/out',
      arguments: ['--css-mangle'], pattern: pattern,
      deleteDir: deleteDirectory);
}

void cssCompilePolyFillTest(String path, String pattern, String cssReset,
    [bool deleteDirectory = true]) {
  var args = ['--no-css-mangle'];
  if (cssReset != null) {
    args.addAll(['--css-reset', '${path}/${cssReset}']);
  }
  renderTests(path, path, '$path/expected', '$path/out',
      arguments: args, pattern: pattern, deleteDir: deleteDirectory);
}

void cssCompileShadowDOMTest(String path, String pattern,
    [bool deleteDirectory = true]) {
  var args = ['--no-css'];
  renderTests(path, path, '$path/expected', '$path/out',
      arguments: args, pattern: pattern,
      deleteDir: deleteDirectory);
}
