#!/bin/sh
# Regenerates android/gradle/wrapper/gradle-wrapper.jar if it's missing.
#
# gradle-wrapper.jar is intentionally not committed to this repo. Without
# it, `./gradlew` (and therefore `flutter build apk` / `flutter build
# appbundle`) fails immediately with:
#   Error: Could not find or load main class org.gradle.wrapper.GradleWrapperMain
#
# Run this once before your first local build:
#   sh android/regenerate_gradle_wrapper.sh

set -e
cd "$(dirname "$0")"

if [ -f gradle/wrapper/gradle-wrapper.jar ]; then
  echo "gradle-wrapper.jar already present — nothing to do."
  exit 0
fi

GRADLE_VERSION=$(grep -oE 'gradle-[0-9.]+' gradle/wrapper/gradle-wrapper.properties | sed 's/gradle-//')

if command -v gradle >/dev/null 2>&1; then
  echo "Regenerating gradle-wrapper.jar with local Gradle ${GRADLE_VERSION}..."
  gradle wrapper --gradle-version "${GRADLE_VERSION}" --distribution-type all
else
  echo "Downloading gradle-wrapper.jar for Gradle ${GRADLE_VERSION}..."
  curl -fsSL "https://raw.githubusercontent.com/gradle/gradle/v${GRADLE_VERSION}/gradle/wrapper/gradle-wrapper.jar" \
    -o gradle/wrapper/gradle-wrapper.jar
fi

echo "Done."
