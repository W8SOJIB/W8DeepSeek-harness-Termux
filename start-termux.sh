#!/usr/bin/env bash
# ==============================================================================
# DeepSeek Harness - Termux Launcher
# ==============================================================================
# Runs DeepSeek Harness inside proot-distro Ubuntu environment on Termux.
# ==============================================================================

set -e

# ANSI color codes
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

# Locate repo directory
if [ -f "$SCRIPT_DIR/package.json" ]; then
  REPO_DIR="$SCRIPT_DIR"
elif [ -d "$HOME/W8DeepSeek-harness-Termux" ] && [ -f "$HOME/W8DeepSeek-harness-Termux/package.json" ]; then
  REPO_DIR="$HOME/W8DeepSeek-harness-Termux"
elif [ -d "$HOME/deepseek-harness" ] && [ -f "$HOME/deepseek-harness/package.json" ]; then
  REPO_DIR="$HOME/deepseek-harness"
else
  REPO_DIR="$(pwd)"
fi

DISTRO="ubuntu"

# Check if proot-distro and distro exist
DISTRO_READY=0
if command -v proot-distro >/dev/null 2>&1; then
  if proot-distro login "$DISTRO" -- true 2>/dev/null; then
    DISTRO_READY=1
  fi
fi

if [ "$DISTRO_READY" -eq 0 ]; then
  echo -e "${YELLOW}[!] Setup required: proot-distro or '$DISTRO' container is not ready.${NC}"
  echo -e "    Running 1-click installer now..."
  if [ -f "$REPO_DIR/install-termux.sh" ]; then
    exec bash "$REPO_DIR/install-termux.sh"
  else
    echo -e "${RED}[!] Could not find install-termux.sh in $REPO_DIR${NC}"
    exit 1
  fi
fi

# Load .env if present in repo
if [ -f "$REPO_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  source "$REPO_DIR/.env" 2>/dev/null || true
  set +a
fi

# Acquire wake lock if running in Termux to prevent background kill
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock
  trap 'termux-wake-unlock 2>/dev/null || true' EXIT INT TERM
fi

# Helper to run commands inside proot Ubuntu
run_in_proot() {
  local env_exports=""
  if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
    env_exports="${env_exports}export DEEPSEEK_API_KEY=\"$DEEPSEEK_API_KEY\"; "
  fi
  if [ -n "${DEEPSEEK_BASE_URL:-}" ]; then
    env_exports="${env_exports}export DEEPSEEK_BASE_URL=\"$DEEPSEEK_BASE_URL\"; "
  else
    env_exports="${env_exports}unset DEEPSEEK_BASE_URL; "
  fi

  proot-distro login "$DISTRO" \
    --termux-home \
    --bind "$REPO_DIR":/workspace \
    -- /bin/bash -c "
      $env_exports
      cd /workspace
      $*
    "
}

# Helper to get masked API key
get_masked_key() {
  if [ -n "${DEEPSEEK_API_KEY:-}" ]; then
    local len=${#DEEPSEEK_API_KEY}
    if [ "$len" -gt 10 ]; then
      echo "${DEEPSEEK_API_KEY:0:5}...${DEEPSEEK_API_KEY: -4}"
    else
      echo "********"
    fi
  else
    echo ""
  fi
}

# Configure / Edit API Key
configure_api_key() {
  echo ""
  echo -e "${BOLD}${CYAN}------------------------------------------------------------${NC}"
  echo -e "${BOLD}${CYAN}          Set / Edit DeepSeek API Key                       ${NC}"
  echo -e "${BOLD}${CYAN}------------------------------------------------------------${NC}"
  local current_masked
  current_masked="$(get_masked_key)"
  if [ -n "$current_masked" ]; then
    echo -e "Current API Key: ${GREEN}[Configured: $current_masked]${NC}"
  else
    echo -e "Current API Key: ${YELLOW}[Not Set]${NC}"
  fi
  echo ""
  read -r -p "Enter DeepSeek API Key (press Enter to cancel): " input_key
  if [ -n "$input_key" ]; then
    # Trim input
    input_key="$(echo "$input_key" | xargs)"
    # Update or create .env file
    if [ -f "$REPO_DIR/.env" ]; then
      grep -v "^DEEPSEEK_API_KEY=" "$REPO_DIR/.env" > "$REPO_DIR/.env.tmp" 2>/dev/null || true
      mv "$REPO_DIR/.env.tmp" "$REPO_DIR/.env"
    fi
    echo "DEEPSEEK_API_KEY=\"$input_key\"" >> "$REPO_DIR/.env"
    export DEEPSEEK_API_KEY="$input_key"
    echo -e "${GREEN}[✓] API Key saved to $REPO_DIR/.env!${NC}"
  else
    echo "No API key change made."
  fi

  echo ""
  read -r -p "Configure custom API Base URL? [y/N]: " ask_url
  if [[ "$ask_url" =~ ^[Yy]$ ]]; then
    read -r -p "Enter Base URL (e.g. https://api.deepseek.com): " input_url
    if [ -n "$input_url" ]; then
      input_url="$(echo "$input_url" | xargs)"
      if [ -f "$REPO_DIR/.env" ]; then
        grep -v "^DEEPSEEK_BASE_URL=" "$REPO_DIR/.env" > "$REPO_DIR/.env.tmp" 2>/dev/null || true
        mv "$REPO_DIR/.env.tmp" "$REPO_DIR/.env"
      fi
      echo "DEEPSEEK_BASE_URL=\"$input_url\"" >> "$REPO_DIR/.env"
      export DEEPSEEK_BASE_URL="$input_url"
      echo -e "${GREEN}[✓] Base URL saved to $REPO_DIR/.env!${NC}"
    fi
  fi
  echo ""
}

# Check API key notice
check_api_key() {
  if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
    echo -e "${YELLOW}[!] Notice: DEEPSEEK_API_KEY is not set.${NC}"
    echo -e "    You can set it directly from the menu (option 4)"
    echo -e "    or add it to ${BOLD}$REPO_DIR/.env${NC}"
    echo ""
  fi
}

MODE="${1:-}"
shift 1 2>/dev/null || true

case "$MODE" in
  api|key|set-api)
    configure_api_key
    exit 0
    ;;
  web|start|"")
    if [ -z "$MODE" ] && [ -t 0 ]; then
      while true; do
        # Reload .env if updated
        if [ -f "$REPO_DIR/.env" ]; then
          set -a
          # shellcheck disable=SC1091
          source "$REPO_DIR/.env" 2>/dev/null || true
          set +a
        fi

        echo -e "${BOLD}${BLUE}============================================================${NC}"
        echo -e "${BOLD}${BLUE}       DeepSeek Harness - Termux Control Panel              ${NC}"
        echo -e "${BOLD}${BLUE}============================================================${NC}"
        key_display="$(get_masked_key)"
        if [ -n "$key_display" ]; then
          echo -e "  API Key Status: ${GREEN}[✓ Configured: $key_display]${NC}"
        else
          echo -e "  API Key Status: ${RED}[✗ Not Set - Choose option 4 to configure]${NC}"
        fi
        echo ""
        echo -e "  ${BOLD}1)${NC} Start Web UI (Browser: http://localhost:3080)"
        echo -e "  ${BOLD}2)${NC} Start Web UI (Dev Mode / Watchers)"
        echo -e "  ${BOLD}3)${NC} Run Headless CLI Task"
        echo -e "  ${BOLD}4)${NC} Set / Edit DeepSeek API Key"
        echo -e "  ${BOLD}5)${NC} Open Ubuntu Terminal Shell"
        echo -e "  ${BOLD}6)${NC} Re-run Dependency Install (pnpm install)"
        echo -e "  ${BOLD}7)${NC} Exit"
        echo ""
        read -r -p "Select option [1-7, default: 1]: " choice
        choice="${choice:-1}"
        case "$choice" in
          1) MODE="web"; break ;;
          2) MODE="dev"; break ;;
          3)
            read -r -p "Enter prompt/task: " task_prompt
            MODE="cli"
            set -- "$task_prompt"
            break
            ;;
          4)
            configure_api_key
            ;;
          5) MODE="shell"; break ;;
          6) MODE="install"; break ;;
          7) echo "Exiting."; exit 0 ;;
          *) echo "Invalid option." ;;
        esac
      done
    fi
    ;;
esac

case "$MODE" in
  web)
    check_api_key
    echo -e "${BOLD}${GREEN}============================================================${NC}"
    echo -e "${BOLD}${GREEN}  DeepSeek Harness Web Server Starting...                   ${NC}"
    echo -e "${BOLD}${GREEN}============================================================${NC}"
    echo ""
    echo -e "  Open your Android browser (Chrome/Brave/Firefox) to:"
    echo -e "  👉 ${BOLD}${CYAN}http://localhost:3080${NC}  or  ${BOLD}${CYAN}http://127.0.0.1:3080${NC}"
    echo ""
    echo -e "  Press ${BOLD}Ctrl+C${NC} anytime to stop the server."
    echo ""
    if command -v termux-open-url >/dev/null 2>&1; then
      # Open browser after a short delay in background
      (sleep 3 && termux-open-url "http://localhost:3080" 2>/dev/null) &
    fi
    run_in_proot "pnpm dsh web --no-open"
    ;;

  dev)
    check_api_key
    echo -e "${BOLD}${GREEN}Starting Web UI in development mode...${NC}"
    echo -e "Access at: ${BOLD}${CYAN}http://localhost:3080${NC}"
    run_in_proot "pnpm run dev:web"
    ;;

  cli)
    check_api_key
    TASK="$*"
    if [ -z "$TASK" ]; then
      read -r -p "Enter task for DeepSeek Harness: " TASK
    fi
    echo -e "${BOLD}[*] Running task: ${CYAN}$TASK${NC}"
    run_in_proot "pnpm dsh --profile headless \"$TASK\""
    ;;

  shell)
    echo -e "${BOLD}[*] Launching interactive shell inside Ubuntu proot (/workspace)...${NC}"
    echo -e "    Type 'exit' to return to Termux."
    proot-distro login "$DISTRO" --termux-home --bind "$REPO_DIR":/workspace -- /bin/bash -c "cd /workspace && exec /bin/bash"
    ;;

  install)
    echo -e "${BOLD}[*] Updating dependencies via pnpm...${NC}"
    run_in_proot "pnpm install"
    ;;

  build)
    echo -e "${BOLD}[*] Building project via pnpm...${NC}"
    run_in_proot "pnpm run build"
    ;;

  *)
    echo "Usage: $0 [web|dev|cli <prompt>|shell|install|build]"
    exit 1
    ;;
esac
