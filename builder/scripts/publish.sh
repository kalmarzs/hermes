#!/bin/bash
set -e

export GNUPGHOME=/gnupg

FILTER="${1:-}"

echo "📦 Available packages:"
ls -l /packages

FOUND=0

for pkg in /packages/*.deb; do
  if [ ! -f "$pkg" ]; then
    continue
  fi

  if [ -n "$FILTER" ]; then
    case "$pkg" in
      *"$FILTER"*) ;;
      *) continue ;;
    esac
  fi

  FOUND=1

  PKG_NAME="$(dpkg-deb -f "$pkg" Package)"

  echo "🧹 Removing existing ${PKG_NAME} from repo if present..."
  reprepro -b /repo remove bookworm "$PKG_NAME" || true

  echo "📤 Publishing $pkg"
  reprepro -b /repo includedeb bookworm "$pkg"
done

if [ "$FOUND" -eq 0 ]; then
  if [ -n "$FILTER" ]; then
    echo "❌ No .deb packages found matching: $FILTER"
  else
    echo "❌ No .deb packages found in /packages"
  fi
  exit 1
fi

echo "✅ Publish complete"
