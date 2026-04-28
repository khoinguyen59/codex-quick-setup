#!/bin/bash
set -e

echo "========================================================="
echo "CODEX PROXY - AUTOMATED INSTALLER FOR UBUNTU/LINUX"
echo "========================================================="

# 1. Prompt for API Key
read -p "Nhập API_KEY của bạn (Định dạng sk-xxxx...): " API_KEY
if [ -z "$API_KEY" ]; then
    echo "API_KEY không được để trống!"
    exit 1
fi

USER=$(whoami)

# 2. Install Node.js & Codex CLI
echo "Đang kiểm tra Node.js..."
if ! command -v node &> /dev/null; then
    echo "Chưa tìm thấy Node.js. Đang cài đặt Node.js v20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi
NODE_PATH=$(which node)

echo "Cài đặt bubblewrap (cần cho sandbox)..."
sudo apt-get install -y bubblewrap || echo "Không cài được bubblewrap, tiếp tục..."

echo "Đang cài đặt Codex CLI..."
sudo npm install -g @openai/codex

# 3. Setup Proxy Script
PROXY_DIR="/home/$USER/codex-proxy"
mkdir -p "$PROXY_DIR"

if [ ! -f "./proxy/codex_proxy.js" ]; then
    echo "LỖI: Không tìm thấy file proxy/codex_proxy.js trong bộ cài!"
    exit 1
fi

cp "./proxy/codex_proxy.js" "$PROXY_DIR/codex_proxy.js"
sed -i "s/<API_KEY_CỦA_BẠN>/$API_KEY/g" "$PROXY_DIR/codex_proxy.js"
echo "Đã cài đặt mã nguồn Proxy vào $PROXY_DIR"

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
echo "Đã cấu hình config Codex CLI."

# 5. Setup Systemd Auto-start
echo "Thiết lập chạy ngầm với systemd..."
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

echo "Đang khởi động Proxy..."
sleep 3

# 6. Test Proxy
if curl -s http://127.0.0.1:20129/v1/models | grep -q "object"; then
    echo "✅ CÀI ĐẶT THÀNH CÔNG! Proxy đang hoạt động ngầm (systemd)."
    echo "Mở Terminal mới và gõ 'codex' để bắt đầu sử dụng."
else
    echo "⚠️ Đã cài đặt nhưng Proxy báo lỗi. Dùng 'sudo journalctl -u codex-proxy -f' để xem lỗi."
fi
