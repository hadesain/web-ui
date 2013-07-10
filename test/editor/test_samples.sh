#!/bin/bash
# Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Run by https://drone.io/dart-lang/web-ui
# to verify that our TodoMVC Editor sample is working on trunk.

SAMPLE_SVN_PATH=https://dart.googlecode.com/svn/trunk/dart/samples/third_party/todomvc
echo "*** Testing TodoMVC editor sample ***"
echo "If this fails you can reproduce by running:"
echo "${BASH_SOURCE[0]}"
echo
echo "Fixing this test may involve updating polymer to work with the latest SDK"
echo "and uploading to Pub. It might also require updating the sample code at:"
echo "$SAMPLE_SVN_PATH"
echo "You can copy this code from example/todomvc."
echo

# bail on error
set -e

# Go to this script's directory, so we can safely use relative paths
cd $( dirname "${BASH_SOURCE[0]}" )

SDK=$(dirname $(dirname $(which dart)))
EDITOR=$(dirname $SDK)
echo "SDK path is $SDK"
echo "Editor path is $EDITOR"

# First clear the test folder. Otherwise we can miss bugs when we fail to
# get the code
if [[ -d todomvc/ ]]; then
  rm -rf todomvc/*
fi

echo "Copying sample from Editor..."
cp -a $EDITOR/samples/todomvc .
cd todomvc

echo "Running Pub install..."
pub install

echo "Building..."
dart build.dart

echo "Running tests..."
dart test/test.dart
