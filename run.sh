#!/bin/bash
# ABOUTME: Simple script to run the Keycast Flutter Demo app
# ABOUTME: Usage: ./run.sh [platform] where platform is macos, ios, or chrome

set -e

cd "$(dirname "$0")"

PLATFORM="${1:-macos}"

case "$PLATFORM" in
  macos)
    echo "Running on macOS desktop..."
    flutter run -d macos
    ;;
  ios)
    echo "Running on iOS simulator..."
    flutter run -d ios
    ;;
  chrome)
    echo "Running in Chrome browser..."
    flutter run -d chrome
    ;;
  *)
    echo "Usage: ./run.sh [macos|ios|chrome]"
    echo "Default: macos"
    exit 1
    ;;
esac
