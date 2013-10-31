#!/usr/bin/env dart
// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Script that prints in a table format a comparison of two benchmark results.
 * The input is given as two json files containing the benchmark results.
 */
library test.perf.compare;

import 'dart:io';
import 'dart:convert' show JSON;
import 'dart:math' as math;

main(args) {
  if (args.length < 2) {
    print('usage: compare.dart results1.json results2.json [filter]');
    exit(1);
  }

  var path1 = args[0];
  var path2 = args[1];
  var file1 = new File(path1).readAsStringSync();
  var file2 = new File(path2).readAsStringSync();
  var filter = args.length > 2 ? new RegExp(args[2]) : null;

  var results = [];
  var map1 = JSON.decode(file1);
  var map2 = JSON.decode(file2);

  for (var key in map1.keys) {
    if (map2.containsKey(key)) {
      results.add(new ResultPair(key, map1[key], map2[key]));
    } else {
      results.add(new ResultPair(key, map1[key], null));
    }
  }

  for (var key in map2.keys) {
    if (!map1.containsKey(key)) {
      results.add(new ResultPair(key, null, map2[key]));
    }
  }

  print('Comparing:\n  (a) $path1\n  (b) $path2');
  _printLine('Benchmark', '(a)', '(b)', '% (b - a)/a');
  _printLine('------------------------------', '--------------',
        '--------------', '--------------');
  var times1 = [];
  var times2 = [];
  var someNull = false;
  if (filter != null) {
    results = results.where((s) => filter.hasMatch(s.name)).toList();
  }
  results.sort();

  for (var entry in results) {
    print(entry);
    if (entry.time1 != null) {
      times1.add(entry.time1);
    } else {
      someNull = true;
    }
    if (entry.time2 != null) {
      times2.add(entry.time2);
    } else {
      someNull = true;
    }

  }
  _printLine('------------------------------', '--------------',
        '--------------', '--------------');
  print(new ResultPair('Geometric mean', _geomean(times1),
        _geomean(times2)));

  if (someNull) {
    times1 = [];
    times2 = [];
    for (var entry in results) {
      if (entry.time1 != null && entry.time2 !=  null) {
        times1.add(entry.time1);
        times2.add(entry.time2);
      }
    }
    print(new ResultPair('Geometric mean (both avail)',
          _geomean(scores1), _geomean(times2)));
  }
}

class ResultPair implements Comparable {
  final String name;
  final num time1;
  final num time2;
  final num score1;
  final num score2;

  num get factor => score1 == null || score2 == null ? null
      : ((score2 - score1) * 100.0) / score1;

  ResultPair(this.name, double time1, double time2)
      : this.time1 = time1, this.time2 = time2,
        score1 = time1 == null ? null : 1000000.0 / time1,
        score2 = time2 == null ? null : 1000000.0 / time2;

  String toString() {
    var buff = new StringBuffer();
    buff.write(name);
    _ensureColumn(buff, 30);
    _addNumber(buff, score1, 45);
    _addNumber(buff, score2, 60);
    _addNumber(buff, factor, 75, color: true);
    return buff.toString();
  }

  int compareTo(ResultPair other) {
    if (name.startsWith('dart') && other.name.startsWith('js  ')) return 1;
    if (name.startsWith('js  ') && other.name.startsWith('dart')) return -1;
    if (factor != null && other.factor != null) {
      var res = factor.compareTo(other.factor);
      if (res != 0) return res;
    }
    return name.compareTo(other.name);
  }
}

_printLine(String col0, String col1, String col2, String col3) {
  var buff = new StringBuffer();
  buff.write(col0);
  _ensureColumn(buff, 30);
  _padRight(buff, col1, 45);
  _padRight(buff, col2, 60);
  _padRight(buff, col3, 75);
  print(buff.toString());
}

_ensureColumn(StringBuffer buff, int ensure) {
  while (buff.length < ensure) {
    buff.write(' ');
  }
}

_addNumber(StringBuffer buff, num value, int ensure, {bool color: false}) {
  var str;
  if (value == null) {
    str = '--';
  } else {
    str = value.toStringAsFixed(value >= 100 ? 0 : (value >= 10 ? 1 : 2));
  }

  while (buff.length + str.length < ensure) {
    buff.write(' ');
  }
  if (color) _addColor(buff, value);
  buff.write(str);
  if (color) _removeColor(buff, value);
}

_addColor(StringBuffer buff, num value) {
  if (value == null || value.abs() < 2) return;
  var color;
  if (value >= 2 && value < 7) {
    color = '[32m';
  } else if (value >= 7) {
    color = '[32;1m';
  } else if (value <= -2 && value > -7) {
    color = '[38;5;208m';
  } else if (value <= -7) {
    color = '[31;1m';
  }
  buff.write(color);
}

_removeColor(StringBuffer buff, num value) {
  if (value == null || value.abs() < 2) return;
  buff.write('[0m');
}

_padRight(StringBuffer buff, String str, int ensure) {
  while (buff.length + str.length < ensure) {
    buff.write(' ');
  }
  buff.write(str);
}

_geomean(List<num> numbers) {
  var log = 0.0;
  for (var n in numbers) {
    log += math.log(n);
  }
  return math.pow(math.E, log / numbers.length);
}
