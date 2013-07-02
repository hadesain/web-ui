// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library no_wrapper_fu;

import 'dart:html';
import 'components/component_loader.dart';
import 'components/components.dart';

void main() {
  _componentsSetup();
}

void _componentsSetup() {
  Map<String, Function> map = {
    'x-not-a-wrapper' : () => new FancyDivElement.component()
  };
  initializeComponents((String name) => map[name], true);
}
