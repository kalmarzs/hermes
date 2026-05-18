#!/bin/bash
set -e
source /scripts/lib/messages.sh
PKG_NAME="hermes-server"
VERSION="2.0.0"
PKG_DIR="/tmp/${PKG_NAME}"

echo "🔧 Building ${PKG_NAME} package..."

rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR"
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/sbin"
mkdir -p "$PKG_DIR/etc"
mkdir -p "$PKG_DIR/data/hermes"

# Copy Hermes project files
cp -r /hermes-source/builder "$PKG_DIR/data/hermes/"
cp -r /hermes-source/repo "$PKG_DIR/data/hermes/"
cp /hermes-source/docker-compose.yaml "$PKG_DIR/data/hermes/docker-compose.yaml"

# Runtime/state directories
mkdir -p "$PKG_DIR/data/hermes/packages"
mkdir -p "$PKG_DIR/data/hermes/repo-data"
mkdir -p "$PKG_DIR/data/hermes/gnupg"

# Install hermes CLI
cat > "$PKG_DIR/usr/sbin/hermes" <<'EOF'
#!/bin/bash
set -e

CONFIG_FILE="/etc/hermes.conf"

if [ -f "$CONFIG_FILE" ]; then
  . "$CONFIG_FILE"
fi

PROJECT_DIR="${HERMES_HOME:-/data/hermes}"
IMAGE="${HERMES_BUILDER_IMAGE:-hermes-builder}"

run_builder() {
  docker run --rm \
    -v "$PROJECT_DIR/packages:/packages" \
    -v "$PROJECT_DIR/repo-data:/repo" \
    -v "$PROJECT_DIR/gnupg:/gnupg" \
    -v "$PROJECT_DIR/builder/scripts:/scripts" \
    -v "$PROJECT_DIR:/hermes-source" \
    "$IMAGE" \
    bash -c "$1"
}

usage() {
  echo "Usage:"
  echo "  hermes <package>              # build + publish"
  echo "  hermes build <package>"
  echo "  hermes list"
  echo "  hermes publish <package>"
  echo "  hermes purge <package>"
  echo "  hermes rebuild-images"
  echo "  hermes remove <package>"
}

build_package() {
  PACKAGE="$1"
  SCRIPT="$PROJECT_DIR/builder/scripts/build-${PACKAGE}.sh"

  if [ ! -f "$SCRIPT" ]; then
    echo "Missing build script: $SCRIPT"
    exit 1
  fi

  if [ ! -x "$SCRIPT" ]; then
    echo "Build script is not executable: $SCRIPT"
    echo "Fix with: chmod +x $SCRIPT"
    exit 1
  fi

  run_builder "/scripts/build-${PACKAGE}.sh"
}

publish_package() {
  PACKAGE="$1"
  run_builder "/scripts/publish.sh ${PACKAGE}"
}

list_packages() {
  echo "Available packages:"
  find "$PROJECT_DIR/builder/scripts" \
    -maxdepth 1 \
    -type f \
    -name "build-*.sh" \
    -printf "  %f\n" \
    | sed 's/^  build-/  /; s/\.sh$//' \
    | sort
}

rebuild_images() {
  cd "$PROJECT_DIR"
  docker build -t "$IMAGE" ./builder
  docker compose up -d --build
}

remove_package() {
  PACKAGE="$1"

  docker run --rm \
    -v "$PROJECT_DIR/repo-data:/repo" \
    -v "$PROJECT_DIR/gnupg:/gnupg" \
    "$IMAGE" \
    bash -c "export GNUPGHOME=/gnupg && reprepro -b /repo remove bookworm '$PACKAGE'"
}

purge_package() {
  PACKAGE="$1"

  echo "🧹 Removing ${PACKAGE} from repository..."

  docker run --rm \
    -v "$PROJECT_DIR/repo-data:/repo" \
    -v "$PROJECT_DIR/gnupg:/gnupg" \
    "$IMAGE" \
    bash -c "export GNUPGHOME=/gnupg && reprepro -b /repo remove bookworm '$PACKAGE'" \
    || true

  echo "🗑 Removing local package files..."

  find "$PROJECT_DIR/packages" \
    -maxdepth 1 \
    -type f \
    -name "${PACKAGE}_*.deb" \
    -print \
    -delete

  echo "✅ Purge complete."
}

case "${1:-}" in
  build)
    [ -n "${2:-}" ] || { usage; exit 1; }
    build_package "$2"
    ;;

  publish)
    [ -n "${2:-}" ] || { usage; exit 1; }
    publish_package "$2"
    ;;

  list)
    list_packages
    ;;

  rebuild-images)
    rebuild_images
    ;;
  
  remove|delete|revoke)
    [ -n "${2:-}" ] || { usage; exit 1; }
    remove_package "$2"
  ;;

  purge)
    [ -n "${2:-}" ] || { usage; exit 1; }
    purge_package "$2"
  ;;

  "")
    usage
    exit 1
    ;;

  *)
    PACKAGE="$1"
    build_package "$PACKAGE"
    publish_package "$PACKAGE"
    ;;
esac
EOF

chmod 755 "$PKG_DIR/usr/sbin/hermes"

# Config file
cat > "$PKG_DIR/etc/hermes.conf" <<'EOF'
HERMES_HOME="/data/hermes"
HERMES_BUILDER_IMAGE="hermes-builder"
HERMES_REPO_CONTAINER="hermes"
EOF

# Debian control
cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: ${PKG_NAME}
Version: ${VERSION}
Section: admin
Priority: optional
Architecture: all
Depends: docker.io
Maintainer: kalmarzs
Description: Hermes private Debian repository and package build helper
EOF

# Mark config file as conffile
cat > "$PKG_DIR/DEBIAN/conffiles" <<EOF
/etc/hermes.conf
EOF

# postinst
cat > "$PKG_DIR/DEBIAN/postinst" <<'EOF'
#!/bin/bash
set -e

mkdir -p /data/hermes/packages
mkdir -p /data/hermes/repo-data
mkdir -p /data/hermes/gnupg

chmod 700 /data/hermes/gnupg || true

if command -v docker >/dev/null 2>&1; then
  cd /data/hermes

  docker build -t hermes-builder ./builder || true

  if docker compose version >/dev/null 2>&1; then
    docker compose up -d --build || true
  else
    echo "Docker Compose v2 not found."
    echo "Repository container was not started automatically."
    echo "Run manually after installing Docker Compose:"
    echo "  hermes rebuild-images"
  fi
else
  echo "Docker is not installed."
  echo "Install Docker, then run:"
  echo "  hermes rebuild-images"
fi

exit 0
EOF

chmod 755 "$PKG_DIR/DEBIAN/postinst"

# prerm
cat > "$PKG_DIR/DEBIAN/prerm" <<'EOF'
#!/bin/bash
set -e

# Do not remove repo data, packages, or keys.
# Only stop containers if Docker is available.
if command -v docker >/dev/null 2>&1; then
  cd /opt/hermes 2>/dev/null || exit 0

  if docker compose version >/dev/null 2>&1; then
    docker compose down || true
  fi
fi

exit 0
EOF

chmod 755 "$PKG_DIR/DEBIAN/prerm"

dpkg-deb --build "$PKG_DIR"

mv "${PKG_DIR}.deb" "/packages/${PKG_NAME}_${VERSION}_all.deb"

echo "✅ Package created:"
echo "   /packages/${PKG_NAME}_${VERSION}_all.deb"
