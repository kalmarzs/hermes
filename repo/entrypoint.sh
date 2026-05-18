#!/bin/bash
set -e

echo "🔐 Initializing GPG..."

# Ensure gnupg folder exists
mkdir -p /gnupg
chmod 700 /gnupg

# Generate key if none exists
if ! gpg --list-keys | grep -q "Repo Signing Key"; then
  echo "⚠ No GPG key found, generating one..."

  gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 2048
Name-Real: Repo Signing Key
Name-Email: repo@local
Expire-Date: 0
%no-protection
%commit
EOF
fi

echo "📦 Exporting public key..."
gpg --armor --export > /repo/public.key

echo "🌍 Starting nginx..."
nginx

tail -f /dev/null
