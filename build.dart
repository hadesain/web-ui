#!/usr/bin/env dart
// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/** Build logic that lets the Dart editor build examples in the background. */
library build;
import 'package:web_ui/component_build.dart';

void main(args) {
  build(args, [
    'example/component/news/web/index.html',
    'example/explainer/clickcount.html',
    'example/explainer/countcomponent.html',
    'example/explainer/countcomponent5.html',
    'example/explainer/counter.html',
    'example/explainer/fruitsearch.html',
    'example/explainer/helloworld.html',
    'example/explainer/matchstrings.html',
    'example/explainer/redbox.html',
    'example/explainer/tableif.html',
    'example/explainer/twoway.html',
    'example/explainer/tictactoe.html',
    'example/mdv/forms_validation/forms_validation.html',
    'example/mdv/hidden/hidden.html',
    'example/mdv/hidden2/hidden2.html',
    'example/mdv/model/main.html',
    'example/mdv/table/table.html',
    'example/mdv/style/style.html',
    'example/todomvc/web/index.html']);
}
