#!/bin/bash
set -e

echo "=== AdoptMatch Vercel Flutter Web Build ==="

if ! command -v flutter &> /dev/null
then
    echo "Flutter not detected on system. Fetching stable Flutter SDK..."
    git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter
    export PATH="$PATH:$PWD/_flutter/bin"
fi

echo "Flutter version:"
flutter --version

echo "Building Flutter Web release..."
flutter config --no-analytics
flutter build web --release

echo "Build complete! Output located at build/web"
