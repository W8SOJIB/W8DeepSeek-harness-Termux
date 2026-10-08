# DeepSeek Harness on Android (Termux)

This guide explains how to install and run **DeepSeek Harness** on Android using [Termux](https://termux.dev) and `proot-distro`.

---

## ⚡ 1-Click Install

Open Termux and run the following command:

### Option A: If you already cloned the repository
```bash
cd W8DeepSeek-harness-Termux
bash install-termux.sh
```

### Option B: Quick 1-command setup from Termux home
```bash
pkg install -y git && git clone https://github.com/W8SOJIB/W8DeepSeek-harness-Termux.git && cd W8DeepSeek-harness-Termux && bash install-termux.sh
```

### Option C: Direct 1-line curl execution
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/W8SOJIB/W8DeepSeek-harness-Termux/main/install-termux.sh)
```

---

## 🔍 How the 1-Click Installer Works

The script [install-termux.sh](install-termux.sh) is designed to be **smart, fast, and idempotent**:

1. **Checks `proot-distro`**:
   - If `proot-distro` is **already installed** on Termux, it skips download/installation.
   - If missing, it installs `proot-distro`, `curl`, and `git` via `pkg`.
2. **Checks Ubuntu rootfs**:
   - If Ubuntu is **already installed** in `proot-distro`, it **automatically reuses it** without downloading rootfs again.
   - If missing, it downloads and initializes Ubuntu once.
3. **Checks Node.js (>=22) & pnpm**:
   - Checks if Node.js `>= 22` is present in the container; skips installation if satisfied.
   - Checks if `pnpm` is present; skips if already installed.
4. **Checks project dependencies**:
   - If `node_modules` is already present, it skips full package download and proceeds immediately.
5. **Creates a global launcher**:
   - Installs `dsh-termux` to Termux's `$PREFIX/bin`, allowing you to run DeepSeek Harness from anywhere.

---

## 🚀 Running DeepSeek Harness

Once installed, you can start DeepSeek Harness anytime with:

### 1. Interactive Control Panel
```bash
dsh-termux
```
Or:
```bash
./start-termux.sh
```

This presents a menu to choose between:
- Starting the Web UI
- Starting Web UI in Development mode (with live reload)
- Running a headless CLI task
- Opening an interactive Ubuntu shell
- Updating dependencies

### 2. Start Web UI directly
```bash
dsh-termux web
```
Then open your Android browser (Chrome, Brave, Firefox, etc.) and navigate to:
```
http://localhost:3080
```
*(or `http://127.0.0.1:3080`)*

### 3. Run a Headless CLI Task
```bash
dsh-termux cli "Analyze the repository structure and list key packages"
```

### 4. Open Linux Terminal Shell
```bash
dsh-termux shell
```

---

## 🔑 Setting your DeepSeek API Key

Before running tasks, export your API key in Termux:
```bash
export DEEPSEEK_API_KEY="sk-your-deepseek-api-key"
```

Or create a `.env` file in the repository root:
```bash
echo "DEEPSEEK_API_KEY=sk-your-deepseek-api-key" >> .env
```
The launcher automatically loads `.env` upon startup.

---

## 💡 Important Android / Termux Tips

1. **Storage Location**:
   - **Do not** place the repository inside `/sdcard` or `/storage/emulated/0`. Android shared storage lacks support for Linux permissions and symlinks required by Node.js and `pnpm`.
   - Always keep the project in Termux's home directory (`$HOME` / `/data/data/com.termux/files/home`).
2. **Prevent Background Sleep (Wake Lock)**:
   - Termux provides `termux-wake-lock` to prevent Android from putting Termux to sleep during long-running tasks.
   - [start-termux.sh](start-termux.sh) automatically acquires a wake lock on launch and releases it when finished.
   - You can also enable "Acquire Wakelock" from the Termux notification drawer.
3. **Port Forwarding**:
   - Android shares the network stack with Termux and `proot-distro`. Any port bound to `localhost` inside proot (e.g. port 3080) is directly accessible in your Android web browser without needing port forwards or root.
