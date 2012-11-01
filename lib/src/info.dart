// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * Datatypes holding information extracted by the analyzer and used by later
 * phases of the compiler.
 */
library info;

import 'dart:collection' show SplayTreeMap;
import 'dart:coreimpl';
import 'dart:uri';

import 'package:html5lib/dom.dart';

import 'file_system/path.dart';
import 'files.dart';
import 'messages.dart';
import 'utils.dart';


/** Information about input, base, and output path locations. */
class PathInfo {
  /**
   * Common prefix to all input paths that are read from the file system. The
   * output generated by the compiler will reflect the directory structure
   * starting from [_baseDir]. For instance, if [_baseDir] is `a/b/c` and
   * [_outputDir] is `g/h/`, then the corresponding output file for
   * `a/b/c/e/f.html` will be under `g/h/e/f.html.dart`.
   */
  final Path _baseDir;

  /** Base path where all output is generated. */
  final Path _outputDir;

  /** Default prefix added to all filenames. */
  static const String _DEFAULT_PREFIX = '_';

  PathInfo(this._baseDir, this._outputDir);

  /**
   * The path to the output file corresponding to [input], by adding
   * [_DEFAULT_PREFIX] and a [suffix] to its file name.
   */
  Path outputPath(Path input, String suffix) {
    var newName = '$_DEFAULT_PREFIX${input.filename}$suffix';
    return _outputDirPath(input).append(newName);
  }

  /** The path to the output file corresponding to [info]. */
  Path outputLibraryPath(LibraryInfo info) {
    return _outputDirPath(info.inputPath).append(info.outputFilename);
  }

  /** The corresponding output directory for [input]'s directory. */
  Path _outputDirPath(Path input) {
    var outputSubdir = input.directoryPath.relativeTo(_baseDir);
    return _outputDir.join(outputSubdir).canonicalize();
  }

  /** Path for a file directly under [_outputDir] with the given [filename]. */
  Path fileInOutputDir(String filename) {
    return _outputDir.append(filename);
  }

  /**
   * Returns a relative path to import/export the output library represented by
   * [target] from the output library of [src]. In other words, a path to import
   * or export `target.outputFilename` from `src.outputFilename`.
   */
  static Path relativePath(LibraryInfo src, LibraryInfo target) {
    var srcDir = src.inputPath.directoryPath;
    var relDir = target.inputPath.directoryPath.relativeTo(srcDir);
    return relDir.append(target.outputFilename).canonicalize();
  }

  /**
   * Returns the relative path to import the output library represented [info]
   * from a file at the top-level output directory.
   */
  Path relativePathFromOutputDir(LibraryInfo info) {
    var relativeDir = info.inputPath.directoryPath.relativeTo(_baseDir);
    return relativeDir.append(info.outputFilename).canonicalize();
  }

  /**
   * Transforms a [target] url seen in `src.inputPath` (e.g. a Dart import, a
   * .css href in an HTML file, etc) into a corresponding url from the output
   * library of [src]. This will keep 'package:', 'dart:', path-absolute, and
   * absolute urls intact, but it will fix relative paths to walk from the
   * output directory back to the input directory. An exception will be thrown
   * if [target] is not under [_baseDir].
   */
  String transformUrl(LibraryInfo src, String target) {
    if (new Uri.fromString(target).isAbsolute()) return target;
    var path = new Path(target);
    if (path.isAbsolute) return target;
    var pathToTarget = src.inputPath.directoryPath.join(path);
    var outputLibraryDir = _outputDirPath(src.inputPath);
    return pathToTarget.relativeTo(outputLibraryDir).canonicalize().toString();
  }
}

/**
 * Information for any library-like input. We consider each HTML file a library,
 * and each component declaration a library as well. Hence we use this as a base
 * class for both [FileInfo] and [ComponentInfo]. Both HTML files and components
 * can have .dart code provided by the user for top-level user scripts and
 * component-level behavior code. This code can either be inlined in the HTML
 * file or included in a script tag with the "src" attribute.
 */
abstract class LibraryInfo {

  /** Whether there is any code associated with the page/component. */
  bool get codeAttached => inlinedCode != null || externalFile != null;

  /**
   * The actual code, either inlined or from an external file, or `null` if none
   * was defined.
   */
  DartCodeInfo userCode;

  /** The inlined code, if any. */
  String inlinedCode;

  /** The name of the file sourced in a script tag, if any. */
  Path externalFile;

  /** Info asscociated with [externalFile], if any. */
  FileInfo externalCode;

  /** File where the top-level code was defined. */
  Path get inputPath;

  /**
   * Name of the file that will hold any generated Dart code for this library
   * unit.
   */
  String get outputFilename;

  /**
   * Components used within this library unit. For [FileInfo] these are
   * components used directly in the page. For [ComponentInfo] these are
   * components used within their shadowed template.
   */
  final Map<ComponentInfo, bool> usedComponents =
      new LinkedHashMap<ComponentInfo, bool>();
}

/** Information extracted at the file-level. */
class FileInfo extends LibraryInfo {
  /** Relative path to this file from the compiler's base directory. */
  final Path path;

  /**
   * Whether this is the entry point of the web app, i.e. the file users
   * navigate to in their browser.
   */
  final bool isEntryPoint;

  // TODO(terry): Ensure that that the libraryName is a valid identifier:
  //              a..z || A..Z || _ [a..z || A..Z || 0..9 || _]*
  String get libraryName => path.filename.replaceAll('.', '_');

  /** File where the top-level code was defined. */
  Path get inputPath => externalFile != null ? externalFile : path;

  /** Name of the file that will hold any generated Dart code. */
  String get outputFilename => '_${inputPath.filename}.dart';

  /**
   * All custom element definitions in this file. This may contain duplicates.
   * Normally you should use [components] for lookup.
   */
  final List<ComponentInfo> declaredComponents = new List<ComponentInfo>();

  /**
   * All custom element definitions defined in this file or imported via
   *`<link rel='components'>` tag. Maps from the tag name to the component
   * information. This map is sorted by the tag name.
   */
  final Map<String, ComponentInfo> components =
      new SplayTreeMap<String, ComponentInfo>();

  /** Files imported with `<link rel="component">` */
  final List<Path> componentLinks = <Path>[];

  /** Root is associated with the body info. */
  ElementInfo bodyInfo;

  FileInfo([this.path, this.isEntryPoint = false]);

  /**
   * Query for an ElementInfo matching the provided [tag], starting from the
   * [bodyInfo].
   */
  ElementInfo query(String tag) => new _QueryInfo(tag).visit(bodyInfo);
}

/** Information about a web component definition. */
class ComponentInfo extends LibraryInfo {

  /** The file that declares this component. */
  final FileInfo declaringFile;

  /** The component tag name, defined with the `name` attribute on `element`. */
  final String tagName;

  /**
   * The tag name that this component extends, defined with the `extends`
   * attribute on `element`.
   */
  final String extendsTag;

  /**
   * The component info associated with the [extendsTag] name, if any.
   * This will be `null` if the component extends a built-in HTML tag, or
   * if the analyzer has not run yet.
   */
  ComponentInfo extendsComponent;

  /** The Dart class containing the component's behavior. */
  final String constructor;

  /** Component's ElementInfo at the element tag. */
  ElementInfo elemInfo;

  /** The declaring `<element>` tag. */
  final Node element;

  /** The component's `<template>` tag, if any. */
  final Node template;

  /** File where this component was defined. */
  Path get inputPath =>
      externalFile != null ? externalFile : declaringFile.path;

  /**
   * Name of the file that will be generated for this component. We want to
   * generate a separate library for each component, unless their code is
   * already in an external library (e.g. [externalCode] is not null). Multiple
   * components could be defined inline within the HTML file, so we return a
   * unique file name for each component.
   */
  String get outputFilename {
    if (externalFile != null) return '_${externalFile.filename}.dart';
    var prefix = declaringFile.path.filename;
    var componentSegment = tagName.toLowerCase().replaceAll('-', '_');
    return '_$prefix.$componentSegment.dart';
  }

  /**
   * True if [tagName] was defined by more than one component. If this happened
   * we will skip over the component.
   */
  bool hasConflict = false;

  ComponentInfo(Element element, this.declaringFile)
    : element = element,
      tagName = element.attributes['name'],
      extendsTag = element.attributes['extends'],
      constructor = element.attributes['constructor'],
      template = _getTemplate(element);

  static _getTemplate(element) {
    List template = element.nodes.filter((n) => n.tagName == 'template');
    return template.length == 1 ? template[0] : null;
  }
}

/** Base tree visitor for the Analyzer infos. */
class InfoVisitor {
  visit(info) {
    if (info == null) return;
    if (info is TemplateInfo) {
      return visitTemplateInfo(info);
    } else if (info is ElementInfo) {
      return visitElementInfo(info);
    } else if (info is ComponentInfo) {
      return visitComponentInfo(info);
    } else if (info is FileInfo) {
      return visitFileInfo(info);
    } else {
      throw new UnsupportedError('Unknown info type: $info');
    }
  }

  visitChildren(ElementInfo info) {
    for (var child in info.children) visit(child);
  }

  visitFileInfo(FileInfo info) {
    visit(info.bodyInfo);
    info.declaredComponents.forEach(visit);
  }

  visitTemplateInfo(TemplateInfo info) => visitElementInfo(info);

  visitElementInfo(ElementInfo info) => visitChildren(info);

  visitComponentInfo(ComponentInfo info) => visit(info.elemInfo);
}

// TODO(terry): ElementInfo should associated with elements, rather than
// nodes. There are cases with the node is pointing to a text node, maybe
// have a 'NodeInfo' rather than an 'ElementInfo'.
/** Information extracted for each node in a template. */
class ElementInfo {
  // TODO(jmesserly): ideally we should only create Infos for things that need
  // an identifier. So this would always be non-null. That is not the case yet.
  /**
   * The name used to refer to this element in Dart code.
   * Depending on the context, this can be a variable or a field.
   */
  String identifier;

  /** Info for the nearest enclosing element, iterator, or conditional. */
  final ElementInfo parent;

  // TODO(jmesserly): make childen work like DOM children collection, so that
  // adding/removing a node updates the parent pointer.
  final List<ElementInfo> children = [];

  // TODO(terry): ElementInfo Should associated with elements, rather than
  // nodes. In this case, we are creating a text node, so we should maybe
  // have a 'NodeInfo' rather than an 'ElementInfo' in that case.
  /** DOM node associated with this ElementInfo. */
  final Node node;

  /**
   * Whether code generators need to create a field to store a reference to this
   * element. This is typically true whenever we need to access the element
   * (e.g. to add event listeners, update values on data-bound watchers, etc).
   */
  bool get needsIdentifier => hasDataBinding || hasIfCondition || hasIterate
      || component != null || values.length > 0 || events.length > 0
      || !needsQuery;

  // TODO(jmesserly): it'd be nice if we didn't need to query.
  /**
   * True if we need to query to get this node. Otherwise, we'll create it
   * from code. We always query except for "if" and "iterate" templates where
   * the children are constructed directly.
   */
  bool get needsQuery => parent == null || !parent.isIterateOrIf;

  /**
   * If this element is a web component instantiation (e.g. `<x-foo>`), this
   * will be set to information about the component, otherwise it will be null.
   */
  ComponentInfo component;

  /** Whether the element contains data bindings. */
  bool hasDataBinding = false;

  // TODO(jmesserly): this doesn't work with child elements (issue #133).
  /** Data-bound expression used in the contents of the node. */
  String contentBinding;

  /**
   * Expression that returns the contents of the node (given it has a
   * data-bound expression in it).
   */
  // TODO(terry,sigmund): support more than 1 expression in the contents.
  String contentExpression;

  /** Generated watcher disposer that watchs for the content expression. */
  // TODO(sigmund): move somewhere else?
  String stopperName;

  // Note: we're using sorted maps so items are enumerated in a consistent order
  // between runs, resulting in less "diff" in the generated code.
  // TODO(jmesserly): An alternative approach would be to use LinkedHashMap to
  // preserve the order of the input, but we'd need to be careful about our tree
  // traversal order.

  /** Collected information for attributes, if any. */
  final Map<String, AttributeInfo> attributes =
      new SplayTreeMap<String, AttributeInfo>();

  /** Collected information for UI events on the corresponding element. */
  final Map<String, List<EventInfo>> events =
      new SplayTreeMap<String, List<EventInfo>>();

  /** Collected information about `data-value="name:value"` expressions. */
  final Map<String, String> values = new SplayTreeMap<String, String>();

  /** Whether the template element has `iterate="... in ...". */
  bool get hasIterate => false;

  /** Whether the template element has an `instantiate="if ..."` conditional. */
  bool get hasIfCondition => false;

  bool get isIterateOrIf => hasIterate || hasIfCondition;

  ElementInfo(this.node, this.parent) {
    if (parent != null) parent.children.add(this);
  }

  String toString() => '#<ElementInfo '
      'identifier: $identifier, '
      'needsIdentifier: $needsIdentifier, '
      'needsQuery: $needsQuery, '
      'component: $component, '
      'hasIterate: $hasIterate, '
      'hasIfCondition: $hasIfCondition, '
      'hasDataBinding: $hasDataBinding, '
      'contentBinding: $contentBinding, '
      'contentExpression: $contentExpression, '
      'attributes: $attributes, '
      'events: $events>';
}

/** Information extracted for each attribute in an element. */
class AttributeInfo {

  /**
   * Whether this is a `class` attribute. In which case more than one binding
   * is allowed (one per class).
   */
  bool isClass = false;

  /**
   * A value that will be monitored for changes. All attributes, except `class`,
   * have a single bound value.
   */
  String get boundValue => bindings[0];

  /** All bound values that would be monitored for changes. */
  List<String> bindings;

  AttributeInfo(String value) : bindings = [value];
  AttributeInfo.forClass(this.bindings) : isClass = true;

  String toString() => '#<AttributeInfo '
      'isClass: $isClass, values: ${Strings.join(bindings, "")}>';

  /**
   * Generated fields for watcher disposers based on the bindings of this
   * attribute.
   */
  List<String> stopperNames;
}

/** Information extracted for each declared event in an element. */
class EventInfo {
  /** Event name for attributes representing actions. */
  final String eventName;

  /** Action associated for event listener attributes. */
  final ActionDefinition action;

  /** Generated field name, if any, associated with this event. */
  String listenerField;

  EventInfo(this.eventName, this.action);

  String toString() => '#<EventInfo eventName: $eventName, action: $action>';
}

class TemplateInfo extends ElementInfo {
  /**
   * The expression that is used in `<template instantiate="if cond">
   * conditionals, or null if this there is no `instantiate="if ..."`
   * attribute.
   */
  final String ifCondition;

  /**
   * If this is a `<template iterate="item in items">`, this is the variable
   * declared on loop iterations, e.g. `item`. This will be null if it is not
   * a `<template iterate="...">`.
   */
  final String loopVariable;

  /**
   * If this is a `<template iterate="item in items">`, this is the expression
   * to get the items to iterate over, e.g. `items`. This will be null if it is
   * not a `<template iterate="...">`.
   */
  final String loopItems;

  TemplateInfo(Node node, ElementInfo parent,
      {this.ifCondition, this.loopVariable, this.loopItems})
      : super(node, parent);

  /**
   * True when [node] is a '<template>' tag. False when [node] is any other
   * element type and the template information is attached as an attribute.
   */
  bool get isTemplateElement => node.tagName == 'template';

  bool get hasIfCondition => ifCondition != null;

  bool get hasIterate => loopVariable != null;

  // TODO(jmesserly): this is wrong if we want to support document fragments.
  ElementInfo get childInfo {
    for (var info in children) {
      if (info.node is Element) return info;
    }
    return null;
  }

  String toString() => '#<TemplateInfo ${super.toString()}'
      'ifCondition: $ifCondition, '
      'loopVariable: $ifCondition, '
      'loopItems: $ifCondition>';
}

/**
 * Specifies the action to take on a particular event. Some actions need to read
 * attributes from the DOM element that has the event listener (e.g. two way
 * bindings do this). [elementVarName] stores a reference to this element, and
 * [eventArgName] stores a reference to the event parameter name.
 * They are generated outside of the analyzer (in the emitter), so they are
 * passed here as arguments.
 */
typedef String ActionDefinition(String elemVarName, String eventArgName);

/** Information extracted from a source Dart file. */
class DartCodeInfo {
  /** Library qualified identifier, if any. */
  final String libraryName;

  /** Library which the code is part-of, if any. */
  final String partOf;

  /** Declared imports, exports, and parts. */
  final List<DartDirectiveInfo> directives;

  /** The rest of the code. */
  final String code;

  DartCodeInfo(this.libraryName, this.partOf, this.directives, this.code);
}

/** Information about a single import/export/part directive. */
class DartDirectiveInfo {
  /** Directive's label: import, export, or part. */
  String label;

  /** Referenced uri being imported, exported, or included by a part. */
  String uri;

  /** Prefix used for imports, if any. */
  String prefix;

  /** Hidden identifiers. */
  List<String> hide;

  /** Shown identifiers. */
  List<String> show;

  DartDirectiveInfo(this.label, this.uri, [this.prefix, this.hide, this.show]);
}


/**
 * Find ElementInfo that associated with a particular DOM node.
 * Used by [ElementInfo.query].
 */
class _QueryInfo extends InfoVisitor {
  final String _tagName;

  _QueryInfo(this._tagName);

  visitElementInfo(ElementInfo info) {
    if (info.node.tagName == _tagName) {
      return info;
    }

    return super.visitElementInfo(info);
  }

  visitChildren(ElementInfo info) {
    for (var child in info.children) {
      var result = visit(child);
      if (result != null) return result;
    }
    return null;
  }
}
