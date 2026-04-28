# =========================================================
# CODEX PROXY - AUTOMATED INSTALLER FOR WINDOWS
# =========================================================

# Check Admin Privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-Not $isAdmin) {
    Write-Host "Vui lòng chạy file install-windows.bat thay vì chạy trực tiếp file ps1 này (để được cấp quyền Admin)." -ForegroundColor Red
    Pause
    exit
}

Write-Host "Đang bắt đầu cài đặt Codex Proxy..." -ForegroundColor Cyan

# 1. Prompt for API Key
$API_KEY = Read-Host "Nhập API_KEY của bạn (Định dạng sk-xxxx...)"
if ([string]::IsNullOrWhiteSpace($API_KEY)) {
    Write-Host "API_KEY không được để trống!" -ForegroundColor Red
    Pause
    exit
}

# 2. Check and Install Node.js
try {
    $nodeVersion = node -v
    Write-Host "Node.js đã được cài đặt: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "Chưa tìm thấy Node.js! Đang tải và cài đặt Node.js..." -ForegroundColor Yellow
    # Download and install Node.js via winget if available
    winget install OpenJS.NodeJS -e --silent
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# 3. Install Codex CLI
Write-Host "Đang cài đặt Codex CLI..." -ForegroundColor Yellow
npm install -g @openai/codex

# 4. Setup Proxy Script
$proxyDir = "$env:USERPROFILE\codex-proxy"
if (-Not (Test-Path -Path $proxyDir)) {
    New-Item -ItemType Directory -Path $proxyDir | Out-Null
}

$sourceProxy = "$PSScriptRoot\proxy\codex_proxy.js"
$destProxy = "$proxyDir\codex_proxy.js"

if (Test-Path -Path $sourceProxy) {
    Copy-Item -Path $sourceProxy -Destination $destProxy -Force
} else {
    Write-Host "KHÔNG TÌM THẤY file proxy\codex_proxy.js trong bộ cài!" -ForegroundColor Red
    Pause
    exit
}

# Replace API KEY in proxy script
(Get-Content $destProxy) -replace '<API_KEY_CỦA_BẠN>', $API_KEY | Set-Content $destProxy
Write-Host "Đã cài đặt mã nguồn Proxy vào $proxyDir" -ForegroundColor Green

# 5. Setup Codex Configs
$codexDir = "$env:USERPROFILE\.codex"
if (-Not (Test-Path -Path $codexDir)) {
    New-Item -ItemType Directory -Path $codexDir | Out-Null
}

$configContent = @"
model = "gpt-5.5"
model_provider = "codexapi"
model_reasoning_effort = "medium"

[model_providers.codexapi]
name = "CodexAPI"
base_url = "http://127.0.0.1:20129/v1"
wire_api = "responses"
api_key_env_var = "OPENAI_API_KEY"

[projects.'$env:USERPROFILE']
trust_level = "trusted"

[windows]
sandbox = "unelevated"
"@
Set-Content -Path "$codexDir\config.toml" -Value $configContent -Encoding UTF8

$authContent = @"
{
  "OPENAI_API_KEY": "$API_KEY"
}
"@
Set-Content -Path "$codexDir\auth.json" -Value $authContent -Encoding UTF8
Write-Host "Đã ghi cấu hình Codex CLI thành công." -ForegroundColor Green

# 6. Setup Auto-start (VBS Script in Startup folder)
$startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$vbsPath = "$startupFolder\StartCodexProxy.vbs"

$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """node"" ""$destProxy""", 0, False
"@
Set-Content -Path $vbsPath -Value $vbsContent -Encoding UTF8
Write-Host "Đã thiết lập tự động khởi động Proxy ngầm vào thư mục Startup." -ForegroundColor Green

# 7. Start Proxy now
Write-Host "Đang khởi động Proxy lần đầu..." -ForegroundColor Yellow
Start-Process -FilePath "wscript.exe" -ArgumentList "`"$vbsPath`"" -WindowStyle Hidden

Start-Sleep -Seconds 3

# Test Proxy
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:20129/v1/models" -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "CÀI ĐẶT THÀNH CÔNG! Proxy đang hoạt động." -ForegroundColor Green
        Write-Host "Mở terminal mới và gõ 'codex' để bắt đầu sử dụng." -ForegroundColor Cyan
    }
} catch {
    Write-Host "Cài đặt có vẻ thành công nhưng không thể test được Proxy. Vui lòng khởi động lại máy tính và thử gõ 'codex'." -ForegroundColor Yellow
}

Write-Host "Nhấn phím bất kỳ để thoát..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
