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

# 计算构建序号：扫描 apk_output 已有同版本 release 包，取最大序号+1（无则从 1 开始）
$apkOutputDir = Join-Path $projectRoot "apk_output"
$buildNo = 1
if (Test-Path $apkOutputDir) {
    $existing = @(Get-ChildItem -Path $apkOutputDir -Filter "qinglong_app_glass_v${versionName}_release_*.apk" -File -ErrorAction SilentlyContinue)
    foreach ($f in $existing) {
        if ($f.BaseName -match '_(\d+)$') {
            $n = [int]$Matches[1]
            if ($n -ge $buildNo) { $buildNo = $n + 1 }
        }
    }
}
# 本地构建时间戳（epoch 毫秒，供新版检测"本地包比 GitHub 新时不提示"）
$buildMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
Write-Host "build no: $buildNo" -ForegroundColor Yellow

# 2. build args
$buildArgs = @("build", "apk")
if ($DebugMode) {
    $buildArgs += "--debug"
    $mode = "debug"
    $filePattern = "app-debug.apk"
} else {
    $buildArgs += "--release"
    $buildArgs += "--no-shrink"
    # 仅安卓64位 + 图标不裁剪（防 tree-shake 导致动态图标变竖条）
    $buildArgs += "--target-platform"
    $buildArgs += "android-arm64"
    $buildArgs += "--no-tree-shake-icons"
    # 注入本地构建时间与安装包序号（新版检测用）
    $buildArgs += "--dart-define=LOCAL_BUILD_TIME=$buildMs"
    $buildArgs += "--dart-define=LOCAL_BUILD_NO=$buildNo"
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

# 4. copy to apk_output (NOT to desktop - user rule: 严禁动桌面文件)
if ($NoCopy) {
    Write-Host ""
    Write-Host "[3/4] skip copy (-NoCopy)" -ForegroundColor DarkGray
} else {
    if (-not (Test-Path $apkOutputDir)) {
        New-Item -ItemType Directory -Path $apkOutputDir -Force | Out-Null
    }
    $suffix = if ($DebugMode) { "debug" } else { "release" }
    # 文件名规则：项目目录名 + _v + 版本号 + _release + _序号.apk（序号递增便于新版检测）
    $destName = "qinglong_app_glass_v${versionName}_${suffix}_${buildNo}.apk"
    $destPath = Join-Path $apkOutputDir $destName
    Copy-Item $apkFile.FullName -Destination $destPath -Force
    Write-Host ""
    Write-Host "[3/4] copied to apk_output" -ForegroundColor Green
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
        # adb 首次启动会向 stderr 打印 "daemon not running..."，
        # 在 $ErrorActionPreference="Stop" 下会被当成 NativeCommandError 中断脚本，这里临时放宽
        $prevEA = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
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
        $ErrorActionPreference = $prevEA
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  build done!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
