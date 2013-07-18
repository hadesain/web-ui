// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This library contains support for scoped CSS that uses the compilation
 * strategy of WebUI. This will likely become deprecated as we migrate over to
 * use runtime mechanisms to enforce scoped css rules.
 */
library scoped_css;

/**
 * Maps CSS selectors (class and) to a mangled name and maps x-component name
 * to [is='x-component'].
 */
class ScopedCssMapper {
  final Map<String, String> _mapping;

  ScopedCssMapper(this._mapping);

  /** Returns mangled name of selector sans . or # character. */
  String operator [](String selector) => _mapping[selector];

  /** Returns mangled name of selector w/ . or # character. */
  String getSelector(String selector) {
    var prefixedName = this[selector];
    var selectorType = selector[0];
    if (selectorType == '.' || selectorType == '#') {
      return '$selectorType${prefixedName}';
    }

    return prefixedName;
  }
}

/** Any CSS selector (class, id or element) defined name to mangled name. */
Map<String, ScopedCssMapper> _mappers = {};

ScopedCssMapper getScopedCss(String componentName) => _mappers[componentName];

void setScopedCss(String componentName, Map<String, String> mapping) {
  _mappers.putIfAbsent(componentName, () => new ScopedCssMapper(mapping));
}
