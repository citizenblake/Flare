#!/bin/sh
# Xcode Cloud post-clone hook.
#
# The "Compile Kotlin" build phase runs ./gradlew, which needs a JDK; Xcode Cloud images
# have none. Install one and link it where macOS's /usr/bin/java finds it without sudo,
# so the later build phase sees it too (environment variables set here don't carry over).
# Gradle then provisions the exact daemon JDK from gradle/gradle-daemon-jvm.properties.
set -eu

brew install openjdk@25
mkdir -p "$HOME/Library/Java/JavaVirtualMachines"
ln -sfn "$(brew --prefix openjdk@25)/libexec/openjdk.jdk" "$HOME/Library/Java/JavaVirtualMachines/openjdk-25.jdk"
/usr/bin/java -version
