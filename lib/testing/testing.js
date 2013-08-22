// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

(function() {
  var undoReplaceScripts = [];

  var flags = {};
  // populate flags from location
  location.search.slice(1).split('&').forEach(function(o) {
    o = o.split('=');
    o[0] && (flags[o[0]] = o[1] || true);
  });

  // Webkit is migrating from layoutTestController to testRunner, we use
  // layoutTestController as a fallback until that settles in.
  var runner = window.testRunner || window.layoutTestController;

  if (runner) {
    runner.dumpAsText();
    runner.waitUntilDone();
  }

  function dumpDOM() {
    // Undo any scripts that were modified.
    undoReplaceScripts.forEach(function(undo) { undo(); });

    function expandShadowRoot(node) {
      for (var n = node.firstChild; n; n = n.nextSibling) {
        expandShadowRoot(n);
      }
      var shadow = node.shadowRoot || node.webkitShadowRoot ||
          node.olderShadowRoot;

      if (shadow) {
        expandShadowRoot(shadow);

        var name = 'shadow-root';
        if (shadow == node.olderShadowRoot) name = 'older-' + name;

        var fakeShadow = document.createElement(name);
        while (shadow.firstChild) fakeShadow.appendChild(shadow.firstChild);
        node.insertBefore(fakeShadow, node.firstChild);
      }
    }

    // TODO(terry): Need to remove attributes in the dart-port: namespace these
    //              are added for JS interop. See bug https://code.google.com/p/dart/issues/detail?id=12645
    //              The new dart:js shouldn't need these attrs for dart2js or
    //              Dartium (won't need with native support) then remove the
    //              below code.
    var htmlTag = document.querySelector('html');
    if (htmlTag != null) {
      var attrs = htmlTag.attributes;
      for (var idx = attrs.length; idx--; idx >= 0) {
        var attr = attrs[idx];
        if (attr.name.indexOf("dart-port:") == 0) {
          htmlTag.removeAttributeNode(attr);
        }
      }
    }
    // Remove the JS Interop script.
    var scriptTags = document.querySelectorAll('script');
    for (var idx = scriptTags.length; idx--; idx >= 0) {
      var scriptTag = scriptTags[idx];
      var typeAttr = scriptTag.getAttributeNode("type");
      if (typeAttr != null && typeAttr.value == "text/javascript") {
        if (scriptTag.text.indexOf(
            "(function() {\n  // Proxy support for js.dart.\n\n") == 0) {
          scriptTag.parentNode.removeChild(scriptTag);
        }
      }
    }

    // TODO(jmesserly): use querySelector to workaround unwrapped "document".
    expandShadowRoot(document.querySelector('body'));

    var out = document.createElement('pre');
    out.textContent = document.documentElement.outerHTML;
    document.body.innerHTML = '';
    document.body.appendChild(out);
  }

  function messageHandler(e) {
    if (e.data == 'done' && runner) {
      // On success, dump the DOM. Convert shadowRoot contents into
      // <shadow-root>
      dumpDOM();
      runner.notifyDone();
    }
  }

  window.addEventListener('message', messageHandler, false);

  function errorHandler(e) {
    if (runner) {
      window.setTimeout(function() { runner.notifyDone(); }, 0);
    }
    window.console.log('FAIL');
  }

  window.addEventListener('error', errorHandler, false);

  if (navigator.webkitStartDart && !flags.js) {
    // TODO(jmesserly): fix this so we don't need to copy from browser/dart.js
    if (!navigator.webkitStartDart()) {
      document.body.innerHTML = 'This build has expired.  Please download a new Dartium at http://www.dartlang.org/dartium/index.html';
    }
  } else {
    if (flags.shadowdomjs) {
      // Allow flags to force polyfill of ShadowDOM so we can test it.
      window.__forceShadowDomPolyfill = true;
    }

    // TODO:
    // - Support in-browser compilation.
    // - Handle inline Dart scripts.
    window.addEventListener("DOMContentLoaded", function (e) {
      // Fall back to compiled JS. Run through all the scripts and
      // replace them if they have a type that indicate that they source
      // in Dart code.
      //
      //   <script type="application/dart" src="..."></script>
      //
      var scripts = document.getElementsByTagName("script");
      var length = scripts.length;
      for (var i = 0; i < length; ++i) {
        var script = scripts[i];
        if (script.type == "application/dart") {
          // Remap foo.dart to foo.dart.js.
          if (script.src && script.src != '') {
            var jsScript = document.createElement('script');
            jsScript.src = script.src.replace(/\.dart(?=\?|$)/, '.dart.js');
            var parent = script.parentNode;
            // TODO(vsm): Find a solution for issue 8455 that works with more
            // than one script.
            document.currentScript = jsScript;

            undoReplaceScripts.push(function() {
              parent.replaceChild(script, jsScript);
            });
            parent.replaceChild(jsScript, script);
          }
        }
      }
    }, false);
  }

})();
