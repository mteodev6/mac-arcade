#!/bin/bash
set -e

echo "=== MacArcade Build Script ==="

if ! command -v xcodebuild &> /dev/null; then
    echo "xcodebuild not found. Please install Xcode on macOS."
    echo "To open in Xcode directly: open MacArcade.xcodeproj"
    exit 1
fi

echo "Building MacArcade with Xcode..."
xcodebuild -project MacArcade.xcodeproj -scheme MacArcade -configuration Debug build

echo "Build complete! The app can be run from Xcode or Products directory."
