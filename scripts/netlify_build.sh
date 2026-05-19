#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="$HOME/flutter"

if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi

export PATH="$PATH:$FLUTTER_DIR/bin"

flutter config --enable-web
flutter pub get
flutter build web --release
