# =========================================================
# CODEX PROXY - AUTOMATED INSTALLER FOR WINDOWS
# =========================================================

# Check Admin Privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-Not $isAdmin) {
    Write-Host "Vui long chay file install-windows.bat de duoc cap quyen Admin." -ForegroundColor Red
    Pause
    exit
}

Write-Host "Dang bat dau cai dat Codex Proxy..." -ForegroundColor Cyan

# 1. Prompt for API Key
$API_KEY = Read-Host "Nhap API_KEY cua ban (Dinh dang sk-xxxx...)"
if ([string]::IsNullOrWhiteSpace($API_KEY)) {
    Write-Host "API_KEY khong duoc de trong!" -ForegroundColor Red
    Pause
    exit
}

# 2. Check and Install Node.js
try {
    $nodeVersion = node -v
    Write-Host "Node.js da duoc cai dat: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "Chua tim thay Node.js! Dang tai va cai dat Node.js..." -ForegroundColor Yellow
    # Download and install Node.js via winget if available
    winget install OpenJS.NodeJS -e --silent
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

# 3. Install Codex CLI
Write-Host "Dang xoa cau hinh Codex cu (neu co)..." -ForegroundColor Yellow
if (Test-Path -Path "$env:USERPROFILE\.codex") {
    Remove-Item -Recurse -Force "$env:USERPROFILE\.codex" -ErrorAction SilentlyContinue
}

Write-Host "Dang cai dat Codex CLI..." -ForegroundColor Yellow
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
    Write-Host "KHONG TIM THAY file proxy\codex_proxy.js trong bo cai!" -ForegroundColor Red
    Pause
    exit
}

# Replace API KEY in proxy script
$utf8NoBom = New-Object System.Text.UTF8Encoding($False)
$proxyContent = Get-Content -Path $destProxy -Raw -Encoding UTF8
$proxyContent = $proxyContent -replace 'YOUR_API_KEY_HERE', $API_KEY
[System.IO.File]::WriteAllText($destProxy, $proxyContent, $utf8NoBom)
Write-Host "Da copy source code Proxy vao $proxyDir" -ForegroundColor Green

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
[System.IO.File]::WriteAllText("$codexDir\config.toml", $configContent, $utf8NoBom)

$authContent = @"
{
  "OPENAI_API_KEY": "$API_KEY"
}
"@
[System.IO.File]::WriteAllText("$codexDir\auth.json", $authContent, $utf8NoBom)
Write-Host "Da ghi cau hinh Codex CLI thanh cong." -ForegroundColor Green

# 6. Setup Auto-start (VBS Script in Startup folder)
$startupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$vbsPath = "$startupFolder\StartCodexProxy.vbs"

$vbsContent = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run """node"" ""$destProxy""", 0, False
"@
$asciiEncoding = New-Object System.Text.ASCIIEncoding
[System.IO.File]::WriteAllText($vbsPath, $vbsContent, $asciiEncoding)
Write-Host "Da thiet lap tu dong khoi dong Proxy ngam vao thu muc Startup." -ForegroundColor Green

# 7. Start Proxy now
Write-Host "Dang khoi dong Proxy lan dau..." -ForegroundColor Yellow
Start-Process -FilePath "wscript.exe" -ArgumentList "`"$vbsPath`"" -WindowStyle Hidden

Start-Sleep -Seconds 3

# Test Proxy
try {
    $response = Invoke-WebRequest -Uri "http://127.0.0.1:20129/v1/models" -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        Write-Host "CAI DAT THANH CONG! Proxy dang hoat dong." -ForegroundColor Green
        Write-Host "Mo terminal moi va go 'codex' de bat dau su dung." -ForegroundColor Cyan
    }
} catch {
    Write-Host "Cai dat co ve thanh cong nhung khong the test duoc Proxy. Vui long khoi dong lai may tinh va thu go 'codex'." -ForegroundColor Yellow
}

Write-Host "Nhan phim bat ky de thoat..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
