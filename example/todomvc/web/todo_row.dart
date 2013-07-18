// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library todo_row;

import 'package:observe/observe.dart';
import 'package:polymer/polymer.dart';
import 'model.dart';

class TodoRow extends PolymerElement with ObservableMixin {
  @observable Todo todo;

  bool get applyAuthorStyles => true;
  ScopedCssMapper get css => getScopedCss("todo-row");

  created() {
    super.created();
    var root = getShadowRoot("todo-row");
    var label = root.query('#label').xtag;
    var item = root.query('.' + css['.todo-item']);

    bindCssClass(item, css['.completed'], this, 'todo.done');
    bindCssClass(item, css['.editing'], label, 'editing');
  }

  void removeTodo() => appModel.todos.remove(todo);
}
