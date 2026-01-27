# Podman Container Deployment Guide

This directory contains scripts and documentation for building and running the chaos-broker handler and orchestrator (Step Functions replacement) as containers using Podman.

## Overview

Podman is a daemonless container engine that is compatible with Docker. This guide provides instructions for:
- Building container images using Podman
- Running containers locally with Podman
- Managing container images and containers

## Prerequisites

### Install Podman

**macOS:**
```bash
brew install podman
```

**Linux (Fedora/RHEL):**
```bash
sudo dnf install podman
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get update
sudo apt-get install podman
```

### Initialize Podman Machine (macOS)

On macOS, Podman requires a virtual machine. Initialize it:

```bash
# Initialize podman machine
podman machine init

# Start podman machine
podman machine start

# Verify installation
podman version
podman info
```

**Note**: Podman machine is not required on Linux systems.

## Directory Structure

```
podman/
├── README.md                    # This file
├── scripts/
│   ├── build-images.sh         # Build container images with Podman
│   ├── run-handler.sh          # Run handler container locally
│   ├── run-orchestrator.sh     # Run orchestrator container locally
│   └── cleanup.sh              # Clean up containers and images
└── sample-payload.json         # Example payload for testing
```

## Quick Start

**⚠️ Important for macOS users:** Before running any scripts, ensure the Podman machine is running:
```bash
podman machine start
```

### 1. Build Container Images

Build both the handler and orchestrator images:

```bash
cd terraform/openshift_deployment/podman
./scripts/build-images.sh
```

Or build individually:

```bash
# Build handler image
./scripts/build-images.sh handler

# Build orchestrator image
./scripts/build-images.sh orchestrator
```

### 2. Run Handler Container Locally

Run the handler container:

```bash
./scripts/run-handler.sh
```

The handler will be available at `http://localhost:8080`

### 3. Run Orchestrator Container Locally

Run the orchestrator container (make sure handler is running first):

```bash
./scripts/run-orchestrator.sh
```

The orchestrator will be available at `http://localhost:8081`

### 4. Test the Services

```bash
# Test handler health
curl http://localhost:8080/health

# Test orchestrator health
curl http://localhost:8081/health

# Test handler with a payload
curl -X POST http://localhost:8080/invoke \
  -H "Content-Type: application/json" \
  -d @sample-payload.json
```

## Detailed Instructions

### Building Images

The build scripts use the same Dockerfiles as the Docker setup (located in `../docker/`). Podman is Docker-compatible, so the Dockerfiles work without modification.

**Build Options:**

```bash
# Build with default settings (latest tag)
./scripts/build-images.sh

# Build with custom tag
IMAGE_TAG=v1.0.0 ./scripts/build-images.sh

# Build specific component
./scripts/build-images.sh handler
./scripts/build-images.sh orchestrator
```

**Build from project root:**

You can also build from the project root:

```bash
cd Latest-Exp-BIntPrvt
podman build \
  -f terraform/openshift_deployment/docker/Dockerfile \
  -t chaos-broker-handler:latest \
  .
```

### Running Containers

#### Handler Container

The handler container runs the chaos-broker handler service. It expects:
- Experiment files in `/app/local_only/experiments/`
- Journal output in `/app/local_only/journals/`

**Basic run:**

```bash
./scripts/run-handler.sh
```

**With custom volumes:**

```bash
podman run -d \
  --name chaos-broker-handler \
  -p 8080:8080 \
  -v /path/to/experiments:/app/local_only/experiments:Z \
  -v /path/to/journals:/app/local_only/journals:Z \
  -e local_mode=podman \
  chaos-broker-handler:latest
```

#### Orchestrator Container

The orchestrator container manages experiment execution workflow. It requires:
- Access to the handler service (via URL)
- Network connectivity to the handler

**Basic run:**

```bash
# Handler must be running first
./scripts/run-orchestrator.sh
```

**With custom handler URL:**

```bash
podman run -d \
  --name chaos-broker-orchestrator \
  -p 8081:8081 \
  -e HANDLER_SERVICE_URL=http://host.containers.internal:8080 \
  chaos-broker-orchestrator:latest
```

**Note**: On Linux, use `172.17.0.1` instead of `host.containers.internal`. On macOS with Podman machine, use the machine's IP or container networking.

### Container Networking

Podman containers can communicate via:

1. **Host network** (Linux only):
   ```bash
   podman run --network host ...
   ```

2. **Container networking** (default):
   - Containers on the same network can reach each other by container name
   - Use `podman network create` to create custom networks

3. **Port mapping** (default approach):
   - Map container ports to host ports
   - Access services via `localhost` or `host.containers.internal`

**Example: Connect orchestrator to handler**

```bash
# Create a podman network
podman network create chaos-broker-net

# Run handler on the network
podman run -d \
  --name handler \
  --network chaos-broker-net \
  -p 8080:8080 \
  chaos-broker-handler:latest

# Run orchestrator on the same network
podman run -d \
  --name orchestrator \
  --network chaos-broker-net \
  -p 8081:8081 \
  -e HANDLER_SERVICE_URL=http://handler:8080 \
  chaos-broker-orchestrator:latest
```

### Managing Containers

**List containers:**
```bash
podman ps           # Running containers
podman ps -a        # All containers
```

**View logs:**
```bash
podman logs chaos-broker-handler
podman logs -f chaos-broker-handler  # Follow logs
```

**Stop containers:**
```bash
podman stop chaos-broker-handler
podman stop chaos-broker-orchestrator
```

**Remove containers:**
```bash
podman rm chaos-broker-handler
podman rm chaos-broker-orchestrator
```

**Clean up script:**
```bash
./scripts/cleanup.sh
```

### Managing Images

**List images:**
```bash
podman images
podman images | grep chaos-broker
```

**Remove images:**
```bash
podman rmi chaos-broker-handler:latest
podman rmi chaos-broker-orchestrator:latest
```

**Save/load images:**
```bash
# Save image to file
podman save -o chaos-broker-handler.tar chaos-broker-handler:latest

# Load image from file
podman load -i chaos-broker-handler.tar
```

## Differences from Docker

While Podman is Docker-compatible, there are a few differences to note:

1. **No daemon**: Podman runs without a daemon (rootless by default)
2. **Command syntax**: Commands are mostly identical (`podman` instead of `docker`)
3. **Networking**: Slightly different networking behavior (especially on macOS)
4. **Volume mounts**: On SELinux systems, use `:Z` suffix for proper labeling

## Storage and Volumes

### Using Bind Mounts

Bind mount host directories into containers:

```bash
podman run -v /host/path:/container/path:Z ...
```

The `:Z` suffix is required on SELinux systems (Fedora/RHEL) for proper labeling.

### Using Named Volumes

Create and use named volumes:

```bash
# Create volume
podman volume create chaos-broker-data

# Use volume
podman run -v chaos-broker-data:/app/local_only:Z ...
```

### Storage Locations

**Linux:**
- Images: `~/.local/share/containers/storage/`
- Containers: `~/.local/share/containers/storage/containers/`

**macOS (with Podman machine):**
- Storage is inside the Podman machine VM

## Troubleshooting

### Podman Machine Issues (macOS)

**Error: "Cannot connect to Podman" or "connection refused":**

This error occurs when the Podman machine is not running. On macOS, Podman requires a virtual machine to be running.

```bash
# Check machine status
podman machine list

# Start the machine
podman machine start

# Verify connection
podman info
```

**Machine won't start:**
```bash
# Check machine status
podman machine list

# Restart machine
podman machine stop
podman machine start
```

**Reset machine:**
```bash
podman machine stop
podman machine rm
podman machine init
podman machine start
```

### Module Not Found Errors

**Error: "ModuleNotFoundError: No module named 'experiment_bofa'"**

This error occurs when the container image was built with editable installs (`pip install -e`) which don't work properly in multi-stage Docker builds. The Dockerfile has been updated to fix this issue.

If you encounter this error:
1. Rebuild the container images:
   ```bash
   ./scripts/build-images.sh handler
   ```
2. Remove the old container and run again:
   ```bash
   podman rm -f chaos-broker-handler
   ./scripts/run-handler.sh
   ```

### Container Networking Issues

**Containers can't communicate:**
- Ensure containers are on the same network
- Check firewall settings
- Verify service URLs and ports

**Can't access services from host:**
- Verify port mappings (`-p host:container`)
- Check if ports are already in use
- On macOS, ensure Podman machine is running

### Permission Issues

**Permission denied errors:**
- Podman runs rootless by default
- Use `podman unshare` for operations requiring elevated permissions
- Check volume mount permissions

### Image Build Failures

**Build context issues:**
- Ensure you're running from the correct directory
- Verify Dockerfile paths are correct
- Check that all required files are in the build context

## Integration with Kubernetes/OpenShift

Podman-built images can be used with Kubernetes/OpenShift:

1. **Push to registry:**
   ```bash
   podman tag chaos-broker-handler:latest registry.example.com/chaos-broker-handler:latest
   podman push registry.example.com/chaos-broker-handler:latest
   ```

2. **Import to OpenShift:**
   ```bash
   oc import-image chaos-broker-handler:latest \
     --from=registry.example.com/chaos-broker-handler:latest \
     --confirm \
     -n chaos-broker
   ```

3. **Use in Kubernetes manifests:**
   - Update image references in deployment manifests
   - Ensure images are accessible from the cluster

## Next Steps

1. **Build and test locally**: Use the scripts to build and run containers
2. **Integrate with CI/CD**: Use Podman in your CI/CD pipelines
3. **Deploy to Kubernetes**: Push images to a registry and deploy
4. **Develop and iterate**: Use Podman for local development

## References

- [Podman Documentation](https://docs.podman.io/)
- [Podman vs Docker](https://podman.io/whatis.html)
- [Rootless Podman](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)

## Support

For issues or questions:
- Check container logs: `podman logs <container-name>`
- Review handler documentation: `../../orchestrator/README.md`
- Check Podman status: `podman info`

