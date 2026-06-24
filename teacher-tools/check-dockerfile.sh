#!/bin/bash
# check-dockerfile.sh - Check Dockerfile best practices
# Usage: bash check-dockerfile.sh <path-to-Dockerfile>

DOCKERFILE="$1"

if [ -z "$DOCKERFILE" ]; then
  echo "Usage: $0 <path-to-Dockerfile>"
  exit 1
fi

if [ ! -f "$DOCKERFILE" ]; then
  echo "Error: Dockerfile not found at $DOCKERFILE"
  exit 1
fi

DOCKERFILE_DIR=$(dirname "$DOCKERFILE")
SCORE=0

# Check 1: Base image is slim/alpine with fixed version (check LAST FROM instruction)
LAST_FROM=$(grep -E '^FROM' "$DOCKERFILE" | tail -1)
BASE_IMAGE=$(echo "$LAST_FROM" | awk '{print $2}')

if echo "$BASE_IMAGE" | grep -qE '^node:[0-9]+.*-(alpine|slim)'; then
  SCORE=$((SCORE + 1))
  echo "OK Check 1: Base image is slim/alpine with fixed version ($BASE_IMAGE)"
else
  echo "KO Check 1: Base image should be slim/alpine with fixed version (found: $BASE_IMAGE)"
fi

# Check 2: USER instruction (non-root user)
if grep -qE '^USER' "$DOCKERFILE"; then
  SCORE=$((SCORE + 1))
  echo "OK Check 2: USER instruction (non-root) found"
else
  echo "KO Check 2: No USER instruction found"
fi

# Check 3: Multi-stage build (at least 2 FROM instructions)
FROM_COUNT=$(grep -cE '^FROM' "$DOCKERFILE")
if [ "$FROM_COUNT" -ge 2 ]; then
  SCORE=$((SCORE + 1))
  echo "OK Check 3: Multi-stage build detected ($FROM_COUNT stages)"
else
  echo "KO Check 3: No multi-stage build (only $FROM_COUNT FROM instruction)"
fi

# Check 4: .dockerignore exists in same directory
if [ -f "$DOCKERFILE_DIR/.dockerignore" ]; then
  SCORE=$((SCORE + 1))
  echo "OK Check 4: .dockerignore exists"
else
  echo "KO Check 4: .dockerignore not found in $DOCKERFILE_DIR"
fi

# Check 5: Layer order - COPY package*.json before RUN npm install/ci before COPY . .
# Find FIRST line with COPY + "package"
COPY_PKG_LINE=$(grep -nE '^COPY.*(package)' "$DOCKERFILE" | head -1 | cut -d: -f1)

# Find FIRST line with RUN npm install or npm ci
NPM_INSTALL_LINE=$(grep -nE '^RUN.*(npm install|npm ci)' "$DOCKERFILE" | head -1 | cut -d: -f1)

# Find LAST COPY . . line
COPY_DOT_LINE=$(grep -nE '^COPY \. \.' "$DOCKERFILE" | tail -1 | cut -d: -f1)

if [ -n "$COPY_PKG_LINE" ] && [ -n "$NPM_INSTALL_LINE" ] && [ -n "$COPY_DOT_LINE" ] && \
   [ "$COPY_PKG_LINE" -lt "$NPM_INSTALL_LINE" ] && [ "$NPM_INSTALL_LINE" -lt "$COPY_DOT_LINE" ]; then
  SCORE=$((SCORE + 1))
  echo "OK Check 5: Optimal layer order (COPY package -> npm install -> COPY . .)"
else
  echo "KO Check 5: Layer order not optimal"
fi

echo ""
echo "$SCORE/5 checks passed"

if [ "$SCORE" -eq 5 ]; then
  exit 0
else
  exit 1
fi
