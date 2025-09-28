#!/usr/bin/env bash
set -euo pipefail

docker run -d \
  --name u24 \
  -p 2222:22 \
  --hostname u24 \
  ubuntu-ssh:24.04
