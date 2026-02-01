#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

usage() {
  cat <<EOF
Usage: sudo $0 [-p PORT] [-c CONTAINER] [-t TIMEOUT] [-r] [-f] [-y] [--dry-run]

Options:
  -p PORT        Host port to inspect/clear (can be repeated)
  -c CONTAINER   Container name or id (discover ports, stop/kill container)
  -t TIMEOUT     docker stop timeout seconds (default 0)
  -r             Also remove container after stopping (default: no)
  -f             Force kill containerd-shim if docker stop fails
  -y             Non-interactive: kill without prompting
  --dry-run      Only show actions, don't execute
  -h             Show this help

Examples:
  $0 -p 5432
  $0 -c mydb
  $0 -p 3000 -c web -r -y
EOF
  exit 1
}

PORTS=()
CONTAINER=""
TIMEOUT=0
REMOVE=0
FORCE_KILL=0
AUTO_YES=0
DRY_RUN=0

# parse args
while [ $# -gt 0 ]; do
  case "$1" in
    -p) PORTS+=("$2"); shift 2 ;;
    -c) CONTAINER="$2"; shift 2 ;;
    -t) TIMEOUT="$2"; shift 2 ;;
    -r) REMOVE=1; shift ;;
    -f) FORCE_KILL=1; shift ;;
    -y) AUTO_YES=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [ ${#PORTS[@]} -eq 0 ] && [ -z "$CONTAINER" ]; then
  echo "ERROR: need -p PORT and/or -c CONTAINER"
  usage
fi

SUDO_CMD=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO_CMD="sudo"
fi

confirm() {
  local prompt="$1"
  if [ "$AUTO_YES" -eq 1 ]; then return 0; fi
  read -r -p "$prompt [y/N]: " ans
  [[ "$ans" =~ ^[Yy]([Ee][Ss])?$ ]]
}

find_pids_on_port() {
  local port="$1"
  local pids=""
  if command -v lsof >/dev/null 2>&1; then
    pids="$(lsof -t -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)"
  fi
  if [ -z "$pids" ] && command -v ss >/dev/null 2>&1; then
    pids="$(ss -ltnp 2>/dev/null | awk -v p=":$port" '
      $0 ~ p {
        for(i=1;i<=NF;i++) if($i ~ /pid=/) {
          split($i,a,","); for(j in a) if(a[j] ~ /^pid=/) {
            split(a[j],b,"="); print b[2]
          }
        }
      }' | sort -u || true)"
  fi
  echo "$pids"
}

inspect_pid() {
  local pid="$1"
  if ps -p "$pid" >/dev/null 2>&1; then
    ps -p "$pid" -o pid=,user=,comm=,args= | sed -E 's/^[[:space:]]+//'
  else
    echo "$pid (not running)"
  fi
}

# --- Step 1: Kill by port(s)
for PORT in "${PORTS[@]}"; do
  echo "==> Searching for processes on host port: $PORT"
  PIDS="$(find_pids_on_port "$PORT")"

  if [ -z "$PIDS" ]; then
    echo "  No process found on port $PORT."
    continue
  fi

  echo "  Found PID(s): $PIDS"
  for pid in $PIDS; do
    inspect_pid "$pid"
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  [DRY-RUN] Would kill $pid"
      continue
    fi
    if confirm "  Kill PID $pid ?"; then
      $SUDO_CMD kill "$pid" || true
      sleep 1
      if ps -p "$pid" >/dev/null 2>&1; then
        echo "  Still alive, sending SIGKILL..."
        $SUDO_CMD kill -9 "$pid" || true
      fi
    fi
  done
done

# --- Step 2: Work on container
if [ -n "$CONTAINER" ]; then
  echo
  echo "==> Processing container: $CONTAINER"

  CONTAINER_ID=$($SUDO_CMD docker inspect --format '{{.Id}}' "$CONTAINER" 2>/dev/null || true)
  if [ -z "$CONTAINER_ID" ]; then
    echo "  Container not found."
    exit 1
  fi

  HOST_PORTS=$($SUDO_CMD docker inspect \
    --format '{{range $k,$v := .NetworkSettings.Ports}}{{if $v}}{{(index $v 0).HostPort}} {{end}}{{end}}' \
    "$CONTAINER")
  if [ -n "$HOST_PORTS" ]; then
    echo "  Container exposes host port(s): $HOST_PORTS"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [DRY-RUN] Would stop container $CONTAINER"
  else
    echo "  Attempting docker stop (timeout=$TIMEOUT)..."
    if ! $SUDO_CMD docker stop -t "$TIMEOUT" "$CONTAINER"; then
      echo "  docker stop failed."
      if [ "$FORCE_KILL" -eq 1 ]; then
        echo "  Killing containerd-shim for $CONTAINER_ID ..."
        SHIM_PIDS=$(ps -ef | grep "$CONTAINER_ID" | grep containerd-shim | awk '{print $2}' || true)
        if [ -n "$SHIM_PIDS" ]; then
          for pid in $SHIM_PIDS; do
            echo "   kill -9 $pid"
            $SUDO_CMD kill -9 "$pid" || true
          done
        fi
        echo "  Retrying docker stop..."
        $SUDO_CMD docker stop -t "$TIMEOUT" "$CONTAINER" || true
      fi
    fi
  fi

  if [ "$REMOVE" -eq 1 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  [DRY-RUN] Would remove container $CONTAINER"
    else
      echo "  Removing container..."
      $SUDO_CMD docker rm -f "$CONTAINER" || true
    fi
  fi
fi

echo "==> Done."
