// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/** Collects several code emitters for the template tool. */
library emitters;

import 'package:csslib/parser.dart' as css;
import 'package:csslib/visitor.dart';
import 'package:html5lib/dom.dart';
import 'package:html5lib/dom_parsing.dart';
import 'package:html5lib/parser.dart';
import 'package:source_maps/span.dart' show Span, FileLocation;

import 'code_printer.dart';
import 'compiler.dart';
import 'dart_parser.dart' show DartCodeInfo;
import 'html5_utils.dart';
import 'html_css_fixup.dart';
import 'info.dart';
import 'messages.dart';
import 'compiler_options.dart';
import 'paths.dart';
import 'refactor.dart';
import 'utils.dart';


/** Only x-tag name element selectors are emitted as [is="x-"]. */
class CssEmitter extends CssPrinter {
  final Set _componentsTag;

  CssEmitter(this._componentsTag);

  /**
   * If element selector is a component's tag name, then change selector to
   * find element who's is attribute's the component's name.
   */
  bool _emitComponentElement(ElementSelector node) {
    if (_componentsTag.contains(node.name)) {
      emit('[is="${node.name}"]');
      return true;
    }
    return false;
  }

  void visitElementSelector(ElementSelector node) {
    if (_componentsTag.isNotEmpty && _emitComponentElement(node)) return;
    super.visitElementSelector(node);
  }

}

/**
 * Style sheet polyfill for a component, each CSS class name/id selector
 * referenced (selector) is prepended with prefix_ (if prefix is non-null).  In
 * addition an element selector this is a component's tag name is transformed
 * to the attribute selector [is="x-"] where x- is the component's tag name.
 */
class ComponentCssEmitter extends CssPrinter {
  final String _componentTagName;
  final CssPolyfillKind _polyfillKind;
  bool _inHostDirective = false;
  bool _selectorStartInHostDirective = false;

  ComponentCssEmitter(this._componentTagName, this._polyfillKind);

  /** Is the element selector an x-tag name. */
  bool _isSelectorElementXTag(Selector node) {
    if (node.simpleSelectorSequences.length > 0) {
      var selector = node.simpleSelectorSequences[0].simpleSelector;
      return selector is ElementSelector && selector.name == _componentTagName;
    }
    return false;
  }

  /**
   * If element selector is the component's tag name, then change selector to
   * find element who's is attribute is the component's name.
   */
  bool _emitComponentElement(ElementSelector node) {
    if (_polyfillKind == CssPolyfillKind.SCOPED_POLYFILL &&
        _componentTagName == node.name) {
      emit('[is="$_componentTagName"]');
      return true;
    }
    return false;
  }

  void visitSelector(Selector node) {
    // If the selector starts with an x-tag name don't emit it twice.
    if (!_isSelectorElementXTag(node) &&
        _polyfillKind == CssPolyfillKind.SCOPED_POLYFILL) {
      if (_inHostDirective) {
        // Style the element that's hosting the component, therefore don't emit
        // the descendent combinator (first space after the [is="x-..."]).
        emit('[is="$_componentTagName"]');
        // Signal that first simpleSelector must be checked.
        _selectorStartInHostDirective = true;
      } else {
        // Emit its scoped as a descendent (space at end).
        emit('[is="$_componentTagName"] ');
      }
    }
    super.visitSelector(node);
  }

  /**
   * If first simple selector of a ruleset in a @host directive is a wildcard
   * then don't emit the wildcard.
   */
  void visitSimpleSelectorSequence(SimpleSelectorSequence node) {
    if (_selectorStartInHostDirective) {
      _selectorStartInHostDirective = false;
      if (_polyfillKind == CssPolyfillKind.SCOPED_POLYFILL &&
          node.simpleSelector.isWildcard) {
        // Skip the wildcard if first item in the sequence.
        return;
      }
      assert(node.isCombinatorNone);
    }

    super.visitSimpleSelectorSequence(node);
  }

  void visitClassSelector(ClassSelector node) {
    if (_polyfillKind == CssPolyfillKind.MANGLED_POLYFILL) {
      emit('.${_componentTagName}_${node.name}');
    } else {
      super.visitClassSelector(node);
    }
  }

  void visitIdSelector(IdSelector node) {
    if (_polyfillKind == CssPolyfillKind.MANGLED_POLYFILL) {
      emit('#${_componentTagName}_${node.name}');
    } else {
      super.visitIdSelector(node);
    }
  }

  void visitElementSelector(ElementSelector node) {
    if (_emitComponentElement(node)) return;
    super.visitElementSelector(node);
  }

  /**
   * If we're polyfilling scoped styles the @host directive is stripped.  Any
   * ruleset(s) processed in an @host will fixup the first selector.  See
   * visitSelector and visitSimpleSelectorSequence in this class, they adjust
   * the selectors so it styles the element hosting the compopnent.
   */
  void visitHostDirective(HostDirective node) {
    if (_polyfillKind == CssPolyfillKind.SCOPED_POLYFILL) {
      _inHostDirective = true;
      emit('/* @host */');
      for (var ruleset in node.rulesets) {
        ruleset.visit(this);
      }
      _inHostDirective = false;
      emit('/* end of @host */\n');
    } else {
      super.visitHostDirective(node);
    }
  }
}

/**
 * Helper function to emit the contents of the style tag outside of a component.
 */
String emitStyleSheet(StyleSheet ss, FileInfo file) =>
  (new CssEmitter(file.components.keys.toSet())
      ..visitTree(ss, pretty: true)).toString();

/** Helper function to emit a component's style tag content. */
String emitComponentStyleSheet(StyleSheet ss, String tagName,
                               CssPolyfillKind polyfillKind) =>
  (new ComponentCssEmitter(tagName, polyfillKind)
      ..visitTree(ss, pretty: true)).toString();

/** Generates the class corresponding to a single web component. */
class WebComponentEmitter {
  final Messages messages;
  final FileInfo _fileInfo;
  final CssPolyfillKind cssPolyfillKind;

  WebComponentEmitter(this._fileInfo, this.messages, this.cssPolyfillKind);

  CodePrinter run(ComponentInfo info, PathMapper pathMapper,
      TextEditTransaction transaction) {
    var templateNode = info.element.nodes.firstWhere(
        (n) => n.tagName == 'template', orElse: () => null);

    if (templateNode != null) {
      if (!info.styleSheets.isEmpty && !messages.options.processCss) {
        // TODO(terry): Only one style tag per component.

        // TODO(jmesserly): csslib + html5lib should work together.
        // We shouldn't need to call a different function to serialize CSS.
        // Calling innerHtml on a StyleElement should be enought - like a real
        // browser. CSSOM and DOM should work together in the same tree.
        var styleText = emitComponentStyleSheet(
            info.styleSheets[0], info.tagName, cssPolyfillKind);

        templateNode.insertBefore(
            new Element.html('<style>\n$styleText\n</style>'),
            templateNode.hasChildNodes() ? templateNode.children[0] : null);
      }
    }

    bool hasExtends = info.extendsComponent != null;
    var codeInfo = info.userCode;
    var classDecl = info.classDeclaration;
    if (classDecl == null) return null;

    if (transaction == null) {
      transaction = new TextEditTransaction(codeInfo.code, codeInfo.sourceFile);
    }

    // Expand the headers to include polymer imports, unless they are already
    // present.
    var libraryName = (codeInfo.libraryName != null)
        ? codeInfo.libraryName
        : info.tagName.replaceAll(new RegExp('[-./]'), '_');
    var header = new CodePrinter(0);
    header.add(_header(path.basename(info.declaringFile.inputUrl.resolvedPath),
        libraryName));
    emitImports(codeInfo, info, pathMapper, header);
    header.addLine('');
    transaction.edit(0, codeInfo.directivesEnd, header);

    var classBody = new CodePrinter(1)
        ..add('\n')
        ..addLine('/** Original code from the component. */');

    var pos = classDecl.leftBracket.end;
    transaction.edit(pos, pos, classBody);

    // Emit all the code in a single printer, keeping track of source-maps.
    return transaction.commit();
  }
}

/** The code that will be used to bootstrap the application. */
CodePrinter generateBootstrapCode(
    FileInfo info, FileInfo userMainInfo, GlobalInfo global,
    PathMapper pathMapper, CompilerOptions options) {

  var printer = new CodePrinter(0)
      ..addLine('library app_bootstrap;')
      ..addLine('')
      ..addLine("import 'package:polymer/polymer.dart';")
      ..addLine("import 'dart:mirrors' show currentMirrorSystem;");

  if (userMainInfo.userCode != null) {
    printer..addLine('')
        ..addLine("import '${pathMapper.importUrlFor(info, userMainInfo)}' "
            "as userMain;\n");
  }

  int i = 0;
  for (var c in global.components.values) {
    if (c.hasConflict) continue;
    printer.addLine("import '${pathMapper.importUrlFor(info, c)}' as i$i;");
    i++;
  }

  printer..addLine('')
      ..addLine('void main() {')
      ..indent += 1
      ..addLine("initPolymer([")
      ..indent += 2;

  for (var c in global.components.values) {
    if (c.hasConflict) continue;
    var tagName = escapeDartString(c.tagName);
    var cssMapExpression = createCssSelectorsExpression(c,
        CssPolyfillKind.of(options, c));
    printer.addLine("'${pathMapper.importUrlFor(info, c)}',");
  }

  return printer
      ..indent -= 1
      ..addLine('],')
      ..addLine(userMainInfo.userCode != null ? 'userMain.main,' : '() {},')
      ..addLine(
          "currentMirrorSystem().findLibrary(const Symbol('app_bootstrap'))")
      ..indent += 2
      ..addLine(".first.uri.toString());")
      ..indent -= 4
      ..addLine('}');
}



/**
 * List of HTML4 elements which could have relative URL resource:
 *
 * <body background=url>, <img src=url>, <input src=url>
 *
 * HTML 5:
 *
 * <audio src=url>, <command icon=url>, <embed src=url>,
 * <source src=url>, <video poster=url> and <video src=url>
*/
class AttributeUrlTransform extends TreeVisitor {
  final String filePath;
  final PathMapper pathMapper;

  AttributeUrlTransform(this.filePath, this.pathMapper);

  visitElement(Element node) {
    if (node.tagName == 'script') return;
    if (node.tagName == 'link') return;

    for (var key in node.attributes.keys) {
      if (urlAttributes.contains(key)) {
        // Rewrite the URL attribute.
        node.attributes[key] = pathMapper.transformUrl(filePath,
            node.attributes[key]);
      }
    }

    super.visitElement(node);
  }
}

void _transformRelativeUrlAttributes(Document document, PathMapper pathMapper,
                                     String filePath) {
  // Transform any element's attribute which is a relative URL.
  new AttributeUrlTransform(filePath, pathMapper).visit(document);
}

void emitImports(DartCodeInfo codeInfo, LibraryInfo info, PathMapper pathMapper,
    CodePrinter printer, [GlobalInfo global]) {
  var seenImports = new Set();
  addUnique(String importString, [location]) {
    if (!seenImports.contains(importString)) {
      printer.addLine(importString, location: location);
      seenImports.add(importString);
    }
  }

  // Add imports only for those components used by this component.
  for (var c in info.usedComponents.keys) {
    addUnique("import '${pathMapper.importUrlFor(info, c)}';");
  }

  if (global != null) {
    for (var c in global.components.values) {
      addUnique("import '${pathMapper.importUrlFor(info, c)}';");
    }
  }

  if (info is ComponentInfo) {
    // Inject an import to the base component.
    var base = (info as ComponentInfo).extendsComponent;
    if (base != null) {
      addUnique("import '${pathMapper.importUrlFor(info, base)}';");
    }
  }

  // Add existing import, export, and part directives.
  var file = codeInfo.sourceFile;
  for (var d in codeInfo.directives) {
    addUnique(d.toString(), file != null ? file.location(d.offset) : null);
  }
}

final shadowDomJS = new RegExp(r'shadowdom\..*\.js', caseSensitive: false);
final bootJS = new RegExp(r'.*/polymer/boot.js', caseSensitive: false);

/** Trim down the html for the main html page. */
void transformMainHtml(Document document, FileInfo fileInfo,
    PathMapper pathMapper, bool hasCss, bool rewriteUrls,
    Messages messages, GlobalInfo global) {
  var filePath = fileInfo.inputUrl.resolvedPath;

  bool dartLoaderFound = false;
  bool shadowDomFound = false;
  for (var tag in document.queryAll('script')) {
    var src = tag.attributes['src'];
    if (src != null) {
      var last = src.split('/').last;
      if (last == 'dart.js' || last == 'testing.js') {
        dartLoaderFound = true;
      } else if (shadowDomJS.hasMatch(last)) {
        shadowDomFound = true;
      }
    }
    if (tag.attributes['type'] == 'application/dart') {
      tag.remove();
    } else if (src != null) {
      if (bootJS.hasMatch(src)) {
        tag.remove();
      } else if (rewriteUrls) {
        tag.attributes["src"] = pathMapper.transformUrl(filePath, src);
      }
    }
  }

  for (var tag in document.queryAll('link')) {
    var href = tag.attributes['href'];
    var rel = tag.attributes['rel'];
    if (rel == 'component' || rel == 'components' || rel == 'import') {
      tag.remove();
    } else if (href != null && rewriteUrls && !hasCss) {
      // Only rewrite URL if rewrite on and we're not CSS polyfilling.
      tag.attributes['href'] = pathMapper.transformUrl(filePath, href);
    }
  }

  if (rewriteUrls) {
    // Transform any element's attribute which is a relative URL.
    _transformRelativeUrlAttributes(document, pathMapper, filePath);
  }

  if (hasCss) {
    var newCss = pathMapper.mangle(path.basename(filePath), '.css', true);
    var linkElem = new Element.html(
        '<link rel="stylesheet" type="text/css" href="$newCss">');
    document.head.insertBefore(linkElem, null);
  }

  var styles = document.queryAll('style');
  if (styles.length > 0) {
    var allCss = new StringBuffer();
    fileInfo.styleSheets.forEach((styleSheet) =>
        allCss.write(emitStyleSheet(styleSheet, fileInfo)));
    styles[0].nodes.clear();
    styles[0].nodes.add(new Text(allCss.toString()));
    for (var i = styles.length - 1; i > 0 ; i--) {
      styles[i].remove();
    }
  }

  // TODO(jmesserly): put this in the global CSS file?
  // http://dvcs.w3.org/hg/webcomponents/raw-file/tip/spec/templates/index.html#css-additions
  document.head.nodes.insert(0, parseFragment(
      '<style>template { display: none; }</style>'));

  // Move all <element> declarations to the main HTML file
  // TODO(sigmund): remove this once we have HTMLImports implemented.
  for (var c in global.components.values) {
    document.body.nodes.insert(0, new Text('\n'));
    var fragment = c.element;
    for (var tag in fragment.queryAll('script')) {
      // TODO(sigmund): leave script tags around when we start using "boot.js"
      if (tag.attributes['type'] == 'application/dart') {
        tag.remove();
      }
    }
    document.body.nodes.insert(0, fragment);
  }


  if (!shadowDomFound) {
    // TODO(jmesserly): we probably shouldn't add this automatically.
    document.body.nodes.add(parseFragment('<script type="text/javascript" '
        'src="packages/shadow_dom/shadow_dom.debug.js"></script>\n'));
  }
  if (!dartLoaderFound) {
    // TODO(jmesserly): turn this warning on.
    //messages.warning('Missing script to load Dart. '
    //    'Please add this line to your HTML file: $dartLoader',
    //    document.body.sourceSpan);
    // TODO(sigmund): switch to 'boot.js'
    document.body.nodes.add(parseFragment('<script type="text/javascript" '
        'src="packages/browser/dart.js"></script>\n'));
  }

  // Insert the "auto-generated" comment after the doctype, otherwise IE will
  // go into quirks mode.
  int commentIndex = 0;
  DocumentType doctype = find(document.nodes, (n) => n is DocumentType);
  if (doctype != null) {
    commentIndex = document.nodes.indexOf(doctype) + 1;
    // TODO(jmesserly): the html5lib parser emits a warning for missing
    // doctype, but it allows you to put it after comments. Presumably they do
    // this because some comments won't force IE into quirks mode (sigh). See
    // this link for more info:
    //     http://bugzilla.validator.nu/show_bug.cgi?id=836
    // For simplicity we emit the warning always, like validator.nu does.
    if (doctype.tagName != 'html' || commentIndex != 1) {
      messages.warning('file should start with <!DOCTYPE html> '
          'to avoid the possibility of it being parsed in quirks mode in IE. '
          'See http://www.w3.org/TR/html5-diff/#doctype', doctype.sourceSpan);
    }
  }
  document.nodes.insert(commentIndex, parseFragment(
      '\n<!-- This file was auto-generated from $filePath. -->\n'));
}

/** Header with common imports, used in every generated .dart file. */
String _header(String filename, String libraryName) {
  var lib = libraryName != null ? '\nlibrary $libraryName;\n' : '';
  return """
// Auto-generated from $filename.
// DO NOT EDIT.
$lib
import 'dart:html' as autogenerated;
import 'dart:svg' as autogenerated_svg;
import 'package:mdv/mdv.dart' as autogenerated_mdv;
import 'package:observe/observe.dart' as __observe;
import 'package:polymer/polymer.dart' as autogenerated;
""";
}
