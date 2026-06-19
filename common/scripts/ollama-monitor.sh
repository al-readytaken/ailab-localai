#!/bin/bash
# Ollama throughput monitor - run with: ./scripts/ollama-monitor.sh [interval_seconds] [model]
set -e

INTERVAL=${1:-10}
MODEL=${2:-"qwen3.5:9b"}

echo "Monitoring Ollama throughput every ${INTERVAL}s (model: ${MODEL})"
echo "Press Ctrl+C to stop"
echo "------------------------------------------------------------"
printf "%-20s %-15s %-15s %-10s\n" "TIMESTAMP" "PROMPT tok/s" "EVAL tok/s" "GPU%"
echo "------------------------------------------------------------"

while true; do
  RESULT=$(curl -sf http://localhost:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"${MODEL}\", \"prompt\": \"Hello, respond with one word.\", \"stream\": false}" 2>/dev/null)

  if [ -n "$RESULT" ]; then
    echo "$RESULT" | python3 -c "
import sys, json
from datetime import datetime
d = json.load(sys.stdin)
eval_s = d.get('eval_duration', 0) / 1e9
eval_n = d.get('eval_count', 0)
prompt_s = d.get('prompt_eval_duration', 0) / 1e9
prompt_n = d.get('prompt_eval_count', 0)
gpu = d.get('load_duration', 0) / 1e9  # approximation
eval_rate = eval_n / eval_s if eval_s > 0 else 0
prompt_rate = prompt_n / prompt_s if prompt_s > 0 else 0
ts = datetime.now().strftime('%H:%M:%S')
print(f'{ts:20} {prompt_rate:>12.1f}   {eval_rate:>12.1f}   {\"-\":>8}')
"
  fi
  sleep "$INTERVAL"
done
