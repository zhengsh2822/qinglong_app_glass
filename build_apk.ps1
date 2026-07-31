param(
    [switch]$DebugMode,
    [switch]$NoCopy,
    [switch]$NoInstall
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
if (-not $projectRoot) { $projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $projectRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  qinglong APK build script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. read version from pubspec.yaml
$pubspecContent = Get-Content (Join-Path $projectRoot "pubspec.yaml") -Raw -Encoding UTF8
$versionName = "unknown"
if ($pubspecContent -match 'version:\s*(\d+\.\d+\.\d+)\+(\d+)') {
    $versionName = $Matches[1]
}
Write-Host "version: $versionName" -ForegroundColor Yellow

# 2. build args
$buildArgs = @("build", "apk")
if ($DebugMode) {
    $buildArgs += "--debug"
    $mode = "debug"
    $filePattern = "app-debug.apk"
} else {
    $buildArgs += "--release"
    $buildArgs += "--no-shrink"
    $mode = "release"
    $filePattern = "*release*.apk"
}

Write-Host ""
Write-Host "[1/4] build start (mode=$mode)..." -ForegroundColor Green
Write-Host "command: flutter $($buildArgs -join ' ')" -ForegroundColor DarkGray

$beforeTime = Get-Date
& flutter @buildArgs | Out-Null
Write-Host "flutter build finished (exit code ignored)" -ForegroundColor DarkGray

# 3. find APK
$apkDir = Join-Path $projectRoot "build\app\outputs\flutter-apk"
if (-not (Test-Path $apkDir)) {
    Write-Host "[ERROR] APK output dir not found: $apkDir" -ForegroundColor Red
    exit 1
}

$apkFiles = @(Get-ChildItem -Path $apkDir -Filter $filePattern -File | Sort-Object LastWriteTime -Descending)
if ($apkFiles.Count -eq 0) {
    Write-Host "[ERROR] no $mode APK found" -ForegroundColor Red
    exit 1
}

$apkFile = $apkFiles[0]
$sizeMB = [math]::Round($apkFile.Length / 1MB, 2)
Write-Host ""
Write-Host "[2/4] build success!" -ForegroundColor Green
Write-Host "  file: $($apkFile.Name)" -ForegroundColor Gray
Write-Host "  size: $sizeMB MB" -ForegroundColor Gray
Write-Host "  time: $($apkFile.LastWriteTime)" -ForegroundColor Gray

# 4. copy to desktop
if ($NoCopy) {
    Write-Host ""
    Write-Host "[3/4] skip copy (-NoCopy)" -ForegroundColor DarkGray
} else {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $suffix = if ($DebugMode) { "debug" } else { "release" }
    $destName = "qinglong_app_v${versionName}_${suffix}.apk"
    $destPath = Join-Path $desktopPath $destName
    Copy-Item $apkFile.FullName -Destination $destPath -Force
    Write-Host ""
    Write-Host "[3/4] copied to desktop" -ForegroundColor Green
    Write-Host "  file: $destName" -ForegroundColor Gray
    Write-Host "  path: $destPath" -ForegroundColor Gray
}

# 5. install to connected ADB device if available
if ($NoInstall) {
    Write-Host ""
    Write-Host "[4/4] skip install (-NoInstall)" -ForegroundColor DarkGray
} else {
    # find adb in PATH or Android SDK
    $adb = $null
    $adbInPath = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbInPath) {
        $adb = $adbInPath.Source
    } else {
        # try common Android SDK locations
        $androidHome = $env:ANDROID_HOME
        if (-not $androidHome) { $androidHome = $env:ANDROID_SDK_ROOT }
        if ($androidHome) {
            $adbPath = Join-Path $androidHome "platform-tools\adb.exe"
            if (Test-Path $adbPath) { $adb = $adbPath }
        }
        if (-not $adb) {
            $localSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
            if (Test-Path $localSdk) { $adb = $localSdk }
        }
    }

    if (-not $adb) {
        Write-Host ""
        Write-Host "[4/4] adb not found, skip install" -ForegroundColor DarkGray
    } else {
        # get connected devices
        $devicesOutput = & $adb devices 2>$null
        $deviceLines = $devicesOutput -split "`n" | Where-Object {
            $_ -match "\sdevice$" -and $_ -notmatch "List of devices"
        }

        if ($deviceLines.Count -eq 0) {
            Write-Host ""
            Write-Host "[4/4] no device connected, skip install" -ForegroundColor DarkGray
        } else {
            $deviceIds = $deviceLines | ForEach-Object { ($_ -split "`t")[0].Trim() }
            Write-Host ""
            Write-Host "[4/4] install to $($deviceIds.Count) device(s)..." -ForegroundColor Green

            foreach ($deviceId in $deviceIds) {
                Write-Host "  -> $deviceId : " -NoNewline -ForegroundColor Gray
                $installResult = & $adb -s $deviceId install -r -d "$($apkFile.FullName)" 2>&1
                $installText = ($installResult | Out-String).Trim()
                if ($installText -match "Success") {
                    Write-Host "Success" -ForegroundColor Green
                } else {
                    Write-Host "Failed" -ForegroundColor Red
                    Write-Host "     $installText" -ForegroundColor DarkGray
                }
            }
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  build done!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
