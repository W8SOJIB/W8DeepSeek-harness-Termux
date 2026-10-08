#!/usr/bin/env bash
# ==============================================================================
# DeepSeek Harness - Termux 1-Click Installer
# ==============================================================================
# Automatically detects if proot-distro and Ubuntu are already installed.
# If already installed, reuses them and skips redundant downloads/installs.
# Sets up Node.js (>=22 LTS), pnpm, and all dependencies in a glibc environment.
# ==============================================================================

set -e

# ANSI color codes
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BOLD}${BLUE}============================================================${NC}"
echo -e "${BOLD}${BLUE}       DeepSeek Harness - Termux 1-Click Installer          ${NC}"
echo -e "${BOLD}${BLUE}============================================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# 1. Environment Detection (Termux Check)
# ------------------------------------------------------------------------------
IS_TERMUX=0
if [ -n "$TERMUX_VERSION" ] || [ -d "/data/data/com.termux" ] || [[ "${PREFIX:-}" == *"com.termux"* ]]; then
  IS_TERMUX=1
fi

if [ "$IS_TERMUX" -eq 0 ]; then
  echo -e "${YELLOW}[!] Notice: You are not running inside Android Termux.${NC}"
  echo -e "    This installer is tailored for Termux (Android) using proot-distro."
  echo -e "    For regular Linux/macOS/Windows, follow the standard quickstart:"
  echo -e "      pnpm install && pnpm run build && pnpm dsh web"
  echo ""
  read -r -p "Do you still want to continue with Termux-style proot setup? [y/N] " proceed
  if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
    echo "Exiting installer."
    exit 0
  fi
fi

# ------------------------------------------------------------------------------
# 2. Determine Repository Root Directory
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"

if [ -f "$SCRIPT_DIR/package.json" ] && grep -q "@deepseek-ai/dsh" "$SCRIPT_DIR/package.json" 2>/dev/null; then
  REPO_DIR="$SCRIPT_DIR"
elif [ -f "$(pwd)/package.json" ] && grep -q "@deepseek-ai/dsh" "$(pwd)/package.json" 2>/dev/null; then
  REPO_DIR="$(pwd)"
elif [ -d "$HOME/W8DeepSeek-harness-Termux" ] && [ -f "$HOME/W8DeepSeek-harness-Termux/package.json" ]; then
  REPO_DIR="$HOME/W8DeepSeek-harness-Termux"
elif [ -d "$HOME/deepseek-harness" ] && [ -f "$HOME/deepseek-harness/package.json" ]; then
  REPO_DIR="$HOME/deepseek-harness"
else
  REPO_DIR="$HOME/W8DeepSeek-harness-Termux"
fi

# Storage safety check: Warn against /sdcard or /storage/emulated/0
if [[ "$REPO_DIR" == *"/sdcard"* ]] || [[ "$REPO_DIR" == *"/storage/emulated"* ]]; then
  echo -e "${RED}[!] WARNING: You are running in Android shared storage ($REPO_DIR).${NC}"
  echo -e "    Android's /sdcard does NOT support Linux symlinks or permissions,"
  echo -e "    which will cause Node.js and pnpm installation to FAIL."
  echo -e "    Switching repository location to Termux private home directory: $HOME/W8DeepSeek-harness-Termux"
  REPO_DIR="$HOME/W8DeepSeek-harness-Termux"
fi

# ------------------------------------------------------------------------------
# 3. Check / Install proot-distro on Termux
# ------------------------------------------------------------------------------
echo -e "${BOLD}[1/4] Checking proot-distro on Termux...${NC}"

if command -v proot-distro >/dev/null 2>&1; then
  echo -e "${GREEN}[✓] proot-distro is ALREADY installed on Termux.${NC}"
  echo -e "    (Skipping download and package installation)"
else
  echo -e "${YELLOW}[→] proot-distro not found. Installing proot-distro via pkg...${NC}"
  pkg update -y || true
  pkg install -y proot-distro curl git || apt-get install -y proot-distro curl git
  echo -e "${GREEN}[✓] proot-distro installed successfully.${NC}"
fi

# ------------------------------------------------------------------------------
# 4. Check / Install Linux Distribution (Ubuntu) in proot-distro
# ------------------------------------------------------------------------------
echo ""
DISTRO="ubuntu"
TERMUX_PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"

echo -e "${BOLD}[2/4] Checking proot-distro distribution ('$DISTRO')...${NC}"

DISTRO_ALREADY_INSTALLED=0

# Check 1: Direct test using proot-distro login
if proot-distro login "$DISTRO" -- true 2>/dev/null; then
  DISTRO_ALREADY_INSTALLED=1
# Check 2: Check proot-distro list output (case-insensitive)
elif proot-distro list 2>/dev/null | grep -i "$DISTRO" | grep -qi "installed"; then
  DISTRO_ALREADY_INSTALLED=1
# Check 3: Check filesystem rootfs directories
else
  for test_dir in \
    "$TERMUX_PREFIX/var/lib/proot-distro/installed-rootfs/$DISTRO" \
    "/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/$DISTRO" \
    "$HOME/../usr/var/lib/proot-distro/installed-rootfs/$DISTRO"; do
    if [ -d "$test_dir" ]; then
      DISTRO_ALREADY_INSTALLED=1
      break
    fi
  done
fi

if [ "$DISTRO_ALREADY_INSTALLED" -eq 1 ]; then
  echo -e "${GREEN}[✓] '$DISTRO' container is ALREADY installed in proot-distro.${NC}"
  echo -e "    Auto-working with existing Ubuntu container! Skipping download."
else
  echo -e "${YELLOW}[→] Container '$DISTRO' not detected. Running proot-distro install...${NC}"
  INSTALL_OUT=$(proot-distro install "$DISTRO" 2>&1 || true)
  if echo "$INSTALL_OUT" | grep -qi "already exists"; then
    echo -e "${GREEN}[✓] '$DISTRO' container already exists! Reusing existing installation.${NC}"
  elif proot-distro login "$DISTRO" -- true 2>/dev/null; then
    echo -e "${GREEN}[✓] '$DISTRO' rootfs installed successfully.${NC}"
  else
    echo "$INSTALL_OUT"
    echo -e "${RED}[!] Error: Could not verify '$DISTRO' container in proot-distro.${NC}"
    exit 1
  fi
fi

# ------------------------------------------------------------------------------
# 5. Check Repository Source Files
# ------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[3/4] Checking DeepSeek Harness files...${NC}"

if [ ! -d "$REPO_DIR" ]; then
  echo -e "${YELLOW}[→] Cloning repository into $REPO_DIR...${NC}"
  git clone https://github.com/W8SOJIB/W8DeepSeek-harness-Termux.git "$REPO_DIR" || \
    git clone https://github.com/deepseek-ai/deepseek-harness.git "$REPO_DIR"
  echo -e "${GREEN}[✓] Repository cloned to $REPO_DIR${NC}"
else
  echo -e "${GREEN}[✓] Repository directory ready: $REPO_DIR${NC}"
fi

# ------------------------------------------------------------------------------
# 6. Configure Node.js (>=22), pnpm, and dependencies inside Ubuntu
# ------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}[4/4] Setting up Node.js 22 LTS, pnpm, and dependencies inside $DISTRO...${NC}"

# Execute configuration script directly inside proot-distro Ubuntu
proot-distro login "$DISTRO" --termux-home --bind "$REPO_DIR":/workspace -- /bin/bash -s << 'EOF'
set -e
export DEBIAN_FRONTEND=noninteractive

# 1. System packages
echo "  [*] Checking system utilities..."
MISSING_PKGS=""
for pkg in curl git build-essential python3 ca-certificates; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    MISSING_PKGS="$MISSING_PKGS $pkg"
  fi
done

if [ -n "$MISSING_PKGS" ]; then
  echo "  [+] Installing missing packages:$MISSING_PKGS..."
  apt-get update -y >/dev/null
  apt-get install -y $MISSING_PKGS >/dev/null
  echo "  [✓] System utilities installed."
else
  echo "  [✓] System utilities already installed."
fi

# 2. Node.js (require Node.js >= 22)
echo "  [*] Checking Node.js runtime..."
NODE_OK=0
if command -v node >/dev/null 2>&1; then
  NODE_VER=$(node -v | sed 's/v//')
  NODE_MAJOR=$(echo "$NODE_VER" | cut -d. -f1)
  if [ "$NODE_MAJOR" -ge 22 ]; then
    NODE_OK=1
    echo "  [✓] Node.js v$NODE_VER is already installed. (Skipping Node.js installation)"
  else
    echo "  [-] Installed Node.js (v$NODE_VER) is older than v22."
  fi
fi

if [ "$NODE_OK" -eq 0 ]; then
  echo "  [+] Installing Node.js 22 LTS via NodeSource..."
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash - >/dev/null
  apt-get install -y nodejs >/dev/null
  echo "  [✓] Node.js $(node -v) installed successfully."
fi

# 3. pnpm
echo "  [*] Checking pnpm..."
if command -v pnpm >/dev/null 2>&1; then
  echo "  [✓] pnpm $(pnpm -v) is already installed. (Skipping pnpm installation)"
else
  echo "  [+] Installing pnpm..."
  npm install -g pnpm@11.7.0 >/dev/null 2>&1 || npm install -g pnpm >/dev/null
  echo "  [✓] pnpm $(pnpm -v) installed successfully."
fi

# 4. Project dependencies
cd /workspace
echo "  [*] Checking project dependencies in workspace..."
if [ -d "/workspace/node_modules" ]; then
  echo "  [✓] node_modules directory already exists. Skipping full re-installation."
else
  echo "  [+] Installing project dependencies via pnpm (this may take a few minutes)..."
  pnpm install
  echo "  [✓] Dependencies installed successfully."
fi

EOF

# ------------------------------------------------------------------------------
# 7. Create Global Launcher in Termux ($PREFIX/bin/dsh-termux)
# ------------------------------------------------------------------------------
START_SCRIPT="$REPO_DIR/start-termux.sh"

if [ -f "$START_SCRIPT" ]; then
  chmod +x "$START_SCRIPT"
fi

if [ -d "$TERMUX_PREFIX/bin" ] && [ -w "$TERMUX_PREFIX/bin" ]; then
  cat > "$TERMUX_PREFIX/bin/dsh-termux" << LAUNCHER_EOF
#!/usr/bin/env bash
exec "$START_SCRIPT" "\$@"
LAUNCHER_EOF
  chmod +x "$TERMUX_PREFIX/bin/dsh-termux"
  GLOBAL_CMD_INSTALLED=1
else
  GLOBAL_CMD_INSTALLED=0
fi

echo ""
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo -e "${BOLD}${GREEN}        Installation & Setup Completed Successfully!        ${NC}"
echo -e "${BOLD}${GREEN}============================================================${NC}"
echo ""
echo -e "You can start DeepSeek Harness anytime with:"
echo ""
if [ "$GLOBAL_CMD_INSTALLED" -eq 1 ]; then
  echo -e "  ${BOLD}${BLUE}dsh-termux${NC}        (Interactive menu from anywhere)"
  echo -e "  ${BOLD}${BLUE}dsh-termux web${NC}    (Start Web UI at http://localhost:3080)"
  echo -e "  ${BOLD}${BLUE}dsh-termux cli \"task\"${NC} (Run headless CLI task)"
fi
echo -e "  ${BOLD}${YELLOW}bash $START_SCRIPT${NC} (Direct launcher script)"
echo ""
echo -e "Tip: Set your DeepSeek API key in Termux before running:"
echo -e "  ${BOLD}export DEEPSEEK_API_KEY=\"your_key_here\"${NC}"
echo ""
read -r -p "Would you like to start DeepSeek Harness Web UI now? [Y/n] " launch_now
if [[ ! "$launch_now" =~ ^[Nn]$ ]]; then
  exec "$START_SCRIPT" web
fi
