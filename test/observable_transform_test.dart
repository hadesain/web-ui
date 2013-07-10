// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:unittest/compact_vm_config.dart';
import 'package:unittest/unittest.dart';
import 'package:polymer/src/dart_parser.dart';
import 'package:polymer/src/messages.dart';
import 'package:polymer/src/observable_transform.dart';

main() {
  useCompactVMConfiguration();

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
