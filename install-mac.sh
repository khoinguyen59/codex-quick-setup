#!/bin/bash
set -e

echo "========================================================="
echo "CODEX PROXY - AUTOMATED INSTALLER FOR MACOS"
echo "========================================================="

# 1. Prompt for API Key
read -p "Nhap API_KEY cua ban (Dinh dang sk-xxxx...): " API_KEY
if [ -z "$API_KEY" ]; then
    echo "API_KEY khong duoc de trong!"
    exit 1
fi

USER=$(whoami)

# 2. Install Node.js & Codex CLI
echo "Dang kiem tra Node.js..."
if ! command -v node &> /dev/null; then
    echo "Chua tim thay Node.js. Vui long cai dat Node.js truoc (VD: 'brew install node')."
    exit 1
fi
NODE_PATH=$(which node)

echo "Dang xoa cau hinh Codex cu (neu co)..."
rm -rf "$HOME/.codex"

echo "Dang cai dat Codex CLI..."
sudo npm install -g @openai/codex || npm install -g @openai/codex

# 3. Setup Proxy Script
PROXY_DIR="$HOME/codex-proxy"
mkdir -p "$PROXY_DIR"

if [ ! -f "./proxy/codex_proxy.js" ]; then
    echo "LOI: Khong tim thay file proxy/codex_proxy.js trong bo cai!"
    exit 1
fi

cp "./proxy/codex_proxy.js" "$PROXY_DIR/codex_proxy.js"
sed -i '' "s/YOUR_API_KEY_HERE/$API_KEY/g" "$PROXY_DIR/codex_proxy.js"
echo "Da cai dat ma nguon Proxy vao $PROXY_DIR"

# 4. Setup Codex Configs
CODEX_DIR="$HOME/.codex"
mkdir -p "$CODEX_DIR"

cat > "$CODEX_DIR/config.toml" << EOF
model = "gpt-5.5"
model_provider = "codexapi"
model_reasoning_effort = "medium"

[model_providers.codexapi]
name = "CodexAPI"
base_url = "http://127.0.0.1:20129/v1"
wire_api = "responses"
api_key_env_var = "OPENAI_API_KEY"

[projects.'/Users/$USER']
trust_level = "trusted"

[macos]
sandbox = "none"
EOF

cat > "$CODEX_DIR/auth.json" << EOF
{
  "OPENAI_API_KEY": "$API_KEY"
}
EOF
echo "Da cau hinh config Codex CLI."

# 5. Setup Launchd Auto-start
echo "Thiet lap chay ngam voi Launchd..."
mkdir -p ~/Library/LaunchAgents
PLIST_PATH="$HOME/Library/LaunchAgents/com.user.codexproxy.plist"

cat > "$PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.codexproxy</string>
    <key>ProgramArguments</key>
    <array>
        <string>$NODE_PATH</string>
        <string>/Users/$USER/codex-proxy/codex_proxy.js</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/$USER/codex-proxy/proxy.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/$USER/codex-proxy/proxy_error.log</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "Dang khoi dong Proxy..."
sleep 3

# 6. Test Proxy
if curl -s http://127.0.0.1:20129/v1/models | grep -q "object"; then
    echo "CAI DAT THANH CONG! Proxy dang hoat dong ngam."
    echo "Mo Terminal moi va go 'codex' de bat dau su dung."
else
    echo "Da cai dat nhung Proxy chua chay. Ban co the tu mo terminal go: node ~/codex-proxy/codex_proxy.js"
fi
