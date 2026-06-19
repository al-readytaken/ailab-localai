#!/bin/bash
set -e

# Set root password if provided
if [ -n "$ROOT_PASSWORD" ]; then
  echo "root:$ROOT_PASSWORD" | chpasswd
fi

# Start SSH daemon in background
mkdir -p /var/run/sshd
/usr/sbin/sshd
echo "-> SSH daemon started"

# Start Ollama server in background
export OLLAMA_CONTEXT_LENGTH=$DEFAULT_CONTEXT_LENGTH
export OLLAMA_HOST="$OLLAMA_IP_WEB"
export HSA_OVERRIDE_GFX_VERSION=12.0.0
export OLLAMA_NUM_GPU=-1
export OLLAMA_NUM_PARALLEL=2
export OLLAMA_FLASH_ATTENTION=1
/bin/ollama serve &
SERVER_PID=$!
echo "-> Ollama daemon started as PID $SERVER_PID"

# Wait for server to be ready
for i in $(seq 1 30); do
  if /bin/ollama list >/dev/null 2>&1; then
    echo "-> Ollama daemon ready"
    break
  fi
  sleep 1
done

# Pull models from models.txt
if [ -f /models.txt ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(echo "$line" | xargs)"
    [ -z "$line" ] && continue
    [[ "$line" == \#* ]] && continue

    echo "-> Pulling model: $line"
    /bin/ollama pull "$line"
  done </models.txt
fi

# Bring server to foreground
wait $SERVER_PID
