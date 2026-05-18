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

  remove_package "$PACKAGE" || true

  find "$PROJECT_DIR/packages" \
    -maxdepth 1 \
    -type f \
    -name "${PACKAGE}_*.deb" \
    -print \
    -delete
}

list_packages() {
  find "$PACKAGE_DIR" \
    -type f \
    -name 'build-*.sh' \
    | sed 's|.*/build-||; s|\.sh$||' \
    | sort
}

case "${1:-}" in

  build)
    build_package "$2"
    ;;

  publish)
    publish_package "$2"
    ;;

  remove|delete|revoke)
    remove_package "$2"
    ;;

  purge)
    purge_package "$2"
    ;;

  list)
    list_packages
    ;;

  '')
    usage
    ;;

  *)
    build_package "$1"
    publish_package "$1"
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
