// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library todo_row;

import 'package:observe/observe.dart';
import 'package:web_ui/web_ui.dart';
import 'model.dart';

class TodoRow extends PolymerElement with ObservableMixin {
  @observable Todo todo;

  ScopedCssMapper get css => getScopedCss("todo-row");

  created() {
    super.created();
    var root = getShadowRoot("todo-row");
    var label = root.query('#label').xtag;
    var item = root.query('.' + css['.todo-item']);

    bindCssClass(item, css['.completed'], this, 'todo.done');
    bindCssClass(item, css['.editing'], label, 'editing');
  }
}
