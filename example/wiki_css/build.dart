#!/usr/bin/env dart
// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'package:web_ui/component_build.dart';

void main() {
  var args = new Options().arguments;
  args.addAll(['--', '--no-css-mangle', '--css-reset', 'web/reset.css',
                   '--warnings_as_errors', '--verbose']);
  build(args, ['web/index.html']);
}
