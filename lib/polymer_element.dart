// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library web_ui.polymer_element;

import 'dart:async';
import 'dart:html';
import 'package:mdv_observe/mdv_observe.dart';
import 'custom_element.dart';
import 'observe.dart';
import 'src/utils_observe.dart' show toCamelCase;

/**
 * Registers a [PolymerElement]. This is similar to [registerCustomElement]
 * but it is designed to work with the `<element>` element and adds additional
 * features.
 */
void registerPolymerElement(Element elementElement, CustomElement create()) {
  // Creates the CustomElement and then publish attributes.
  createElement() {
    CustomElement element = create();
    // TODO(jmesserly): to simplify the DWC compiler, we always emit calls to
    // registerPolymerElement, regardless of the base class type.
    if (element is PolymerElement) element._publishAttributes(elementElement);
    return element;
  }

  registerCustomElement(elementElement.attributes['name'], createElement);
}

/**
 * *Warning*: many features of this class are not fully implemented.
 *
 * The base class for Polymer elements. It provides convience features on top
 * of the custom elements web standard.
 *
 * Currently it supports publishing attributes via:
 *
 *     <element name="..." attributes="foo, bar, baz">
 *
 * Any attribute published this way can be used in a data binding expression,
 * and it should contain a corresponding DOM field.
 *
 * *Warning*: due to dart2js mirror limititations, the mapping from HTML
 * attribute to element property is a conversion from `dash-separated-words`
 * to camelCase, rather than searching for a property with the same name.
 */
// TODO(jmesserly): fix the dash-separated-words issue. Polymer uses lowercase.
abstract class PolymerElement extends CustomElement {
  // This is a partial port of:
  // https://github.com/Polymer/polymer/blob/stable/src/attrs.js
  // https://github.com/Polymer/polymer/blob/stable/src/bindProperties.js
  // TODO(jmesserly): we still need to port more of the functionality

  Map<String, PathObserver> _publishedAttrs;
  Map<String, StreamSubscription> _bindings;

  void _publishAttributes(Element elementElement) {
    _bindings = {};
    _publishedAttrs = {};

    var attrs = elementElement.attributes['attributes'];
    if (attrs != null) {
      // attributes='a b c' or attributes='a,b,c'
      for (var name in attrs.split(attrs.contains(',') ? ',' : ' ')) {
        name = name.trim();

        // TODO(jmesserly): PathObserver is overkill here; it helps avoid
        // "new Symbol" and other mirrors-related warnings.
        _publishedAttrs[name] = new PathObserver(this, toCamelCase(name));
      }
    }
  }

  void created() {
    // TODO(jmesserly): this breaks until we get some kind of type conversion.
    // _publishedAttrs.forEach((name, propObserver) {
    // var value = attributes[name];
    //   if (value != null) propObserver.value = value;
    // });
  }

  void bind(String name, model, String path) {
    var propObserver = _publishedAttrs[name];
    if (propObserver != null) {
      unbind(name);

      _bindings[name] = new PathObserver(model, path).bindSync((value) {
        propObserver.value = value;
      });
      return;
    }
    return super.bind(name, model, path);
  }

  void unbind(String name) {
    if (_bindings != null) {
      var binding = _bindings.remove(name);
      if (binding != null) {
        binding.cancel();
        return;
      }
    }
    return super.unbind(name);
  }

  void unbindAll() {
    for (var binding in _bindings.values) binding.cancel();
    _bindings.clear();
    return super.unbindAll();
  }
}
