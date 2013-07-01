MDV examples are from the Model-driven Views Experimental Library
in http://code.google.com/p/mdv/.

#How to compile examples in mdv
	
To build all examples run (from the top-level directory)
	
    ./build.dart

or to build a particular example (e.g., hidden) generates output to the
directory example/mdv/hidden/out

	cd example/mdv/hidden/
	../../../bin/dwc.dart -o out hidden.html

The template compiler will create a number of files; a Dart file named _*.dart
(in our example * is "hidden.html" and the file would be named
example/mdv/hidden/.out/_hidden.html.dart). This file contains the Dart code to
create your MDV application.  Another generated file  _*_bootstrap.dart is the
main entrypoint of an app.

To run the code, launch [Dartium][] pointing to the generated file name
"_*.html" (in our example * is "hidden.html", so the file to launch from Dartium
would be example/mdv/hidden/out/_hidden.html.html).

#forms_validation
This example was derived from the MDV example located at
http://code.google.com/p/mdv/source/browse/use_cases/forms_validation.html.

#hidden
This example checks that two addresses are identical, it is a variant
of https://code.google.com/p/mdv/source/browse/use_cases/hidden2.html. This
example deviates with the addition of an OK button. The OK button is enabled or
disabled when both the shipping and billing addresses are known.  Clicking OK
displays the address(es) to the console.

#hidden2
This example displays an agreement requires accepting an agreement.
The original example can be found at:
http://code.google.com/p/mdv/source/browse/use_cases/hidden2.html.

#model
This example is a variant of forms validation located at
http://code.google.com/p/mdv/source/browse/use_cases/forms_validation.html.  The
difference is that a specific model class is defined outside of main.

#table
This example, a tic-tac-toe game using data binding, is based on the MDV
example located at
https://code.google.com/p/mdv/source/browse/use_cases/table.html

[Dartium]: http://www.dartlang.org/dartium/
