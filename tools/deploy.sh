#!/usr/bin/env bash
#
# deploy.sh — update the docs checkout and rebuild the live site, on the server.
#
# Installed at /opt/olyg3/deploy.sh. Pulls the latest commit into the olyg3
# checkout and rebuilds Hugo's site/public/ directory, which the web server
# serves directly (see site/deploy/nginx.conf).
#
# The rebuild happens in place on the live site/public/ directory, so a browser
# loading a page mid-build may briefly hit a missing or half-written asset.
# This is accepted as low risk (low probability, low impact).
#
# One-time server setup is documented in site/deploy/README.md.
#
# Usage (on the server):
#   /opt/olyg3/deploy.sh
#
set -euo pipefail

# deploy-docs.sh invokes this over SSH, and a non-interactive SSH shell has a
# minimal PATH that omits /usr/local/bin, the Go toolchain, and /snap/bin. Add
# the common locations so git/hugo/go resolve however they were installed.
export PATH="/usr/local/bin:/usr/local/go/bin:/snap/bin:$PATH"

# Where the olyg3 repo is checked out on this server. The Hugo project lives in
# "$REPO_DIR/site"; the web server's docs root points at "$REPO_DIR/site/public".
REPO_DIR="/opt/olyg3/olympia-g3"

cd "$REPO_DIR"

echo ">> Updating checkout in $REPO_DIR"
git pull --ff-only

echo ">> Rebuilding site/public/"
hugo --source site --gc --minify

echo ">> Done"
