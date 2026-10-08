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
  proot-distro login "$DISTRO" \
    --termux-home \
    --bind "$REPO_DIR":/workspace \
    -- /bin/bash -c "
      export DEEPSEEK_API_KEY=\"${DEEPSEEK_API_KEY:-}\"
      export DEEPSEEK_BASE_URL=\"${DEEPSEEK_BASE_URL:-}\"
      cd /workspace
      $*
    "
}

# Check API key notice
check_api_key() {
  if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
    echo -e "${YELLOW}[!] Notice: DEEPSEEK_API_KEY is not set in environment or .env file.${NC}"
    echo -e "    You can set it with: ${BOLD}export DEEPSEEK_API_KEY=\"sk-...\"${NC}"
    echo -e "    or add it to ${BOLD}$REPO_DIR/.env${NC}"
    echo ""
  fi
}

MODE="${1:-}"
shift 1 2>/dev/null || true

case "$MODE" in
  web|start|"")
    if [ -z "$MODE" ] && [ -t 0 ]; then
      # Interactive mode menu
      echo -e "${BOLD}${BLUE}============================================================${NC}"
      echo -e "${BOLD}${BLUE}       DeepSeek Harness - Termux Control Panel              ${NC}"
      echo -e "${BOLD}${BLUE}============================================================${NC}"
      echo ""
      echo -e "  ${BOLD}1)${NC} Start Web UI (Browser: http://localhost:3080)"
      echo -e "  ${BOLD}2)${NC} Start Web UI (Dev Mode / Watchers)"
      echo -e "  ${BOLD}3)${NC} Run Headless CLI Task"
      echo -e "  ${BOLD}4)${NC} Open Ubuntu Terminal Shell"
      echo -e "  ${BOLD}5)${NC} Re-run Dependency Install (pnpm install)"
      echo -e "  ${BOLD}6)${NC} Exit"
      echo ""
      read -r -p "Select option [1-6, default: 1]: " choice
      choice="${choice:-1}"
      case "$choice" in
        1) MODE="web" ;;
        2) MODE="dev" ;;
        3)
          read -r -p "Enter prompt/task: " task_prompt
          MODE="cli"
          set -- "$task_prompt"
          ;;
        4) MODE="shell" ;;
        5) MODE="install" ;;
        6) echo "Exiting."; exit 0 ;;
        *) echo "Invalid option."; exit 1 ;;
      esac
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
