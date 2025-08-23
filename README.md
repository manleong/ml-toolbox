# Container Removal Tool

A helper script to deal with stubborn Docker containers and processes  
(like `docker-proxy`) that keep ports bound even after you try to stop a container.

This script can:

- Kill processes listening on a given host port (e.g. `docker-proxy`).
- Stop a container by name/ID.
- Force-kill a container's underlying `containerd-shim` process if `docker stop` fails.
- (Optional) Remove the container after stopping.

---

## Usage

sudo ./kill_port_and_stop.sh [options]

### Options

| Flag            | Description                                                                 |
|-----------------|-----------------------------------------------------------------------------|
| `-p PORT`       | Host port to inspect and clear (e.g. `5432`).                              |
| `-c CONTAINER`  | Container name or ID to stop (e.g. `webui`).                               |
| `-t TIMEOUT`    | Timeout for `docker stop` in seconds (default: `0`).                       |
| `-f`            | Force mode: if `docker stop` fails, kill the container's `containerd-shim`. |
| `-y`            | Non-interactive: auto-confirm killing PIDs without prompting.              |
| `--dry-run`     | Show what would be done (no processes killed, no docker actions).          |
| `-h`            | Show usage help.                                                           |

---

## Examples

### Kill any process holding a port

sudo ./kill_port_and_stop.sh -p 5432


### Stop a container by name


sudo ./kill_port_and_stop.sh -c webui


### Stop a container and force kill its shim if `docker stop` fails


sudo ./kill_port_and_stop.sh -c webui -f


### Kill processes on a port, then stop a container


sudo ./kill_port_and_stop.sh -p 5432 -c postgres


### Dry-run (see what would happen without killing/stopping)


sudo ./kill_port_and_stop.sh -p 3000 -c webui --dry-run


---

## Notes

- Run as **root** (`sudo`) for full effect.  
- Use `-f` with care: it will `kill -9` the container's `containerd-shim`, which is safe but abrupt.  
- This script is mainly for situations where Docker containers cannot be stopped/removed normally because of stuck `docker-proxy` or permission issues.  
