#!/usr/bin/env dart
// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Script to compile each dart web component examples and copy the
 * generated code to an output directory.
 */
library build_examples;

import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:web_ui/dwc.dart' as dwc;

main() {
  var argParser = new ArgParser();
  argParser.addFlag('help', abbr: 'h', help: 'Displayes this help message',
      defaultsTo: false, negatable: false);
  argParser.addOption('out', abbr: 'o',
      help: 'output directory for the generated code',
      defaultsTo: 'generated');
  var args = argParser.parse(new Options().arguments);

  if (args['help']) {
    print('Usage: build_examples.dart [-o outdir] [file1, file2, ...]');
    print(argParser.getUsage());
    exit(0);
  }

  var output = args['out'];
  if (args.rest.isEmpty) {
    var dir = new Directory.current();
    listFiles(dir,
        (filename) => filename.endsWith('.html') && !filename.startsWith('_'))
        .then((inputs) {
          buildAll(inputs.map((file) => new Path(file).filename), output);
        });
  } else {
    buildAll(args.rest, output);
  }
}

Future<List<String>> listFiles(Directory dir, bool filter(String filename)) {
  var res = [];
  var completer = new Completer();
  var lister = dir.list();
  lister.onFile = (file) {
    if (filter(new Path(file).filename)) res.add(file);
  };
  lister.onDone = (completed) {
    if (completed) completer.complete(res);
  };
  return completer.future;
}

List<String> totalTime = [];

void buildAll(Iterable<String> inputs, output) {
  var processes = inputs.map((input) => buildSingle(input, output));
  Future.wait(processes).then((_) {
    print('----- time summary -----');
    totalTime.forEach((s) => print(s));
  });
}

Future buildSingle(String input, String output) {
  var timer = startTime();
  return dwc.run(['--out', output, input]).then((_) {
    stopTime(timer, 'dwc - compile $input');

    timer = startTime();
    var dartFile ='$output/${input}_bootstrap.dart';
    var res = Process.run(
        'dart2js', ['--minify', '-ppackages/', dartFile,'-o$dartFile.js']);
    return res.then((r) {
      if (r.exitCode != 0) {
        print(r.stdout);
        print(r.stderr);
      }
      stopTime(timer, 'dart2js - compile ${input}_boostrap.dart');
    });
  });
}


final String GREEN_COLOR = '\u001b[32m';
final String NO_COLOR = '\u001b[0m';

Stopwatch startTime() => new Stopwatch()..start();

void stopTime(Stopwatch watch, String message) {
  watch.stop();
  var duration = watch.elapsedMilliseconds;
  print('$message: $GREEN_COLOR$duration ms$NO_COLOR');
  totalTime.add('$message: $GREEN_COLOR$duration ms$NO_COLOR');
}
