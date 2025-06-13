# Ghost Distroless Migration

This document describes the migration of the Ghost Docker image to use Google's distroless base image for enhanced security and reduced attack surface.

## Overview

The Ghost Docker image now supports two runtime options:
- **Alpine-based** (original): Full-featured with shell access for debugging
- **Distroless** (new): Minimal, secure runtime without shell or package manager

## Architecture

### Multi-Stage Build Process

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Build Stages  │    │  Alpine Runtime │    │Distroless Runtime│
│                 │    │                 │    │                 │
│ 1. mynode       │───▶│ 5. final        │    │ 6. distroless   │
│ 2. debug        │    │                 │    │                 │
│ 3. builder      │    │ + Shell access  │    │ + Minimal size  │
│ 4. (packages)   │    │ + Debugging     │    │ + Enhanced security│
│                 │    │ + Flexibility   │    │ + No shell access │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Key Changes

#### Base Image
- **From**: `node:20.19.2-alpine3.22`
- **To**: `gcr.io/distroless/nodejs20-debian12`

#### User Management
- **From**: `node` user (UID 1000) with `gosu` privilege dropping
- **To**: `nonroot` user (UID 65532) - no privilege dropping needed

#### Entrypoint Strategy
- **From**: Shell-based `docker-entrypoint.sh` with runtime content initialization
- **To**: Direct Node.js execution with build-time content initialization

## Building Images

### Build Both Versions
```bash
./v5/build-distroless.sh
```

### Build Specific Versions
```bash
# Alpine version (original)
docker build --target final -t ghostfire:alpine -f v5/Dockerfile .

# Distroless version (recommended for production)
docker build --target distroless -t ghostfire:distroless -f v5/Dockerfile .
```

## Testing

### Test Distroless Version
```bash
./v5/test-distroless.sh
```

### Manual Testing
```bash
# Run distroless container
docker run -d -p 2368:2368 --name ghost-test ghostfire:distroless

# Check if Ghost is running
curl http://localhost:2368

# View logs (no shell access available)
docker logs ghost-test

# Clean up
docker rm -f ghost-test
```

## Security Benefits

### Distroless Advantages
- **Minimal Attack Surface**: No shell, package manager, or unnecessary binaries
- **Reduced CVE Exposure**: Fewer packages mean fewer potential vulnerabilities
- **Immutable Runtime**: Cannot install additional packages or modify system
- **Smaller Image Size**: ~50-100MB reduction compared to Alpine version

### Security Comparison

| Feature | Alpine | Distroless |
|---------|--------|------------|
| Shell Access | ✅ bash/sh | ❌ None |
| Package Manager | ✅ apk | ❌ None |
| Debug Tools | ✅ Available | ❌ None |
| CVE Surface | 🟡 Medium | 🟢 Minimal |
| Image Size | 🟡 ~200MB | 🟢 ~150MB |
| Runtime Modification | 🔴 Possible | 🟢 Impossible |

## Production Deployment

### Recommended Usage
```yaml
# docker-compose.yml
version: '3.8'
services:
  ghost:
    image: devmtl/ghostfire:distroless
    ports:
      - "2368:2368"
    environment:
      - NODE_ENV=production
    volumes:
      - ghost_content:/var/lib/ghost/content
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp
```

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ghost-distroless
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ghost
  template:
    metadata:
      labels:
        app: ghost
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        fsGroup: 65532
      containers:
      - name: ghost
        image: devmtl/ghostfire:distroless
        ports:
        - containerPort: 2368
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: ghost-content
          mountPath: /var/lib/ghost/content
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: ghost-content
        persistentVolumeClaim:
          claimName: ghost-content-pvc
      - name: tmp
        emptyDir: {}
```

## Debugging

### Distroless Debugging
Since distroless images don't have shell access, debugging requires different approaches:

#### 1. Use Debug Variant
```bash
# Build with debug variant for troubleshooting
FROM gcr.io/distroless/nodejs20-debian12:debug AS distroless-debug
# ... rest of distroless stage
```

#### 2. Log Analysis
```bash
# View container logs
docker logs <container-name>

# Follow logs in real-time
docker logs -f <container-name>
```

#### 3. External Debugging Tools
```bash
# Use external tools to inspect running container
docker exec <container-name> cat /proc/1/status
docker inspect <container-name>
```

#### 4. Fallback to Alpine
For complex debugging, temporarily use the Alpine version:
```bash
docker run -it --rm ghostfire:alpine sh
```

## Migration Checklist

- [x] ✅ Multi-stage Dockerfile with distroless target
- [x] ✅ Content initialization moved to build stage
- [x] ✅ User management updated for nonroot user
- [x] ✅ Build scripts for both versions
- [x] ✅ Test scripts for validation
- [x] ✅ Documentation and deployment examples
- [ ] 🔄 Production testing and validation
- [ ] 🔄 CI/CD pipeline updates
- [ ] 🔄 Monitoring and alerting adjustments

## Troubleshooting

### Common Issues

#### Content Permissions
If Ghost fails to start due to content permissions:
```bash
# Check content ownership in Alpine version
docker run --rm -v ghost_content:/content ghostfire:alpine ls -la /content

# Fix permissions if needed
docker run --rm -v ghost_content:/content ghostfire:alpine chown -R 65532:65532 /content
```

#### Missing Content
If Ghost starts but content is missing:
```bash
# Verify content initialization in build logs
docker build --target distroless --progress=plain -f v5/Dockerfile . 2>&1 | grep -i content
```

#### Performance Issues
Monitor startup time and resource usage:
```bash
# Compare startup times
time docker run --rm ghostfire:alpine node --version
time docker run --rm ghostfire:distroless node --version
```

## Support

For issues related to the distroless migration:
1. Check the troubleshooting section above
2. Review container logs for error messages
3. Test with the Alpine version to isolate distroless-specific issues
4. Use the debug variant for deeper investigation

## References

- [Google Distroless Images](https://github.com/GoogleContainerTools/distroless)
- [Ghost.js Documentation](https://ghost.org/docs/)
- [Docker Multi-stage Builds](https://docs.docker.com/develop/dev-best-practices/dockerfile_best-practices/#use-multi-stage-builds)
- [Container Security Best Practices](https://cloud.google.com/architecture/best-practices-for-building-containers)