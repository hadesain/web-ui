// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/** Tests for some of the utility helper functions used by the compiler. */
library observe_test;

import 'dart:collection' show LinkedHashMap;
import 'package:unittest/compact_vm_config.dart';
import 'package:unittest/unittest.dart';
import 'package:web_ui/observe.dart';
import 'package:web_ui/observe/observable.dart' show hasObservers, observeReads;
import 'package:web_ui/src/utils_observe.dart' show setImmediate;

main() {
  useCompactVMConfiguration();

  group('ObservableReference', () {
    test('no observers', () {
      var t = new ObservableReference<int>(123);
      expect(t.value, 123);
      t.value = 42;
      expect(t.value, 42);
      expect(hasObservers(t), false);
    });

    test('observe', () {
      var t = new ObservableReference<int>(123);
      int called = 0;
      observe(() => t.value, expectAsync1((ChangeNotification n) {
        called++;
        expect(n.oldValue, 123);
        expect(n.newValue, 42);
      }));
      t.value = 41;
      t.value = 42;
      expect(called, 0, reason: 'changes delived async');
    });

    test('observe multiple changes', () {
      var t = new ObservableReference<int>(123);
      observe(() => t.value, expectAsync1((ChangeNotification n) {
        if (n.oldValue == 123) {
          expect(n.newValue, 42);
          // Cause another change
          t.value = 777;
        } else {
          expect(n.oldValue, 42);
          expect(n.newValue, 777);
        }
      }, count: 2));
      t.value = 42;
    });

    test('multiple observers', () {
      var t = new ObservableReference<int>(123);
      observe(() => t.value, expectAsync1((ChangeNotification n) {
        expect(n.oldValue, 123);
        expect(n.newValue, 42);
      }));
      observe(() => t.value + 1, expectAsync1((ChangeNotification n) {
        expect(n.oldValue, 124);
        expect(n.newValue, 43);
      }));
      t.value = 41;
      t.value = 42;
    });

    test('deliverChangesSync', () {
      var t = new ObservableReference<int>(123);
      var notifications = [];
      observe(() => t.value, notifications.add);
      t.value = 41;
      t.value = 42;
      expect(notifications, [], reason: 'changes delived async');

      deliverChangesSync();
      expect(notifications, [_change(123, 42)]);
      t.value = 777;
      expect(notifications.length, 1, reason: 'changes delived async');

      deliverChangesSync();
      expect(notifications, [_change(123, 42), _change(42, 777)]);

      // Has no effect if there are no changes
      deliverChangesSync();
      expect(notifications, [_change(123, 42), _change(42, 777)]);
    });

    test('unobserve', () {
      var t = new ObservableReference<int>(123);
      ChangeUnobserver unobserve;
      unobserve = observe(() => t.value, expectAsync1((n) {
        expect(n.oldValue, 123);
        expect(n.newValue, 42);
        unobserve();
        t.value = 777;
      }));
      t.value = 42;
    });

    test('observers fired in order', () {
      var t = new ObservableReference<int>(123);
      int expectOldValue = 123;
      int expectNewValue = 42;
      observe(() => t.value, expectAsync1((n) {
        expect(n.oldValue, expectOldValue);
        expect(n.newValue, expectNewValue);

        // The second observer will see this change already, and only be called
        // once. However we'll be called a second time.
        t.value = 777;
        expectNewValue = 777;
        expectOldValue = 42;
      }, count: 2));

      observe(() => t.value + 1000, expectAsync1((n) {
        expect(n.oldValue, 1123);
        expect(n.newValue, 1777);
      }));

      // Make the initial change
      t.value = 42;
    });

    test('unobserve one of two observers', () {
      var t = new ObservableReference<int>(123);
      ChangeUnobserver unobserve;
      unobserve = observe(() => t.value, expectAsync1((n) {
        expect(n.oldValue, 123);
        expect(n.newValue, 42);

        // This will not affect the other observer, so it still gets the event.
        unobserve();
        setImmediate(() => t.value = 777);
      }));
      int count = 0;
      observe(() => t.value + 1000, expectAsync1((n) {
        if (++count == 1) {
          expect(n.oldValue, 1123);
          expect(n.newValue, 1042);
        } else {
          expect(n.oldValue, 1042);
          expect(n.newValue, 1777);
        }
      }, count: 2));

      // Make the initial change
      t.value = 42;
    });

    test('notifyRead in getter', () {
      var t = new ObservableReference<int>(123);

      observe(() {
        expect(hasObservers(t), false);
        expect(observeReads, true);
        return t.value;
      }, (n) {});

      expect(observeReads, false);
      expect(hasObservers(t), true);
    });

    test('notifyChange in setter', () {
      var t = new ObservableReference<int>(123);
      expect(hasObservers(t), false);

      observe(() {
        expect(observeReads, true);
        return t.value;
      }, (n) {});

      t.value = 42;
      expect(observeReads, false);
      expect(hasObservers(t), true);

      // This will re-observe the expression.
      deliverChangesSync();

      expect(observeReads, false);
      expect(hasObservers(t), true);
    });

    test('observe conditional async', () {
      var t = new ObservableReference<bool>(false);
      var a = new ObservableReference<int>(123);
      var b = new ObservableReference<String>('hi');

      int count = 0;
      var oldValue = 'hi';
      observe(() => t.value ? a.value : b.value, expectAsync1((n) {
        expect(n.oldValue, oldValue);
        oldValue = t.value ? a.value : b.value;
        expect(n.newValue, oldValue);

        expect(hasObservers(t), true);
        expect(hasObservers(a), t.value);
        expect(hasObservers(b), !t.value);

        switch (++count) {
          case 1:
            // We are observing "a", change it
            a.value = 42;
            break;
          case 2:
            // Switch to observing "b"
            t.value = false;
            break;
          case 3:
            // Change "a", this should have no effect and will not fire a 4th
            // change event.
            a.value = 777;
            break;
          default:
            // Should not be able to reach this because of the "count" argument
            // to expectAsync1
            throw new StateError('unreachable');
        }
      }, count: 3));

      expect(hasObservers(t), true);
      expect(hasObservers(a), false);
      expect(hasObservers(b), true);

      // Start off by changing "t" to true.
      t.value = true;
    });

    test('change limit set to null (unbounded)', () {
      const BIG_LIMIT = 1000;
      expect(circularNotifyLimit, lessThan(BIG_LIMIT));

      int oldLimit = circularNotifyLimit;
      circularNotifyLimit = null;
      try {
        var x = new ObservableReference(false);
        var y = new ObservableReference(false);

        int xCount = 0, yCount = 0;
        observe(() => x.value, (n) {
          if (++xCount < BIG_LIMIT) y.value = x.value;
        });
        observe(() => y.value, (n) {
          if (++yCount < BIG_LIMIT) x.value = !y.value;
        });

        // Kick off the cascading changes
        x.value = true;

        deliverChangesSync();

        expect(xCount, BIG_LIMIT);
        expect(yCount, BIG_LIMIT - 1);
      } finally {
        circularNotifyLimit = oldLimit;
      }
    });

    test('change limit calls handler', () {
      const BIG_LIMIT = 1000;
      expect(circularNotifyLimit, lessThan(BIG_LIMIT));

      var savedOnCircularNotifyLimit = onCircularNotifyLimit;
      onCircularNotifyLimit = expectAsync1((message) {
        expect(message, contains('circular reference in observer callbacks'));
      });
      try {
        var x = new ObservableReference(false);
        var y = new ObservableReference(false);

        int xCount = 0, yCount = 0;
        observe(() => x.value, (n) {
          xCount++;
          y.value = x.value;
        });
        observe(() => y.value, (n) {
          yCount++;
          x.value = !y.value;
        });

        // Kick off the cascading changes
        x.value = true;

        deliverChangesSync();

        // The reason these are divided by 4:
        //
        // One factor of 2 is because the fact we update only one of the two
        // couters each iteration. The other factor of 2 is because the
        // expression observers add 1 cycle of lag:
        //
        // start: mutate x
        // 1: x changed -> runs x expression observer
        // 2: x expression observer -> ++xCount, mutate y
        // 3: y changed -> run y expression observer
        // 4: y expression observer -> ++yCount, mutate x
        //
        // So for 4 cycles in deliverChangesSync, we only got 1 change to
        // xCount and one change to yCount.
        expect(xCount, circularNotifyLimit ~/ 4);
        expect(yCount, circularNotifyLimit ~/ 4);
      } finally {
        onCircularNotifyLimit = savedOnCircularNotifyLimit;
      }
    });

    test('observe conditional sync', () {
      var t = new ObservableReference<bool>(false);
      var a = new ObservableReference<int>(123);
      var b = new ObservableReference<String>('hi');

      var notifications = [];
      observe(() => t.value ? a.value : b.value, notifications.add);

      // Start off by changing "t" to true, so we evaluate "a".
      t.value = true;
      deliverChangesSync();

      // This changes "a" which we should be observing.
      a.value = 42;
      deliverChangesSync();

      // This has no effect because we aren't using "b" yet.
      b.value = 'universe';
      deliverChangesSync();

      // Switch to use "b".
      t.value = false;
      deliverChangesSync();

      // This has no effect because we aren't using "a" anymore.
      a.value = 777;
      deliverChangesSync();

      expect(notifications, [
          _change('hi', 123),
          _change(123, 42),
          _change(42, 'universe')]);
    });
  });


  group('ObservableList', () {
    // TODO(jmesserly): need all standard List tests.

    test('observe length', () {
      var list = new ObservableList<int>();
      var notification = null;
      observe(() => list.length, (n) { notification = n; });

      list.addAll([1, 2, 3]);
      expect(list, [1, 2, 3]);
      deliverChangesSync();
      expect(notification, _change(0, 3), reason: 'addAll changes length');

      list.add(4);
      expect(list, [1, 2, 3, 4]);
      deliverChangesSync();
      expect(notification, _change(3, 4), reason: 'add changes length');

      list.removeRange(1, 2);
      expect(list, [1, 4]);
      deliverChangesSync();
      expect(notification, _change(4, 2), reason: 'removeRange changes length');

      list.length = 5;
      expect(list, [1, 4, null, null, null]);
      deliverChangesSync();
      expect(notification, _change(2, 5), reason: 'length= changes length');
      notification = null;

      list[2] = 9000;
      expect(list, [1, 4, 9000, null, null]);
      deliverChangesSync();
      expect(notification, null, reason: '[]= does not change length');

      list.clear();
      expect(list, []);
      deliverChangesSync();
      expect(notification, _change(5, 0), reason: 'clear changes length');
    });

    test('observe index', () {
      var list = toObservable([1, 2, 3]);
      var notification = null;
      observe(() => list[1], (n) { notification = n; });

      list.add(4);
      expect(list, [1, 2, 3, 4]);
      deliverChangesSync();
      expect(notification, null,
          reason: 'add does not change existing items');

      list[1] = 777;
      expect(list, [1, 777, 3, 4]);
      deliverChangesSync();
      expect(notification, _change(2, 777));

      notification = null;
      list[2] = 9000;
      expect(list, [1, 777, 9000, 4]);
      deliverChangesSync();
      expect(notification, null,
          reason: 'setting a different index should not fire change');

      list[1] = 44;
      list[1] = 43;
      list[1] = 42;
      expect(list, [1, 42, 9000, 4]);
      deliverChangesSync();
      expect(notification, _change(777, 42));

      notification = null;
      list.length = 2;
      expect(list, [1, 42]);
      deliverChangesSync();
      expect(notification, null,
          reason: 'did not truncate the observed item');

      list.length = 1; // truncate
      list.add(2);
      expect(list, [1, 2]);
      deliverChangesSync();
      expect(notification, _change(42, 2),
          reason: 'item truncated and added back');

      notification = null;
      list.length = 1; // truncate
      list.add(2);
      expect(list, [1, 2]);
      deliverChangesSync();
      expect(notification, null,
          reason: 'truncated but added same item back');
    });

    test('toString', () {
      var list = toObservable([1, 2, 3]);
      var notification = null;
      observe(() => list.toString(), (n) { notification = n; });
      list[2] = 4;
      deliverChangesSync();
      expect(notification, _change('[1, 2, 3]', '[1, 2, 4]'));
    });

    test('iterator', () {
      var list = toObservable([0, 1, 2]);
      var notification = null;
      observe(() => list.where((x) => x % 2 == 0).toList(),
          (n) { notification = n; });

      list[2] = 4;
      deliverChangesSync();
      expect('$notification', '#<ChangeNotification from [0, 2] to [0, 4]>');

      notification = null;
      list[1] = 7;
      deliverChangesSync();

      // TODO(jmesserly): this seems like a bug. Even though Dart doesn't
      // implement equality for List/Map, maybe we should? Has interesting
      // performance implications, though.
      //
      // Or should ObservableList return an ObservableIterator that correctly
      // tracks changes relative to the original collection?
      expect('$notification', '#<ChangeNotification from [0, 4] to [0, 4]>');
    });

    group('change records', () {

      List<ChangeRecord> records;
      List list;

      setUp(() {
        list = toObservable([1, 2, 3, 1, 3, 4]);
        records = null;
        observeChanges(list, (r) { records = r; });
      });

      test('read operations', () {
        expect(list.length, 6);
        expect(list[0], 1);
        expect(list.indexOf(4), 5);
        expect(list.indexOf(1), 0);
        expect(list.indexOf(1, 1), 3);
        expect(list.lastIndexOf(1), 3);
        expect(list.last, 4);
        var copy = new List<int>();
        list.forEach((i) { copy.add(i); });
        expect(copy, orderedEquals([1, 2, 3, 1, 3, 4]));
        deliverChangesSync();

        // no change from read-only operators
        expect(records, null);
      });

      test('add', () {
        list.add(5);
        list.add(6);
        expect(list, orderedEquals([1, 2, 3, 1, 3, 4, 5, 6]));

        deliverChangesSync();
        expect(records, [
          _record(ChangeRecord.FIELD, 'length', 6, 7),
          _record(ChangeRecord.INSERT, 6, null, 5),
          _record(ChangeRecord.FIELD, 'length', 7, 8),
          _record(ChangeRecord.INSERT, 7, null, 6),
        ]);
      });

      test('[]=', () {
        list[1] = list.last;
        expect(list, orderedEquals([1, 4, 3, 1, 3, 4]));

        deliverChangesSync();
        expect(records, [ _record(ChangeRecord.INDEX, 1, 2, 4) ]);
      });

      test('removeLast', () {
        expect(list.removeLast(), 4);
        expect(list, orderedEquals([1, 2, 3, 1, 3]));

        deliverChangesSync();
        expect(records, [
          _record(ChangeRecord.REMOVE, 5,  4, null),
          _record(ChangeRecord.FIELD, 'length', 6, 5),
        ]);
      });

      test('removeRange', () {
        list.removeRange(1, 3);
        expect(list, orderedEquals([1, 3, 4]));

        deliverChangesSync();
        // TODO(jmesserly): ideally we'd have a better way to express the moves.
        expect(records, [
          _record(ChangeRecord.REMOVE, 1, 2, null),
          _record(ChangeRecord.REMOVE, 2, 3, null),
          _record(ChangeRecord.INDEX, 1, 2, 3),
          _record(ChangeRecord.INDEX, 2, 3, 4),
          _record(ChangeRecord.REMOVE, 5, 4, null),
          _record(ChangeRecord.REMOVE, 4, 3, null),
          _record(ChangeRecord.REMOVE, 3, 1, null),
          _record(ChangeRecord.FIELD, 'length', 6, 3)
        ]);
      });

      test('sort', () {
        list.sort((x, y) => x - y);
        expect(list, orderedEquals([1, 1, 2, 3, 3, 4]));

        deliverChangesSync();
        // TODO(jmesserly): this depends on implementation details of sort.
        expect(records, [
          _record(ChangeRecord.INDEX, 1, 2, 2),
          _record(ChangeRecord.INDEX, 2, 3, 3),
          _record(ChangeRecord.INDEX, 3, 1, 3),
          _record(ChangeRecord.INDEX, 2, 3, 2),
          _record(ChangeRecord.INDEX, 1, 2, 1),
          _record(ChangeRecord.INDEX, 4, 3, 3),
          _record(ChangeRecord.INDEX, 5, 4, 4)
        ]);
      });

      test('clear', () {
        list.clear();
        expect(list, []);

        deliverChangesSync();
        expect(records, [
          _record(ChangeRecord.REMOVE, 5, 4, null),
          _record(ChangeRecord.REMOVE, 4, 3, null),
          _record(ChangeRecord.REMOVE, 3, 1, null),
          _record(ChangeRecord.REMOVE, 2, 3, null),
          _record(ChangeRecord.REMOVE, 1, 2, null),
          _record(ChangeRecord.REMOVE, 0, 1, null),
          _record(ChangeRecord.FIELD, 'length', 6, 0),
        ]);
      });
    });
  });


  group('ObservableSet', () {
    // TODO(jmesserly): need all standard Set tests.

    test('observe length', () {
      var set = new ObservableSet<int>();
      var notification = null;
      observe(() => set.length, (n) { notification = n; });

      set.addAll([1, 2, 3]);
      expect(set, unorderedEquals([1, 2, 3]));
      deliverChangesSync();
      expect(notification, _change(0, 3), reason: 'addAll changes length');

      set.add(4);
      expect(set, unorderedEquals([1, 2, 3, 4]));
      deliverChangesSync();
      expect(notification, _change(3, 4), reason: 'add changes length');

      set.removeAll([2, 3]);
      expect(set, unorderedEquals([1, 4]));
      deliverChangesSync();
      expect(notification, _change(4, 2), reason: 'removeAll changes length');

      set.remove(1);
      expect(set, [4]);
      deliverChangesSync();
      expect(notification, _change(2, 1), reason: 'remove changes length');

      notification = null;
      set.add(4);
      expect(set, [4]);
      deliverChangesSync();
      expect(notification, null, reason: 'item already exists');

      set.clear();
      expect(set, []);
      deliverChangesSync();
      expect(notification, _change(1, 0), reason: 'clear changes length');
    });

    test('observe item', () {
      var set = new ObservableSet.from([1, 2, 3]);
      var notification = null;
      observe(() => set.contains(2), (n) { notification = n; });

      set.add(4);
      expect(set, unorderedEquals([1, 2, 3, 4]));
      deliverChangesSync();
      expect(notification, null, reason: 'add does not change existing items');

      set.remove(3);
      expect(set, unorderedEquals([1, 2, 4]));
      expect(notification, null,
          reason: 'removing an item does not change other items');

      set.remove(2);
      expect(set, unorderedEquals([1, 4]));
      deliverChangesSync();
      expect(notification, _change(true, false));

      notification = null;
      set.removeAll([2, 3]);
      expect(set, unorderedEquals([1, 4]));
      deliverChangesSync();
      expect(notification, null, reason: 'item already removed');

      set.add(2);
      expect(set, unorderedEquals([1, 2, 4]));
      deliverChangesSync();
      expect(notification, _change(false, true), reason: 'item added again');
    });

    test('toString', () {
      var original = new Set.from([1, 2, 3]);
      var set = new ObservableSet.from(original);
      var notification = null;
      observe(() => set.toString(), (n) { notification = n; });
      set.add(4);
      deliverChangesSync();
      var updated = new Set.from([1, 2, 3, 4]);

      // Note: using Set.toString as the exectation, so the order is the same
      // as with ObservableSet, regardless of how hashCode is implemented.
      expect(notification, _change('$original', '$updated'));
    });
  });


  group('ObservableMap', () {
    // TODO(jmesserly): need all standard Map tests.

    test('observe length', () {
      var map = new ObservableMap();
      var notification = null;
      observe(() => map.length, (n) { notification = n; });

      map['a'] = 1;
      map.putIfAbsent('b', () => 2);
      map['c'] = 3;
      expect(map, {'a': 1, 'b': 2, 'c': 3});
      deliverChangesSync();
      expect(notification, _change(0, 3), reason: 'adding changes length');

      map['d'] = 4;
      expect(map, {'a': 1, 'b': 2, 'c': 3, 'd': 4});
      deliverChangesSync();
      expect(notification, _change(3, 4), reason: 'add changes length');

      map.remove('b');
      map.remove('c');
      expect(map, {'a': 1, 'd': 4});
      deliverChangesSync();
      expect(notification, _change(4, 2), reason: 'removeRange changes length');

      notification = null;
      map['d'] = 9000;
      expect(map, {'a': 1, 'd': 9000});
      deliverChangesSync();
      expect(notification, null, reason: 'update item does not change length');

      map.clear();
      expect(map, {});
      deliverChangesSync();
      expect(notification, _change(2, 0), reason: 'clear changes length');
    });

    test('observe index', () {
      var map = toObservable({'a': 1, 'b': 2, 'c': 3});
      var notification = null;
      observe(() => map['b'], (n) { notification = n; });

      map.putIfAbsent('d', () => 4);
      expect(map, {'a': 1, 'b': 2, 'c': 3, 'd': 4});
      deliverChangesSync();
      expect(notification, null, reason: 'add does not change existing items');

      map['b'] = null;
      expect(map, {'a': 1, 'b': null, 'c': 3, 'd': 4});
      deliverChangesSync();
      expect(notification, _change(2, null));

      map['b'] = 777;
      expect(map, {'a': 1, 'b': 777, 'c': 3, 'd': 4});
      deliverChangesSync();
      expect(notification, _change(null, 777));

      notification = null;
      map.putIfAbsent('b', () => 1234);
      expect(map, {'a': 1, 'b': 777, 'c': 3, 'd': 4});
      deliverChangesSync();
      expect(notification, null, reason: 'item already there');

      map['c'] = 9000;
      expect(map, {'a': 1, 'b': 777, 'c': 9000, 'd': 4});
      deliverChangesSync();
      expect(notification, null, reason: 'setting a different item');

      map['b'] = 44;
      map['b'] = 43;
      map['b'] = 42;
      expect(map, {'a': 1, 'b': 42, 'c': 9000, 'd': 4});
      deliverChangesSync();
      expect(notification, _change(777, 42));

      notification = null;
      map.remove('a');
      map.remove('d');
      expect(map, {'b': 42, 'c': 9000});
      deliverChangesSync();
      expect(notification, null, reason: 'did not remove the observed item');

      map.remove('b');
      map['b'] = 2;
      expect(map, {'b': 2, 'c': 9000});
      deliverChangesSync();
      expect(notification, _change(42, 2), reason: 'removed and added back');
    });

    test('toString', () {
      var map = toObservable({'a': 1, 'b': 2});

      var notification = null;
      observe(() => map.toString(), (n) { notification = n; });
      map.remove('b');
      map['c'] = 3;
      deliverChangesSync();

      expect(notification, _change('{a: 1, b: 2}', '{a: 1, c: 3}'));
    });


    group('change records', () {
      List<ChangeRecord> records;
      Map map;

      setUp(() {
        map = toObservable({'a': 1, 'b': 2});
        records = null;
        observeChanges(map, (r) { records = r; });
      });

      test('read operations', () {
        expect(map.length, 2);
        expect(map.isEmpty, false);
        expect(map['a'], 1);
        expect(map.containsKey(2), false);
        expect(map.containsValue(2), true);
        expect(map.containsKey('b'), true);
        expect(map.keys.toList(), ['a', 'b']);
        expect(map.values.toList(), [1, 2]);
        var copy = {};
        map.forEach((k, v) { copy[k] = v; });
        expect(copy, {'a': 1, 'b': 2});
        deliverChangesSync();

        // no change from read-only operators
        expect(records, null);
      });

      test('putIfAbsent', () {
        map.putIfAbsent('a', () => 42);
        expect(map, {'a': 1, 'b': 2});

        map.putIfAbsent('c', () => 3);
        expect(map, {'a': 1, 'b': 2, 'c': 3});

        deliverChangesSync();
        expect(records, [
          _record(ChangeRecord.FIELD, 'length', 2, 3),
          _record(ChangeRecord.INSERT, 'c', null, 3),
        ]);
      });

      test('[]=', () {
        map['a'] = 42;
        expect(map, {'a': 42, 'b': 2});

        map['c'] = 3;
        expect(map, {'a': 42, 'b': 2, 'c': 3});

        deliverChangesSync();
        expect(records, [
          _record(ChangeRecord.INDEX, 'a', 1, 42),
          _record(ChangeRecord.FIELD, 'length', 2, 3),
          _record(ChangeRecord.INSERT, 'c', null, 3)
        ]);
      });

      test('remove', () {
        map.remove('b');
        expect(map, {'a': 1});

        deliverChangesSync();
        expect(records, [
          _record(ChangeRecord.REMOVE, 'b',  2, null),
          _record(ChangeRecord.FIELD, 'length', 2, 1),
        ]);
      });

      test('clear', () {
        map.clear();
        expect(map, {});

        deliverChangesSync();
        expect(records, [
          _record(ChangeRecord.REMOVE, 'a',  1, null),
          _record(ChangeRecord.REMOVE, 'b',  2, null),
          _record(ChangeRecord.FIELD, 'length', 2, 0),
        ]);
      });
    });
  });

  // We only really support equality on these for testing purposes.
  // However we need .hashCode because we've implemented operator ==.
  test('ChangeRecord.hashCode', () {
    var a = _record(ChangeRecord.REMOVE, 'a',  1, null);
    var b = _record(ChangeRecord.REMOVE, 'a',  1, null);
    var c = _record(ChangeRecord.REMOVE, 'b',  1, null);
    expect(a.hashCode, b.hashCode, reason: 'a == b');
    expect(b.hashCode, isNot(equals(c.hashCode)), reason: 'b != c');
  });

  test('ChangeNotification.hashCode', () {
    var a = _change(123, 42);
    var b = _change(123, 42);
    var c = _change(123, 43);
    expect(a.hashCode, b.hashCode, reason: 'a == b');
    expect(b.hashCode, isNot(equals(c.hashCode)), reason: 'b != c');
  });
}

_change(oldValue, newValue) => new ChangeNotification(oldValue, newValue);

_record(type, key, oldValue, newValue) =>
    new ChangeRecord(type, key, oldValue, newValue);
