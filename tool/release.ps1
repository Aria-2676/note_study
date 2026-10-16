# 任务管家（V5）一键发布：改版本号 → 构建 APK → 发布到 GitHub
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File tool\release.ps1 -Version 5.5.24
#
# 流程：
#   1. 修改 pubspec.yaml 版本号
#   2. 构建 4 个 APK（split + fat）
#   3. 提交代码（tag + update.json）
#   4. 调用 publish_release.ps1 发布
#
# 可选参数：
#   -SkipTests     跳过构建前的测试（默认会跑测试）
#   -SkipPublish   只构建不发布（用于验证构建）
#   -DryRun        只显示将要做什么，不实际执行

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [switch]$SkipTests,
    [switch]$SkipPublish,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Log($msg) {
    $ts = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$ts] $msg"
}

function Confirm-Step($msg) {
    if ($DryRun) {
        Log "[DRY-RUN] $msg"
        return $false
    }
    return $true
}

# 版本号清洗
$Version = $Version.Trim() -replace '^[vV]', '' -replace '\+.*$', ''
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "版本号格式错误：'$Version'。请使用纯数字三段式，如 5.5.24"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$pubspecPath = Join-Path $repoRoot 'pubspec.yaml'

Log "=== V5 一键发布 v$Version ==="

# 步骤 1：修改 pubspec.yaml
Log "步骤 1：修改 pubspec.yaml 版本号"
$pubspec = Get-Content $pubspecPath -Raw -Encoding UTF8
if ($pubspec -notmatch 'version:\s*\d+\.\d+\.\d+\+\d+') {
    throw "pubspec.yaml 中未找到 version 字段"
}
$oldVersion = $Matches[0]
$newVersionLine = "version: $Version+0"
$pubspec = $pubspec -replace 'version:\s*\d+\.\d+\.\d+\+\d+', $newVersionLine
if (Confirm-Step "将 $oldVersion 改为 $newVersionLine") {
    [System.IO.File]::WriteAllText($pubspecPath, $pubspec, [System.Text.UTF8Encoding]::new($false))
    Log "  已修改：$oldVersion → $newVersionLine"
}

# 步骤 2：构建 APK
Log "步骤 2：构建 APK（split + fat）"
if (Confirm-Step "构建 APK") {
    Push-Location $repoRoot
    try {
        # 构建 split 包
        Log "  构建 split 包（arm64-v8a, armeabi-v7a, x86_64）..."
        flutter build apk --release --no-tree-shake-icons --split-per-abi
        if ($LASTEXITCODE -ne 0) { throw "split 构建失败" }

        # 构建 fat 包
        Log "  构建 fat 包..."
        flutter build apk --release --no-tree-shake-icons
        if ($LASTEXITCODE -ne 0) { throw "fat 构建失败" }

        # 验证 4 个 APK 都存在
        $apkDir = Join-Path $repoRoot 'build\app\outputs\flutter-apk'
        $apkFiles = @(
            'app-release.apk',
            'app-arm64-v8a-release.apk',
            'app-armeabi-v7a-release.apk',
            'app-x86_64-release.apk'
        )
        foreach ($name in $apkFiles) {
            $path = Join-Path $apkDir $name
            if (-not (Test-Path $path)) { throw "APK 缺失：$path" }
            $size = (Get-Item $path).Length
            Log "  ✓ $name ($([Math]::Round($size/1MB,2)) MB)"
        }
    } finally {
        Pop-Location
    }
}

# 步骤 3：提交代码
Log "步骤 3：提交代码"
if (Confirm-Step "提交 pubspec.yaml 和构建产物") {
    Push-Location $repoRoot
    try {
        # 提交 pubspec.yaml
        git add pubspec.yaml
        $msg = 'V' + $Version + '：版本号更新至 ' + $Version
        $msgFile = Join-Path $env:TEMP "v5_release_$(Get-Random).txt"
        [System.IO.File]::WriteAllText($msgFile, $msg, [System.Text.UTF8Encoding]::new($false))
        git commit -F $msgFile
        Remove-Item $msgFile -Force -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0) { throw "git commit 失败" }
        Log "  已提交版本号更新"
    } finally {
        Pop-Location
    }
}

# 步骤 4：发布
if (-not $SkipPublish) {
    Log "步骤 4：发布到 GitHub"
    if (Confirm-Step "调用 publish_release.ps1") {
        $publishScript = Join-Path $PSScriptRoot 'publish_release.ps1'
        & powershell -ExecutionPolicy Bypass -File $publishScript -Version $Version
        if ($LASTEXITCODE -ne 0) { throw "发布失败" }
    }
} else {
    Log "  跳过发布（-SkipPublish）"
}

Log "=== 发布完成 ==="
Log "版本：$Version"
Log "Release：https://github.com/Aria-2676/note_study/releases/tag/v$Version"
