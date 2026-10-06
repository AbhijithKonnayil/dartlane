#!/usr/bin/env bash
# Checks the workspace dependency rules from the PRD (section 9).
#
# Rules, applied to every package under packages/:
#   1. No `path:` dependencies. Workspace packages resolve each other
#      through `resolution: workspace`, never through paths.
#   2. dartlane_core depends on no other workspace package.
#   3. dartlane, dartlane_flutter and dartlane_firebase may depend on
#      dartlane_core only. They must not depend on each other.
#
# Why: these rules keep the dependency graph a tree rooted at dartlane_core,
# so a package cycle cannot appear and action packages stay independent.
# `dart analyze` cannot catch this: it only reports imports that are missing
# from a pubspec, not a declared dependency that points the wrong way.
#
# How: the pubspecs are read with grep, so a dependency must be written in the
# normal block form (`  name: version`). Only packages/ is checked; examples/
# may depend on anything.
#
# Usage:  ./tool/check_dependencies.sh     (or: melos run deps)
# Exit:   0 when all rules hold, 1 and a message per violation otherwise.
#
# To add a workspace package, append it to `workspace_packages` below.

set -euo pipefail

cd "$(dirname "$0")/.."

core="dartlane_core"
workspace_packages="dartlane_core dartlane_flutter dartlane_firebase dartlane"
status=0

for pkg in $workspace_packages; do
  pubspec="packages/$pkg/pubspec.yaml"

  if grep -Eq '^\s+path:' "$pubspec"; then
    echo "$pubspec: path dependencies are not allowed"
    status=1
  fi

  for other in $workspace_packages; do
    [ "$other" = "$pkg" ] && continue
    [ "$other" = "$core" ] && [ "$pkg" != "$core" ] && continue
    if grep -Eq "^\s+$other:" "$pubspec"; then
      if [ "$pkg" = "$core" ]; then
        echo "$pubspec: $core must not depend on $other"
      else
        echo "$pubspec: must not depend on $other (only $core is allowed)"
      fi
      status=1
    fi
  done
done

[ "$status" -eq 0 ] && echo "Dependency rules OK."
exit "$status"
