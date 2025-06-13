#!/bin/bash
set -e

# Test script for distroless Ghost image
APP_NAME="ghostfire"
DOCKERHUB_USER="devmtl"
CONTAINER_NAME="ghost-distroless-test"
PORT="2368"

echo "🧪 Testing Ghost distroless image..."
echo ""

# Clean up any existing test container
echo "🧹 Cleaning up existing test containers..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

# Run the distroless container
echo "🚀 Starting Ghost distroless container..."
docker run -d \
    --name "$CONTAINER_NAME" \
    -p "$PORT:2368" \
    -e NODE_ENV=production \
    "$DOCKERHUB_USER/$APP_NAME:distroless"

echo "⏳ Waiting for Ghost to start..."
sleep 10

# Test if Ghost is responding
echo "🔍 Testing Ghost health..."
if curl -f -s "http://localhost:$PORT" > /dev/null; then
    echo "✅ Ghost is responding on port $PORT"
    echo "🌐 Ghost is accessible at: http://localhost:$PORT"
else
    echo "❌ Ghost is not responding"
    echo "📋 Container logs:"
    docker logs "$CONTAINER_NAME"
    exit 1
fi

# Show container info
echo ""
echo "📊 Container information:"
echo "Container ID: $(docker ps -q -f name=$CONTAINER_NAME)"
echo "Image: $(docker inspect --format='{{.Config.Image}}' $CONTAINER_NAME)"
echo "User: $(docker exec $CONTAINER_NAME whoami 2>/dev/null || echo 'nonroot (distroless)')"
echo "Working Dir: $(docker inspect --format='{{.Config.WorkingDir}}' $CONTAINER_NAME)"

# Show running processes (if possible in distroless)
echo ""
echo "🔍 Process information:"
docker exec "$CONTAINER_NAME" ps aux 2>/dev/null || echo "Process listing not available in distroless (expected)"

echo ""
echo "✅ Distroless test completed successfully!"
echo ""
echo "Commands to interact with the container:"
echo "  View logs:    docker logs $CONTAINER_NAME"
echo "  Stop:         docker stop $CONTAINER_NAME"
echo "  Remove:       docker rm -f $CONTAINER_NAME"
echo "  Access Ghost: http://localhost:$PORT"
echo ""
echo "Note: Distroless containers don't have shell access for security."
echo "For debugging, use the debug variant: gcr.io/distroless/nodejs20-debian12:debug"