#!/usr/bin/env bash

set -euo pipefail

MODEL_NAME="${MODEL_NAME:-phi3:mini}"
OLLAMA_HOST_BIND="${OLLAMA_HOST_BIND:-0.0.0.0:11434}"
OLLAMA_KEEP_ALIVE_VALUE="${OLLAMA_KEEP_ALIVE_VALUE:-0}"
TAILSCALE_STATE_PATH="${TAILSCALE_STATE_PATH:-/tmp/tailscaled.state}"
TAILSCALE_LOG_PATH="${TAILSCALE_LOG_PATH:-/tmp/tailscaled.log}"
OLLAMA_LOG_PATH="${OLLAMA_LOG_PATH:-/tmp/ollama-serve.log}"
WEB_CHAT_PORT="${WEB_CHAT_PORT:-8501}"
WEB_CHAT_HOST_BIND="${WEB_CHAT_HOST_BIND:-0.0.0.0}"
WEB_CHAT_LOG_PATH="${WEB_CHAT_LOG_PATH:-/tmp/colab-chat-ui.log}"

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

install_streamlit() {
  if ! command -v python3 >/dev/null 2>&1; then
    log "Skipping streamlit install because python3 is not available"
    return
  fi

  if python3 -m pip show streamlit >/dev/null 2>&1; then
    log "streamlit is already installed"
    return
  fi

  log "Installing streamlit for web chat UI"
  python3 -m pip install -q streamlit requests
}

install_colab_xterm() {
  if ! command -v python3 >/dev/null 2>&1; then
    log "Skipping colab-xterm install because python3 is not available"
    return
  fi

  if python3 -m pip show colab-xterm >/dev/null 2>&1; then
    log "colab-xterm is already installed"
    return
  fi

  log "Installing colab-xterm for Colab terminal support"
  python3 -m pip install -q colab-xterm
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
  nohup env \
    OLLAMA_HOST="$OLLAMA_HOST_BIND" \
    OLLAMA_KEEP_ALIVE="$OLLAMA_KEEP_ALIVE_VALUE" \
    OLLAMA_NUM_GPU=999999 \
    OLLAMA_GPU_LAYERS=999999 \
    OLLAMA_NUM_LOAD=1 \
    ollama serve >"$OLLAMA_LOG_PATH" 2>&1 &
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
            sys.stdout.write(
                f"\rStatus: {status} | Progress: {percent}% "
                f"({downloaded_mb:.1f} MB / {total_mb:.1f} MB)"
            )
            sys.stdout.flush()
            last_status = status
            last_percent = percent
    else:
        if status != last_status:
            sys.stdout.write(f"\rStatus: {status} | Progress: preparing...                ")
            sys.stdout.flush()
            last_status = status
print()
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

get_script_dir() {
  local source_path
  source_path="${BASH_SOURCE[0]}"
  cd "$(dirname "$source_path")" >/dev/null 2>&1 && pwd
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

wait_for_web_chat_ui() {
  local retries=300
  local i

  for ((i=1; i<=retries; i++)); do
    if curl --silent --fail "http://127.0.0.1:${WEB_CHAT_PORT}/health" >/dev/null 2>&1; then
      return
    fi
    sleep 1
  done

  echo "Web chat UI did not become ready in time" >&2
  echo "Check log file: $WEB_CHAT_LOG_PATH" >&2
  exit 1
}

start_web_chat_ui() {
  require_command curl
  require_command python3

  if curl --silent --fail "http://127.0.0.1:${WEB_CHAT_PORT}/health" >/dev/null 2>&1; then
    log "Web chat UI is already running"
    return
  fi

  log "Stopping any existing web chat UI process"
  pkill -9 -f "streamlit_chat.py" || true
  pkill -9 -f "gradio_chat.py" || true
  pkill -9 -f "chat_ui.py" || true
  sleep 2

  log "Starting Streamlit web chat UI in background"
  nohup env \
    MODEL_NAME="$MODEL_NAME" \
    OLLAMA_CHAT_URL="http://127.0.0.1:11434/api/chat" \
    streamlit run "$(get_script_dir)/streamlit_chat.py" \
    --server.port="${WEB_CHAT_PORT}" \
    --server.address="${WEB_CHAT_HOST_BIND}" \
    --server.headless=true \
    --browser.gatherUsageStats=false >"$WEB_CHAT_LOG_PATH" 2>&1 &
  
  sleep 3

  wait_for_web_chat_ui
}

print_web_chat_info() {
  local ts_ip
  ts_ip="$(get_tailscale_ip)"

  echo
  echo "========================================"
  echo "Web Chat Information"
  echo "========================================"
  echo "Local URL        : http://127.0.0.1:${WEB_CHAT_PORT}"
  echo "Tailscale URL    : http://${ts_ip}:${WEB_CHAT_PORT}"
  echo "Model            : $MODEL_NAME"
  echo
  echo "Open the Tailscale URL in a browser tab to chat without blocking the terminal."
}

setup_everything() {
  install_colab_xterm
  install_base_packages
  install_streamlit
  install_tailscale
  start_tailscaled
  ensure_tailscale_login
  install_ollama
  start_ollama_server
}

ensure_services_running() {
  if ! pgrep -x tailscaled >/dev/null 2>&1; then
    log "Starting tailscaled"
    start_tailscaled
    ensure_tailscale_login
  fi

  if ! pgrep -f "ollama serve" >/dev/null 2>&1; then
    log "Starting Ollama server"
    start_ollama_server
  fi
}

warm_up_model() {
  log "Warming up model with a dummy API request (this may take a minute)..."
  curl --silent --max-time 120 \
    -X POST http://127.0.0.1:11434/api/generate \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL_NAME\",\"prompt\":\"hi\",\"stream\":false}" \
    >/dev/null 2>&1 || true
  log "Model warm-up complete. Ready for fast responses."
}

start_keep_alive() {
  if pgrep -f "keep_alive.sh" >/dev/null 2>&1; then
    log "Keep-alive process already running"
    return
  fi

  log "Starting keep-alive process (sends dummy API request every 2 minutes)"
  nohup bash -c "
    while true; do
      sleep 120
      curl --silent --max-time 30 \
        -X POST http://127.0.0.1:11434/api/generate \
        -H \"Content-Type: application/json\" \
        -d \"{\\\"model\\\":\\\"$MODEL_NAME\\\",\\\"prompt\\\":\\\".\\\",\\\"stream\\\":false}\" \
        >/dev/null 2>&1 || true
    done
  " >/tmp/keep_alive.log 2>&1 &
}

stop_keep_alive() {
  log "Stopping keep-alive process"
  pkill -f "keep_alive.sh" || true
  pkill -f "while true; do sleep" || true
}

run_setup_mode() {
  setup_everything
  ensure_model
  warm_up_model
  start_keep_alive
  log "Setup complete. Chat and API modes should now start much faster."
}

run_chat_mode() {
  ensure_services_running
  ensure_model
  log "Starting local chat mode"
  cd /tmp || cd /
  ollama run "$MODEL_NAME"
}

run_web_chat_mode() {
  ensure_services_running
  ensure_model
  start_keep_alive
  start_web_chat_ui
  print_web_chat_info
}

run_api_mode() {
  ensure_services_running
  ensure_model
  start_keep_alive
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

  if curl --silent --fail "http://127.0.0.1:${WEB_CHAT_PORT}/health" >/dev/null 2>&1; then
    echo "web chat ui     : running"
    echo "web chat port   : ${WEB_CHAT_PORT}"
  else
    echo "web chat ui     : stopped"
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
  log "Stopping web chat UI if running"
  pkill -f "chat_ui.py" || true
  pkill -f "streamlit_chat.py" || true
  log "Stopping keep-alive process"
  stop_keep_alive
  sleep 1
}

restart_api_mode() {
  stop_services
  sleep 2
  setup_everything
  ensure_model
  print_connection_info
  verify_api
  echo "Continue config:"
  print_continue_config
}

show_web_chat_log() {
  if [ -f "$WEB_CHAT_LOG_PATH" ]; then
    echo "Web chat UI log:"
    cat "$WEB_CHAT_LOG_PATH"
  else
    echo "No web chat log file found at: $WEB_CHAT_LOG_PATH"
  fi
}

show_activity_log() {
  echo
  echo "========================================"
  echo "Activity Monitor"
  echo "========================================"
  
  echo "Keep-alive status:"
  if pgrep -f "while true; do sleep" >/dev/null 2>&1; then
    echo "  Status: Running (sends dummy API request every 4 min)"
    echo "  Log: /tmp/keep_alive.log"
  else
    echo "  Status: Stopped"
  fi
  
  echo
  echo "Recent Ollama activity:"
  if [ -f "$OLLAMA_LOG_PATH" ]; then
    tail -20 "$OLLAMA_LOG_PATH" 2>/dev/null || echo "  No recent activity"
  else
    echo "  No log file found"
  fi
  
  echo
  echo "Services status:"
  if pgrep -x tailscaled >/dev/null 2>&1; then
    echo "  tailscaled: Running"
  else
    echo "  tailscaled: Stopped"
  fi
  
  if pgrep -f "ollama serve" >/dev/null 2>&1; then
    echo "  ollama serve: Running"
  else
    echo "  ollama serve: Stopped"
  fi
  
  if pgrep -f "streamlit_chat.py" >/dev/null 2>&1; then
    echo "  web chat UI: Running"
  else
    echo "  web chat UI: Stopped"
  fi
}

show_help() {
  cat <<'EOF'
Usage:
  bash colab_ai.sh setup
  bash colab_ai.sh chat
  bash colab_ai.sh webchat
  bash colab_ai.sh api
  bash colab_ai.sh restart
  bash colab_ai.sh config
  bash colab_ai.sh status
  bash colab_ai.sh stop
  bash colab_ai.sh log
  bash colab_ai.sh monitor

Commands:
  setup    Install everything and preload the model for the current Colab runtime
  chat     Open local chat mode inside Colab using ollama run
  webchat  Start a browser-based chat UI that runs in the background
  api      Start API mode for VS Code / Continue and print ready-to-use config
  restart  Stop the old Ollama server and start API mode again
  config   Print Continue config using the current Tailscale IP
  status   Show service and model status
  stop     Stop the Ollama server
  log      Show web chat UI log for debugging
  monitor  Show activity monitor with logs and service status

Optional environment variables:
  MODEL_NAME=phi3:mini
  OLLAMA_HOST_BIND=0.0.0.0:11434
  OLLAMA_KEEP_ALIVE_VALUE=0 (0 means model stays loaded indefinitely)
EOF
}

main() {
  local command="${1:-help}"

  case "$command" in
    setup)
      run_setup_mode
      ;;
    chat)
      run_chat_mode
      ;;
    webchat)
      run_web_chat_mode
      ;;
    api)
      run_api_mode
      ;;
    restart)
      restart_api_mode
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
    log)
      show_web_chat_log
      ;;
    monitor)
      show_activity_log
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
