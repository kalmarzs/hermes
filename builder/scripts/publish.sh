#!/bin/bash
set -e

source /scripts/lib/messages.sh

export GNUPGHOME=/gnupg

FILTER="${1:-}"

msg available_pkgs
ls -l /packages

FOUND=0

REMOVED_PACKAGES=""

for pkg in /packages/*.deb; do

  [ -f "$pkg" ] || continue

  if [ -n "$FILTER" ]; then
    case "$pkg" in
      *"$FILTER"*) ;;
      *) continue ;;
    esac
  fi

  FOUND=1

  PKG_NAME="$(dpkg-deb -f "$pkg" Package)"

  case " $REMOVED_PACKAGES " in
    *" $PKG_NAME "*)
      ;;

    *)
      echo "🧹 Removing existing package: $PKG_NAME"
      reprepro -b /repo remove bookworm "$PKG_NAME" || true
      REMOVED_PACKAGES="$REMOVED_PACKAGES $PKG_NAME"
      ;;
  esac

  msg publish_start "$pkg"
  reprepro -b /repo includedeb bookworm "$pkg"

done

if [ "$FOUND" -eq 0 ]; then
  msg no_package "$FILTER"
  exit 1
fi

msg publish_done
