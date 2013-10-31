#!/usr/bin/env dart
// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A simple script that updates a target json file with the new values from
 * another json file.
 */
library test.perf.update_json;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

main() {
  if (args.length < 2) {
    print('update_json.dart: A simple script that updates a target json file '
          'with the new values from another json file. ');
    print('usage: update.dart from.json to.json');
    exit(1);
  }

  var path1 = args[0];
  var path2 = args[1];
  var file1 = new File(path1).readAsStringSync();
  var file2 = new File(path2).readAsStringSync();

  var results = [];
  var map1 = JSON.decode(file1);
  var map2 = JSON.decode(file2);

  for (var key in map1.keys) {
    if (map1[key] != null) {
      map2[key] = map1[key];
    }
  }

  print('updating $path2...');
  _writeFile(path2, JSON.encode(map2));
}

Future _writeFile(String path, String text) {
  return new File(path).open(FileMode.WRITE)
      .then((file) => file.writeString(text))
      .then((file) => file.close());
}
