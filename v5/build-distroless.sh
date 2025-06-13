#!/bin/bash
set -e

# Build script for Ghost with distroless runtime
# This script builds both Alpine and distroless versions

APP_NAME="ghostfire"
VERSION="5.121.0"
DOCKERHUB_USER="devmtl"

echo "Building Ghost Docker images..."
echo "App: $APP_NAME"
echo "Version: $VERSION"
echo ""

# Build Alpine version (original)
echo "🏔️  Building Alpine version..."
docker build \
    --target final \
    --build-arg VERSION="$VERSION" \
    -t "$DOCKERHUB_USER/$APP_NAME:$VERSION-alpine" \
    -t "$DOCKERHUB_USER/$APP_NAME:alpine" \
    -f v5/Dockerfile \
    .

echo "✅ Alpine build completed"
echo ""

# Build distroless version (new)
echo "🔒 Building distroless version..."
docker build \
    --target distroless \
    --build-arg VERSION="$VERSION" \
    -t "$DOCKERHUB_USER/$APP_NAME:$VERSION-distroless" \
    -t "$DOCKERHUB_USER/$APP_NAME:distroless" \
    -t "$DOCKERHUB_USER/$APP_NAME:latest" \
    -f v5/Dockerfile \
    .

echo "✅ Distroless build completed"
echo ""

# Show image sizes
echo "📊 Image size comparison:"
docker images | grep "$DOCKERHUB_USER/$APP_NAME" | head -4

echo ""
echo "🚀 Build completed successfully!"
echo ""
echo "Available images:"
echo "  - Alpine version:     $DOCKERHUB_USER/$APP_NAME:alpine"
echo "  - Distroless version: $DOCKERHUB_USER/$APP_NAME:distroless"
echo "  - Latest (distroless): $DOCKERHUB_USER/$APP_NAME:latest"
echo ""
echo "To run distroless version:"
echo "  docker run -p 2368:2368 $DOCKERHUB_USER/$APP_NAME:distroless"