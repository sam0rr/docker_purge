# Docker Purge

A Docker environment cleanup and optimization tool written in Bash. This script analyzes your Docker disk usage, prunes unused containers, images, networks, volumes, and build caches, and provides a detailed report of the reclaimed space.

## Features

- **Usage Analysis**: Calculates Docker disk usage before and after cleanup using standard tools.
- **Full Pruning**: Cleans stopped containers, all images (not just dangling), unused networks, and all build caches.
- **Volume Cleanup**: Removes all unused volumes to reclaim maximum space.
- **Zero Dependencies**: Optimized for portability; works on Arch Linux, Debian, Ubuntu, etc. (No `bc` required).
- **Hard Reset Mode**: Can stop all running containers before purging with the `--force` flag.
- **Interactive Support**: Works seamlessly when piped from `curl` by using `/dev/tty`.

## Prerequisites

- `bash` (version 4+)
- `docker` (installed and running)

Ensure your user has permissions to run Docker commands without `sudo`, or run the script with appropriate privileges.

## Installation

Choose one of the following methods:

### 1. One‑line execution (curl)

_Downloads and executes the script. Use the following syntax to pass arguments:_

**Standard interactive cleanup:**

```bash
curl -fsSL https://raw.githubusercontent.com/sam0rr/docker_purge/main/docker_purge.sh | bash
```

**With arguments:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sam0rr/docker_purge/main/docker_purge.sh) --force --no-confirm
```

### 2. Install as a system command

1. Download to `/usr/local/bin`:

   ````bash
       sudo curl -fsSL \
           https://raw.githubusercontent.com/sam0rr/docker_purge/main/docker_purge.sh \
           -o /usr/local/bin/docker-purge   ```
   ````

2. Make executable:

   ```bash
   sudo chmod +x /usr/local/bin/docker-purge
   ```

3. Run it directly:

   ```bash
   docker-purge
   ```

## How it works

1. **validate_requirements**: Ensures `docker` is available and the daemon is reachable.
2. **get_docker_usage**: Uses `docker system df` and `awk` to calculate total byte usage.
3. **confirm_purge**: Provides a warning and asks for user confirmation.
4. **perform_cleanup**:
   - Stops all running containers if `--force` is used.
   - Sequentially executes `builder prune`, `container prune`, `image prune`, `volume prune`, and a final `system prune`.
5. **display_summary**: Compares pre and post usage, formatting the results into a clean, colored report.

## CLI Usage

You can view the help message by running `docker-purge --help`:

```text
DOCKER PURGE — Usage Guide

USAGE:
  docker-purge [OPTIONS]

OPTIONS:
  -h, --help         Show this help message and exit
  --no-confirm      Skip interactive confirmation prompts
  --force           Stop all running containers before purging

EXAMPLES:
  # Standard interactive cleanup
  docker-purge

  # Hard reset (Stop all and purge without asking)
  docker-purge --force --no-confirm

  # Run via curl (piped with arguments)
  bash <(curl -fsSL https://raw.githubusercontent.com/sam0rr/docker_purge/main/docker_purge.sh) --force --no-confirm
```

## Arguments

- `--no-confirm`: Skip interactive prompts (useful for automation).
- `--force`: Stop all currently running containers before starting the cleanup.

## License

MIT License © 2026 Samorr
