// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library components;

typedef WebComponent ComponentFactory();

/** This is not a wrapper but rather a real live custom div. */
class FancyDivElement extends DivElementImpl implements WebComponent {
  ShadowRoot _root;

  static ComponentFactory _$constr;
  factory FancyDivElement.component() {
    if(_$constr == null) {
      _$constr = () => new FancyDivElement._internal();
    }
    var t1 = new DivElement();
    rewirePrototypeChain(t1, _$constr, 'NotAWrapper');
    return t1;
  }

  factory FancyDivElement() {
    return manager.expandHtml('<div is="x-not-a-wrapper"></div>');
  }

  FancyDivElement._internal();

  void created(ShadowRoot root) {
    _root = root;
    _idiomCount = 0;
  }

  void inserted() {
    _root.on.click.add((e) => _root.innerHtml = '<p>${generateIdiom()}</p>');
    print('[samhop] NotAWrapper inserted');
  }

  void attributeChanged(String name, String oldValue, String newValue) { }

  void removed() { }

  int _idiomCount;
  String generateIdiom() {
    _idiomCount++;
    if (_idiomCount > 2) {
      _idiomCount = 0;
    }
    switch(_idiomCount) {
      case 0 : return 'When it rains, it pours!';
      case 1 : return "There's no such thing as bad publicity.";
      case 2 : return "I don't think we're in Kansas anymore, Toto.";
    };
  }
}
