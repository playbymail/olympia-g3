#!/usr/bin/env bash
#
# deploy-docs.sh — trigger a docs deploy on the server.
#
# Deploys are now built on the server. This just runs /opt/olyg3/deploy.sh over
# SSH, which pulls the latest commit and rebuilds the live site. Push your
# changes to the repo first so the server has something to pull.
#
# Usage:
#   tools/deploy-docs.sh
#
set -euo pipefail

exec ssh olympia-g3.pbbgaming.com /opt/olyg3/deploy.sh
