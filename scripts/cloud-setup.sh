#!/usr/bin/env bash
# Setup for a Claude Code cloud session (claude.ai/code) on flutter_notemus.
#
# The cloud image is Ubuntu 24.04, runs this as root, and ships Node, Java,
# Python and friends but NOT Flutter. This installs the stable Flutter SDK (the
# channel CI uses), resolves the root package and example/, and runs a short
# smoke test so a session can start working straight away.
#
# Idempotent: a second run reuses the SDK and only re-resolves packages.
#
#   bash scripts/cloud-setup.sh                 # setup + smoke test
#   FLUTTER_REF=3.47.0 bash scripts/cloud-setup.sh   # pin a tag instead of stable
#   SKIP_SMOKE=1 bash scripts/cloud-setup.sh    # setup only
#
# Goldens are NOT run here: they are recorded on Windows and only match there
# (see dart_test.yaml and doc/handoff/HANDOFF.md).

set -euo pipefail

FLUTTER_DIR="${FLUTTER_DIR:-/opt/flutter}"
FLUTTER_REF="${FLUTTER_REF:-stable}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '\n==> %s\n' "$*"; }

# --- System packages Flutter's tool needs on a bare Ubuntu ------------------
if ! command -v unzip >/dev/null 2>&1 || ! command -v xz >/dev/null 2>&1; then
  log "Installing unzip, xz-utils, curl, git"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq unzip xz-utils curl git ca-certificates >/dev/null
fi

# --- Flutter SDK ------------------------------------------------------------
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  log "Cloning Flutter ($FLUTTER_REF) into $FLUTTER_DIR"
  git clone --depth 1 --branch "$FLUTTER_REF" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
else
  log "Flutter already at $FLUTTER_DIR, reusing it"
fi

# The SDK is owned by root but git may run as another user later.
git config --global --add safe.directory "$FLUTTER_DIR" || true
git config --global --add safe.directory "$REPO_ROOT" || true

export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:$PATH"
cat >/etc/profile.d/flutter.sh <<EOF
export PATH="$FLUTTER_DIR/bin:$FLUTTER_DIR/bin/cache/dart-sdk/bin:\$PATH"
EOF

export CI=true FLUTTER_SUPPRESS_ANALYTICS=true
flutter config --no-analytics >/dev/null 2>&1 || true
dart --disable-analytics >/dev/null 2>&1 || true

log "Flutter version"
flutter --version

# --- Packages ----------------------------------------------------------------
# example/ first, root last, as CI does. Formatting depends on this: without a
# resolved package config `dart format` falls back to the newest style and
# rewrites files that are already correct.
log "Resolving example/"
(cd "$REPO_ROOT/example" && flutter pub get)
log "Resolving the package"
(cd "$REPO_ROOT" && flutter pub get)

# --- Smoke test --------------------------------------------------------------
if [ "${SKIP_SMOKE:-0}" != "1" ]; then
  log "Smoke test: analyzer + core tests"
  (cd "$REPO_ROOT" && dart analyze lib test && flutter test --exclude-tags golden test/core)
fi

log "Done. Open a new shell (or: source /etc/profile.d/flutter.sh), then:"
cat <<'EOF'
    flutter test --exclude-tags golden     # the logic suite, as CI runs it on Linux
    dart analyze lib test
    (cd example && flutter analyze)
    dart format lib test example           # CI's Format job is the reference
EOF
