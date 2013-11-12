Web UI 0.4 (deprecated, newer versions in [Polymer.dart](https://pub.dartlang.org/packages/polymer))
===========

**PLEASE NOTE**: web_ui was renamed, and versions >= 0.5 can be found in the [Polymer.dart package](https://pub.dartlang.org/packages/polymer) instead.
There have been a number of breaking changes since 0.4, you can read about [how to migrate here](https://www.dartlang.org/polymer-dart/#upgrading-from-web-ui).
Please feel free to [reach out to us](https://www.dartlang.org/polymer-dart/#support) with migration questions.

Documentation [about Web UI 0.4](https://www.dartlang.org/articles/web-ui/) is
still available for those that are building production applications on top of
this package.

Introduction
-----------

Web UI lets you build web apps as if you had a browser from the future. You can
use the cool new web technologies like [Web Components][wc],
and features like dynamic templates and live data binding inspired by
[Model Driven Views][mdv] and [Dart][d] today. Build apps easily using HTML as
your template language, express your application's components in HTML, and
synchronize your data automatically between Dart and your components.

We believe that:

- Web Components and MDV are on their way, we should start using them now.
- Cool new features should be made available to [modern browsers][mb] that
  haven't yet implemented them.
- Write/reload is just as important as write/compile/minimize/ship.
- Working in open source is the way to go.
- Developers from all backgrounds should be building awesome modern web apps.

[![Build Status](https://drone.io/github.com/dart-lang/web-ui/status.png)](https://drone.io/github.com/dart-lang/web-ui/latest)

Try It Now
-----------
Add the Web UI package to your pubspec.yaml file:

```yaml
dependencies:
  web_ui: any
```

Instead of using `any`, we recommend using version ranges to avoid getting your project broken on each release. Using a version range lets you upgrade your package at your own pace:

```yaml
dependencies:
  web_ui: ">=0.4.8 <0.4.9"
```

We update versions within the range when we release small bug fixes. For instance, `0.4.8+1` is considered
a non-breaking change. We change versions outside of the range when we introduce a breaking change. See our
[changelog][changelog] to find the version that works best for you.


Learn More
----------

* [Read an overview][overview]
* [Setup your tools][tools]
* [Browse the features][features]
* [Dive into the specification][spec]

See our [TodoMVC][] example [running][todo_live]. Read the
[README.md][todo_readme] in `example/todomvc` for more details.


Running Tests
-------------

Dependencies are installed using the [Pub Package Manager][pub].
```bash
pub install

# Run command line tests and automated end-to-end tests. It needs two
# executables on your path: `dart` and `content_shell` (see below
# for links to download `content_shell`)
test/run.sh
```
Note: to run browser tests you will need to have [content_shell][cs],
which can be downloaded prebuilt for [Ubuntu Lucid][cs_lucid],
[Windows][cs_win], or [Mac][cs_mac]. You can also build it from the
[Dartium and content_shell sources][dartium_src].

For Linux users all the necessary fonts must be installed see
https://code.google.com/p/chromium/wiki/LayoutTestsLinux

Contacting Us
-------------

Please file issues in our [Issue Tracker][issues] or contact us on the
[Dart Web UI mailing list][mailinglist].

We also have the [Web UI development list][devlist] for discussions about
internals of the code, code reviews, etc.

[wc]: http://dvcs.w3.org/hg/webcomponents/raw-file/tip/explainer/index.html
[mdv]: https://github.com/toolkitchen/mdv/
[d]: http://www.dartlang.org
[mb]: http://www.dartlang.org/support/faq.html#what-browsers-supported
[pub]: http://www.dartlang.org/docs/pub-package-manager/
[cs]: http://www.chromium.org/developers/testing/webkit-layout-tests
[cs_lucid]: http://gsdview.appspot.com/dartium-archive/continuous/drt-lucid64.zip
[cs_mac]: http://gsdview.appspot.com/dartium-archive/continuous/drt-mac.zip
[cs_win]: http://gsdview.appspot.com/dartium-archive/continuous/drt-win.zip
[dartium_src]: http://code.google.com/p/dart/wiki/BuildingDartium
[TodoMVC]: http://addyosmani.github.com/todomvc/
[todo_readme]: https://github.com/dart-lang/web-ui/blob/master/example/todomvc/README.md
[todo_live]:http://dart-lang.github.io/web-ui/example/todomvc/index.html
[changelog]:https://github.com/dart-lang/web-ui/blob/master/CHANGELOG.md
[issues]:https://github.com/dart-lang/web-ui/issues
[mailinglist]:https://groups.google.com/a/dartlang.org/forum/?fromgroups#!forum/web-ui
[devlist]:https://groups.google.com/a/dartlang.org/forum/?fromgroups#!forum/web-ui-dev
[overview]:http://www.dartlang.org/articles/dart-web-components/
[tools]:https://www.dartlang.org/articles/dart-web-components/tools.html
[spec]:https://www.dartlang.org/articles/dart-web-components/spec.html
[features]:https://www.dartlang.org/articles/dart-web-components/summary.html
