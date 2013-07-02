// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/compact_vm_config.dart';
import 'package:unittest/unittest.dart';
import 'package:web_ui/src/dart_parser.dart';
import 'package:web_ui/src/messages.dart';
import 'package:web_ui/src/observable_transform.dart';

main() {
  useCompactVMConfiguration();

  group('do not add "with Observable"', () {
    testClause('', '');
    testClause('extends Base', 'extends Base');
    testClause('extends Base<T>', 'extends Base<T>');
    testClause('extends Base with Mixin',
        'extends Base with Mixin');
    testClause('extends Base with Mixin<T>',
        'extends Base with Mixin<T>');
    testClause('extends Base with Mixin, Mixin2',
        'extends Base with Mixin, Mixin2');
    testClause('implements Interface', 'implements Interface');
    testClause('implements Interface<T>', 'implements Interface<T>');
    testClause('extends Base implements Interface',
        'extends Base implements Interface');
    testClause('extends Base with Mixin implements Interface, Interface2',
        'extends Base with Mixin implements Interface, Interface2');
  });

  group('fixes contructor calls ', () {
    testInitializers('this.a', '(a) : __\$a = a');
    testInitializers('{this.a}', '({a}) : __\$a = a');
    testInitializers('[this.a]', '([a]) : __\$a = a');
    testInitializers('this.a, this.b', '(a, b) : __\$a = a, __\$b = b');
    testInitializers('{this.a, this.b}', '({a, b}) : __\$a = a, __\$b = b');
    testInitializers('[this.a, this.b]', '([a, b]) : __\$a = a, __\$b = b');
    testInitializers('this.a, [this.b]', '(a, [b]) : __\$a = a, __\$b = b');
    testInitializers('this.a, {this.b}', '(a, {b}) : __\$a = a, __\$b = b');
  });
}

testClause(String clauses, String expected) {
  test(clauses, () {

    var className = 'MyClass';
    if (clauses.contains('<T>')) className += '<T>';

    var code = '''
        class $className $clauses {
          @observable var field;
        }''';


    var edit = transformObservables(parseDartCode('<test>', code, null),
        new Messages.silent());
    expect(edit, isNotNull);
    var output = (edit.commit()..build('<test>')).text;

    var classPos = output.indexOf(className) + className.length;
    var actualClauses = output.substring(classPos, output.indexOf('{'))
        .trim().replaceAll('  ', ' ');

    expect(actualClauses, expected);
  });
}

testInitializers(String args, String expected) {
  test(args, () {

    var constructor = 'MyClass(';

    var code = '''
        class MyClass {
          @observable var a;
          @observable var b;
          MyClass($args);
        }''';

    var edit = transformObservables(parseDartCode('<test>', code, null),
        new Messages.silent());
    expect(edit, isNotNull);
    var output = (edit.commit()..build('<test>')).text;

    var begin = output.indexOf(constructor) + constructor.length - 1;
    var end = output.indexOf(';', begin);
    if (end == -1) end = output.length;
    var init = output.substring(begin, end).trim().replaceAll('  ', ' ');

    expect(init, expected);
  });
}
