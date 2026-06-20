#!/bin/bash
set -e

if [ -n "$ROOT_PASSWORD" ]; then
  echo "root:$ROOT_PASSWORD" | chpasswd
fi

mkdir -p /var/run/sshd
/usr/sbin/sshd
echo "-> SSH daemon started"

MODEL_DIR="${LLAMACPP_MODEL_DIR:-/models}"
mkdir -p "$MODEL_DIR"

if [ -f /models.txt ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(echo "$line" | xargs)"
    [ -z "$line" ] && continue
    [[ "$line" == \#* ]] && continue

    repo="$(echo "$line" | cut -d'/' -f1-2)"
    file="$(echo "$line" | cut -d'/' -f3-)"
    output="$MODEL_DIR/$(basename "$file")"

    if [ ! -f "$output" ]; then
      echo "-> Downloading model: $line"
      hf download "$repo" "$file" --local-dir "$MODEL_DIR" 2>&1 || true
    else
      echo "-> Model exists: $output"
    fi
  done </models.txt
fi

MODEL="${LLAMACPP_MODEL:-}"
if [ -z "$MODEL" ]; then
  MODEL=$(find "$MODEL_DIR" -name "*.gguf" | head -1)
fi

if [ -z "$MODEL" ] || [ ! -f "$MODEL" ]; then
  echo "ERROR: No model found. Set LLAMACPP_MODEL or place a .gguf in $MODEL_DIR"
  exit 1
fi

LLAMACPP_ARGS=("-m" "$MODEL")
LLAMACPP_ARGS+=("--host" "${LLAMACPP_IP_WEB:-0.0.0.0}")
LLAMACPP_ARGS+=("--port" "8080")
LLAMACPP_ARGS+=("--verbose")

[ -n "$LLAMACPP_N_GPU" ]    && LLAMACPP_ARGS+=("-ngl" "$LLAMACPP_N_GPU")
[ -n "$LLAMACPP_CTX_SIZE" ] && LLAMACPP_ARGS+=("-c" "$LLAMACPP_CTX_SIZE")
[ -n "$LLAMACPP_N_PARALLEL" ] && LLAMACPP_ARGS+=("-np" "$LLAMACPP_N_PARALLEL")
[ -n "$LLAMACPP_BATCH_SIZE" ] && LLAMACPP_ARGS+=("-b" "$LLAMACPP_BATCH_SIZE")
[ -n "$LLAMACPP_UBATCH_SIZE" ] && LLAMACPP_ARGS+=("-ub" "$LLAMACPP_UBATCH_SIZE")
[ -n "$LLAMACPP_GPU_SPLIT" ] && LLAMACPP_ARGS+=("-gpu" "$LLAMACPP_GPU_SPLIT")
[ -n "$LLAMACPP_MAIN_GPU" ] && LLAMACPP_ARGS+=("-mg" "$LLAMACPP_MAIN_GPU")
[ -n "$LLAMACPP_TENSOR_SPLIT" ] && LLAMACPP_ARGS+=("-ts" "$LLAMACPP_TENSOR_SPLIT")
LLAMACPP_ARGS+=("--flash-attn" "${LLAMACPP_FLASH_ATTN:-auto}")

if [ "$LLAMACPP_NO_MMAP" = "1" ]; then
  LLAMACPP_ARGS+=("--no-mmap")
fi

if [ "$LLAMACPP_MLOCK" = "1" ]; then
  LLAMACPP_ARGS+=("--mlock")
fi

if [ -n "$LLAMACPP_EXTRA_ARGS" ]; then
  read -ra EXTRA_ARGS <<<"$LLAMACPP_EXTRA_ARGS"
  LLAMACPP_ARGS+=("${EXTRA_ARGS[@]}")
fi

echo "-> Starting llama-server with model: $MODEL"
echo "-> Args: ${LLAMACPP_ARGS[*]}"

/app/llama-server "${LLAMACPP_ARGS[@]}" &
SERVER_PID=$!

wait $SERVER_PID
