// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library app;

import 'dart:html';
import 'package:mdv_observe/mdv_observe.dart';
import 'package:web_ui/web_ui.dart';
import 'model.dart';

class TodoApp extends CustomElement with ObservableMixin {
  @observable AppModel app;

  void created() {
    super.created();
    app = appModel;
  }

  void addTodo(Event e) {
    e.preventDefault(); // don't submit the form
    var input = getShadowRoot('todo-app').query('#new-todo');
    if (input.value == '') return;
    app.todos.add(new Todo(input.value));
    input.value = '';
  }
}
