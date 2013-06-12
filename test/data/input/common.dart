// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/** Common definitions used across several tests. */

@observable
library common;

import 'package:web_ui/observe.dart';
import 'dart:html';

String topLevelVar = "hi";

bool cond = false;

bool get notCond => !cond;

List<String> loopItemList = toObservable(["a", "b"]);

List<String> initNullLoopItemList = null;

/**
 * Query in the document for the first thing matching the selector.
 * Walks inside [ShadowRoot]s.
 */
Node queryInShadow(String selector, [Node node]) {
  if (node == null) node = document;

  if (node is Element) {
    if (node.matches(selector)) return node;

    // TODO(jmesserly): what about older shadow roots?
    if (node.shadowRoot != null) {
      var r = queryInShadow(selector, node.shadowRoot);
      if (r != null) return r;
    }
  }

  for (var n in node.nodes) {
    var r = queryInShadow(selector, n);
    if (r != null) return r;
  }

  return null;
}
