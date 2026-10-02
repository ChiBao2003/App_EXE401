# ============================================================
# start_dev.ps1 - Khởi động nhanh môi trường dev EXE401
# Chạy: .\start_dev.ps1 trong PowerShell
# ============================================================

$adbPath = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
$phoneIp = "192.168.1.14"
$phonePort = "43431"   # <- Cập nhật port debug từ Wireless Debugging

Write-Host "Khoi dong EXE401 Dev Environment..." -ForegroundColor Cyan

# --- Backend ---
Write-Host "[1/3] Khoi dong Backend FastAPI..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList '-NoExit', '-Command', @"
  cd 'c:\EXE401_WEDAPP_PROJECT_REPORT\App_EXE401\Backend_EXE401'
  .\venv\Scripts\Activate.ps1
  uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"@

Start-Sleep 2

# --- ADB Connect ---
Write-Host "[2/3] Ket noi ADB Wireless..." -ForegroundColor Yellow
& $adbPath connect "${phoneIp}:${phonePort}"
$devices = & $adbPath devices
if ($devices -match $phoneIp) {
    Write-Host "Dien thoai da ket noi!" -ForegroundColor Green
    # --- Flutter ---
    Write-Host "[3/3] Chay Flutter App..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList '-NoExit', '-Command', @"
      cd 'c:\EXE401_WEDAPP_PROJECT_REPORT\App_EXE401\Frontend_EXE401'
      flutter run -d ${phoneIp}:${phonePort}
"@
} else {
    Write-Host "Khong thay dien thoai. Bat Wireless Debugging truoc." -ForegroundColor Red
}
Write-Host "Mo http://localhost:8000/docs de test API." -ForegroundColor Green
