#!/bin/bash
set -e

echo "========================================================="
echo "CODEX PROXY - AUTOMATED INSTALLER FOR UBUNTU/LINUX"
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
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "Chua tim thay Node.js hoac NPM. Dang cai dat Node.js v20..."
    if ! command -v curl &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y curl
    fi
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi
NODE_PATH=$(which node)

echo "Cai dat bubblewrap (can cho sandbox)..."
sudo apt-get install -y bubblewrap || echo "Khong cai duoc bubblewrap, tiep tuc..."

echo "Dang xoa cau hinh Codex cu (neu co)..."
rm -rf "$HOME/.codex"

echo "Dang cai dat Codex CLI..."
sudo npm install -g @openai/codex

# 3. Setup Proxy Script
PROXY_DIR="/home/$USER/codex-proxy"
mkdir -p "$PROXY_DIR"

if [ ! -f "./proxy/codex_proxy.js" ]; then
    echo "LOI: Khong tim thay file proxy/codex_proxy.js trong bo cai!"
    exit 1
fi

cp "./proxy/codex_proxy.js" "$PROXY_DIR/codex_proxy.js"
sed -i "s/YOUR_API_KEY_HERE/$API_KEY/g" "$PROXY_DIR/codex_proxy.js"
echo "Da cai dat ma nguon Proxy vao $PROXY_DIR"

# 4. Setup Codex Configs
CODEX_DIR="/home/$USER/.codex"
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

[projects.'/home/$USER']
trust_level = "trusted"

[linux]
sandbox = "unelevated"
EOF

cat > "$CODEX_DIR/auth.json" << EOF
{
  "OPENAI_API_KEY": "$API_KEY"
}
EOF
echo "Da cau hinh config Codex CLI."

# 5. Setup Systemd Auto-start
echo "Thiet lap chay ngam voi systemd..."
sudo tee /etc/systemd/system/codex-proxy.service > /dev/null << EOF
[Unit]
Description=Codex Proxy API v3
After=network.target

[Service]
ExecStart=$NODE_PATH /home/$USER/codex-proxy/codex_proxy.js
Restart=always
RestartSec=3
User=$USER
Environment=PATH=/usr/bin:/usr/local/bin
WorkingDirectory=/home/$USER/codex-proxy
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable codex-proxy
sudo systemctl start codex-proxy

echo "Dang khoi dong Proxy..."
sleep 3

# 6. Test Proxy
if curl -s http://127.0.0.1:20129/v1/models | grep -q "object"; then
    echo "CAI DAT THANH CONG! Proxy dang hoat dong ngam (systemd)."
    echo "Mo Terminal moi va go 'codex' de bat dau su dung."
else
    echo "Da cai dat nhung Proxy bao loi. Dung 'sudo journalctl -u codex-proxy -f' de xem loi."
fi
