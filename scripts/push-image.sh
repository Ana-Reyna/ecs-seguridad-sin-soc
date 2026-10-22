#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../terraform"
REPO="$(terraform output -raw ecr_repository_url)"
REGION="$(terraform output -raw region)"
SRC="${1:-nginx:1.19.0}"
if [ -d "../$SRC" ]; then SRC="$(cd "../$SRC" && pwd)"; fi

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${REPO%%/*}"

if [ -d "$SRC" ]; then
  docker build --platform linux/amd64 -t "$REPO:vulnerable" "$SRC"
else
  docker pull --platform linux/amd64 "$SRC"
  docker tag "$SRC" "$REPO:vulnerable"
fi
docker push "$REPO:vulnerable"

echo "Listo: $REPO:vulnerable"
