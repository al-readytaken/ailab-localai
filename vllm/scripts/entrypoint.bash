#!/bin/bash
set -e

# Set root password if provided
if [ -n "$ROOT_PASSWORD" ]; then
  echo "root:$ROOT_PASSWORD" | chpasswd
fi

# Source venv
source /root/.venv/bin/activate

# Start SSH daemon in background
mkdir -p /var/run/sshd
/usr/sbin/sshd
echo "-> SSH daemon started"

export HF_TOKEN="$VLLM_HF_TOKEN"
# export VLLM_LOGGING_LEVEL=DEBUG
export VLLM_ALLOW_LONG_MAX_MODEL_LEN=1

# Set default model if not provided
MODEL="${VLLM_MODEL:-Qwen/Qwen2.5-0.5B-Instruct}"
# MODEL="${VLLM_MODEL:-Qwen/Qwen3-8B}"

# Build vLLM serve args
VLLM_ARGS=("serve" "$MODEL")

# qwen
VLLM_ARGS+=("-O3")
VLLM_ARGS+=("--enable-prefix-caching")
VLLM_ARGS+=("--enable-auto-tool-choice")
VLLM_ARGS+=("--tool-call-parser" "hermes")


# VLLM_ARGS+=("--enable-reasoning")
# VLLM_ARGS+=("--reasoning-parser" "deepseek_v4")
  # VLLM_ARGS+=("--rope-scaling" '{"type":"yarn","factor":4.0}')

# Add host and port
VLLM_ARGS+=("--host" "${VLLM_IP_WEB:-0.0.0.0}")
VLLM_ARGS+=("--port" "${VLLM_PORT_WEB:-8000}")


# GPU configuration
if [ -n "$VLLM_GPU_MEMORY_UTILIZATION" ]; then
  VLLM_ARGS+=("--gpu-memory-utilization" "$VLLM_GPU_MEMORY_UTILIZATION")
fi

if [ -n "$VLLM_MAX_MODEL_LEN" ]; then
  VLLM_ARGS+=("--max-model-len" "$VLLM_MAX_MODEL_LEN")
fi

if [ -n "$VLLM_DTYPE" ]; then
  VLLM_ARGS+=("--dtype" "$VLLM_DTYPE")
fi

if [ -n "$VLLM_TENSOR_PARALLEL_SIZE" ]; then
  VLLM_ARGS+=("--tensor-parallel-size" "$VLLM_TENSOR_PARALLEL_SIZE")
fi

if [ -n "$VLLM_DATA_PARALLEL_SIZE" ]; then
  VLLM_ARGS+=("--data_parallel_size" "$VLLM_DATA_PARALLEL_SIZE")
fi

if [ -n "$VLLM_KV_CACHE_QUANT" ]; then
  VLLM_ARGS+=("--kv-cache-dtype" "$VLLM_KV_CACHE_QUANT")
fi

if [ -n "$VLLM_MAX_NUM_SEQ" ]; then
  VLLM_ARGS+=("--max-num-seqs" "$VLLM_MAX_NUM_SEQ")
fi

if [ -n "$VLLM_MAX_NUM_BATCHED_TOKENS" ]; then
  VLLM_ARGS+=("--max-num-batched-tokens" "$VLLM_MAX_NUM_BATCHED_TOKENS")
fi

# Extra args from env (space-separated)
if [ -n "$VLLM_EXTRA_ARGS" ]; then
  read -ra EXTRA_ARGS <<<"$VLLM_EXTRA_ARGS"
  VLLM_ARGS+=("${EXTRA_ARGS[@]}")
fi

echo "-> Starting vLLM server with model: $MODEL"
echo "-> vLLM args: ${VLLM_ARGS[*]}"

# Start vLLM server in foreground
vllm "${VLLM_ARGS[@]}" &


exec tail -f /dev/null
