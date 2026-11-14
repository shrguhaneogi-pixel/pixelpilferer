# Environment and Tooling Verification for Godot 4.7
# Usage: powershell -ExecutionPolicy Bypass -File verify_environment.ps1

Write-Host "=== Auditing Godot 4.7 Development Environment ===" -ForegroundColor Cyan

# 1. Check for Godot Executable
$candidates = @("godot", "godot4", "godot.exe", "godot4.exe")
$godotCmd = $null
foreach ($name in $candidates) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) {
        $godotCmd = $cmd
        break
    }
}

if ($godotCmd) {
    Write-Host "[OK] Found Godot binary: $($godotCmd.Source)" -ForegroundColor Green
    try {
        $version = & $godotCmd.Source --version
        Write-Host "[OK] Godot Version: $version" -ForegroundColor Green
    } catch {
        Write-Host "[WARN] Could not retrieve Godot version: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "[FAIL] Godot executable ('godot', 'godot4') is not found in PATH." -ForegroundColor Red
    Write-Host "       Please install Godot 4.7.2 and add the executable to your system PATH." -ForegroundColor Yellow
}

# 2. Check for Project File
if (Test-Path "project.godot") {
    Write-Host "[OK] Found project.godot in workspace." -ForegroundColor Green
} else {
    Write-Host "[INFO] project.godot is not present in root yet. (New or uninitialized repository)." -ForegroundColor Cyan
}

# 3. Check for Export Presets
if (Test-Path "export_presets.cfg") {
    Write-Host "[OK] Found export_presets.cfg." -ForegroundColor Green
} else {
    Write-Host "[INFO] export_presets.cfg is not present yet." -ForegroundColor Cyan
}

Write-Host "=================================================" -ForegroundColor Cyan
