#!/usr/bin/env bash

set -euo pipefail

MODEL_NAME="${MODEL_NAME:-qwen3-coder:latest}"
OLLAMA_HOST_BIND="${OLLAMA_HOST_BIND:-0.0.0.0:11434}"
OLLAMA_KEEP_ALIVE_VALUE="${OLLAMA_KEEP_ALIVE_VALUE:-24h}"
TAILSCALE_STATE_PATH="${TAILSCALE_STATE_PATH:-/tmp/tailscaled.state}"
TAILSCALE_LOG_PATH="${TAILSCALE_LOG_PATH:-/tmp/tailscaled.log}"
OLLAMA_LOG_PATH="${OLLAMA_LOG_PATH:-/tmp/ollama-serve.log}"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$1"
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 1
  fi
}

install_base_packages() {
  log "Installing required Linux packages"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl screen zstd
}

install_tailscale() {
  if command -v tailscale >/dev/null 2>&1; then
    log "Tailscale already installed"
    return
  fi

  log "Installing Tailscale"
  curl -fsSL https://tailscale.com/install.sh | sh
}

start_tailscaled() {
  if pgrep -x tailscaled >/dev/null 2>&1; then
    log "tailscaled is already running"
    return
  fi

  log "Starting tailscaled in background"
  nohup tailscaled --tun=userspace-networking --state="$TAILSCALE_STATE_PATH" >"$TAILSCALE_LOG_PATH" 2>&1 &
  sleep 3
}

ensure_tailscale_login() {
  if tailscale status >/dev/null 2>&1; then
    log "Tailscale session is active"
    return
  fi

  log "Tailscale login is required"
  echo "A login URL may appear below. Open it once to connect this Colab runtime:"
  tailscale up --reset
}

install_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    log "Ollama already installed"
    return
  fi

  log "Installing Ollama"
  curl -fsSL https://ollama.com/install.sh | sh
}

start_ollama_server() {
  if pgrep -f "ollama serve" >/dev/null 2>&1; then
    log "Ollama server is already running"
    return
  fi

  log "Starting Ollama server in background"
  nohup env OLLAMA_HOST="$OLLAMA_HOST_BIND" OLLAMA_KEEP_ALIVE="$OLLAMA_KEEP_ALIVE_VALUE" ollama serve >"$OLLAMA_LOG_PATH" 2>&1 &
  sleep 4
}

wait_for_ollama_api() {
  local retries=30
  local i

  for ((i=1; i<=retries; i++)); do
    if curl --silent --fail http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done

  echo "Ollama API did not become ready in time" >&2
  exit 1
}

pull_model_with_progress() {
  require_command curl
  require_command python3

  wait_for_ollama_api

  curl --no-buffer --silent \
    -X POST http://127.0.0.1:11434/api/pull \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$MODEL_NAME\",\"stream\":true}" |
    python3 -c '
import json
import sys

last_status = None
last_percent = -1

for raw_line in sys.stdin:
    line = raw_line.strip()
    if not line:
        continue

    try:
        item = json.loads(line)
    except json.JSONDecodeError:
        continue

    status = item.get("status", "working")
    completed = item.get("completed")
    total = item.get("total")

    if total and completed is not None and total > 0:
        percent = int((completed * 100) / total)
        if status != last_status or percent != last_percent:
            downloaded_mb = completed / (1024 * 1024)
            total_mb = total / (1024 * 1024)
            print(f"Status   : {status}")
            print(f"Progress : {percent}% ({downloaded_mb:.1f} MB / {total_mb:.1f} MB)")
            print("-" * 40)
            sys.stdout.flush()
            last_status = status
            last_percent = percent
    else:
        if status != last_status:
            print(f"Status   : {status}")
            print("Progress : preparing...")
            print("-" * 40)
            sys.stdout.flush()
            last_status = status

print("Status   : completed")
print("Progress : 100%")
'
}

ensure_model() {
  log "Checking model: $MODEL_NAME"
  if ollama show "$MODEL_NAME" >/dev/null 2>&1; then
    log "Model already available"
    return
  fi

  log "Pulling model: $MODEL_NAME"
  pull_model_with_progress
}

get_tailscale_ip() {
  tailscale ip -4 | head -n 1
}

print_connection_info() {
  local ts_ip
  ts_ip="$(get_tailscale_ip)"

  echo
  echo "========================================"
  echo "Connection Information"
  echo "========================================"
  echo "Model           : $MODEL_NAME"
  echo "Tailscale IP    : $ts_ip"
  echo "Ollama API Base : http://$ts_ip:11434"
  echo "OpenAI Base URL : http://$ts_ip:11434/v1"
  echo "Dummy API Key   : ollama"
  echo
  echo "Use the dummy key only for clients that require a non-empty API key field."
  echo "Continue with provider=ollama usually does not need an API key."
}

print_continue_config() {
  local ts_ip
  ts_ip="$(get_tailscale_ip)"

  cat <<EOF
name: Colab Ollama
version: 1.0.0
schema: v1

models:
  - name: Qwen3 Coder
    provider: ollama
    model: $MODEL_NAME
    apiBase: http://$ts_ip:11434

    defaultCompletionOptions:
      contextLength: 8192
      temperature: 0.2

    capabilities:
      - tool_use

    roles:
      - chat
      - edit
      - apply
      - autocomplete
EOF
}

verify_api() {
  require_command curl
  local ts_ip
  ts_ip="$(get_tailscale_ip)"

  log "Checking Ollama API response"
  curl --silent "http://$ts_ip:11434/api/tags" | head -c 400
  echo
}

setup_everything() {
  install_base_packages
  install_tailscale
  start_tailscaled
  ensure_tailscale_login
  install_ollama
  start_ollama_server
}

run_chat_mode() {
  setup_everything
  ensure_model
  log "Starting local chat mode"
  ollama run "$MODEL_NAME"
}

run_api_mode() {
  setup_everything
  ensure_model
  print_connection_info
  verify_api
  echo "Continue config:"
  print_continue_config
}

show_status() {
  echo
  echo "========================================"
  echo "Runtime Status"
  echo "========================================"

  if pgrep -x tailscaled >/dev/null 2>&1; then
    echo "tailscaled      : running"
  else
    echo "tailscaled      : stopped"
  fi

  if tailscale status >/dev/null 2>&1; then
    echo "tailscale login : connected"
    echo "tailscale ip    : $(get_tailscale_ip)"
  else
    echo "tailscale login : not connected"
  fi

  if pgrep -f "ollama serve" >/dev/null 2>&1; then
    echo "ollama serve    : running"
  else
    echo "ollama serve    : stopped"
  fi

  if command -v ollama >/dev/null 2>&1; then
    echo "ollama version  : $(ollama --version)"
    echo "installed models:"
    ollama list || true
  else
    echo "ollama version  : not installed"
  fi
}

stop_services() {
  log "Stopping Ollama server if running"
  pkill -f "ollama serve" || true
}

show_help() {
  cat <<'EOF'
Usage:
  bash colab_ai.sh setup
  bash colab_ai.sh chat
  bash colab_ai.sh api
  bash colab_ai.sh config
  bash colab_ai.sh status
  bash colab_ai.sh stop

Commands:
  setup   Install and start Tailscale + Ollama for the current Colab runtime
  chat    Open local chat mode inside Colab using ollama run
  api     Start API mode for VS Code / Continue and print ready-to-use config
  config  Print Continue config using the current Tailscale IP
  status  Show service and model status
  stop    Stop the Ollama server

Optional environment variables:
  MODEL_NAME=qwen3-coder:latest
  OLLAMA_HOST_BIND=0.0.0.0:11434
  OLLAMA_KEEP_ALIVE_VALUE=24h
EOF
}

main() {
  local command="${1:-help}"

  case "$command" in
    setup)
      setup_everything
      ;;
    chat)
      run_chat_mode
      ;;
    api)
      run_api_mode
      ;;
    config)
      print_continue_config
      ;;
    status)
      show_status
      ;;
    stop)
      stop_services
      ;;
    help|-h|--help)
      show_help
      ;;
    *)
      echo "Unknown command: $command" >&2
      show_help
      exit 1
      ;;
  esac
}

main "$@"
