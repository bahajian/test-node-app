#!/usr/bin/env bash
# Build -> push to Nexus -> deploy to k8s.
# Image is built on the Docker host (BUILDER) since the Mac has no docker daemon.
set -euo pipefail

IMAGE="nexus.ibstorm.com/test-node-app"
TAG="${1:-v1}"
BUILDER="${BUILDER:-user@192.168.2.7}"   # has a Docker daemon
MASTER="${MASTER:-user@192.168.2.10}"    # k8s control-plane
DIR="$(cd "$(dirname "$0")" && pwd)"

echo ">> copy source to builder"
ssh "$BUILDER" "rm -rf ~/test-node-app-build && mkdir -p ~/test-node-app-build"
scp -q "$DIR/server.js" "$DIR/package.json" "$DIR/Dockerfile" "$DIR/.dockerignore" "$BUILDER:~/test-node-app-build/"

echo ">> docker login + build + push ($IMAGE:$TAG)"
# Expects CI creds; override with NEXUS_USER / NEXUS_PASS env vars.
ssh "$BUILDER" "echo '${NEXUS_PASS:-Ci-Push-9241!Kx}' | docker login nexus.ibstorm.com -u '${NEXUS_USER:-ci}' --password-stdin && \
  cd ~/test-node-app-build && \
  docker build -t $IMAGE:$TAG . && \
  docker push $IMAGE:$TAG && \
  docker logout nexus.ibstorm.com"

echo ">> apply manifests + set image + rollout"
ssh "$MASTER" "rm -rf ~/test-node-app && mkdir -p ~/test-node-app/k8s"
scp -q "$DIR"/k8s/*.yaml "$MASTER:~/test-node-app/k8s/"
ssh "$MASTER" "kubectl apply -f ~/test-node-app/k8s/ && \
  kubectl -n test-node-app set image deploy/test-node-app app=$IMAGE:$TAG && \
  kubectl -n test-node-app rollout status deploy/test-node-app --timeout=120s"

echo ">> done"
