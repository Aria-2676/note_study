# 打包小游戏并回填 manifest.json 的 sha256 / sizeBytes。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File tool/build_game_package.ps1 -GameId 2048
#   powershell -ExecutionPolicy Bypass -File tool/build_game_package.ps1 -GameId 2048 -Version 1.0.1
#
# 约定：
#   - 游戏源目录：game_center/src/<源目录名>/       （默认与 GameId 同名）
#   - 产出包路径：manifest 中该游戏 package.path 指定的位置
#   - manifest.json 同时是元数据（名称/简介/图标/单价）的唯一来源，
#     本脚本只负责回填 package.sha256 与 package.sizeBytes。

param(
    [Parameter(Mandatory = $true)][string]$GameId,
    [string]$Version,
    [string]$SourceDir,
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
}

$manifestPath = Join-Path $RepoRoot 'game_center/manifest.json'
if (-not (Test-Path $manifestPath)) {
    throw "找不到清单文件: $manifestPath"
}

$manifest = Get-Content $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$target = $manifest.games | Where-Object { $_.id -eq $GameId } | Select-Object -First 1
if (-not $target) {
    throw "清单中不存在游戏 id=$GameId，请先在 manifest.json 中登记"
}

if ($Version) { $target.latestVersion = $Version }
$effectiveVersion = $target.latestVersion
if (-not $effectiveVersion) {
    throw "游戏 $GameId 缺少 latestVersion"
}

if (-not $SourceDir) {
    if ($target.source) { $SourceDir = $target.source } else { $SourceDir = "game_center/src/$GameId" }
}
$sourcePath = Join-Path $RepoRoot $SourceDir
if (-not (Test-Path $sourcePath)) {
    throw "找不到游戏源目录: $sourcePath"
}
if (-not (Test-Path (Join-Path $sourcePath 'index.html'))) {
    throw "游戏源目录缺少入口文件 index.html: $sourcePath"
}

# 包路径：manifest 已指定则沿用，否则按约定生成
$packageRelPath = $target.package.path
if (-not $packageRelPath) {
    $packageRelPath = "game_center/packages/${GameId}_v$effectiveVersion.zip"
    $target.package | Add-Member -NotePropertyName path -NotePropertyValue $packageRelPath -Force
}
$packagePath = Join-Path $RepoRoot $packageRelPath

$packageDir = Split-Path -Parent $packagePath
if (-not (Test-Path $packageDir)) {
    New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
}

if (Test-Path $packagePath) {
    Remove-Item $packagePath -Force
}

# 只打包源目录内容（入口位于 zip 根目录）
Compress-Archive -Path (Join-Path $sourcePath '*') -DestinationPath $packagePath -CompressionLevel Optimal

$hash = (Get-FileHash -Path $packagePath -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $packagePath).Length

$target.package.sha256 = $hash
$target.package.sizeBytes = $size
$target.package.path = $packageRelPath

$manifest | Add-Member -NotePropertyName updatedAt -NotePropertyValue (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') -Force

$json = $manifest | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($manifestPath, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "已打包 $GameId v$effectiveVersion" -ForegroundColor Green
Write-Host "  包路径 : $packageRelPath"
Write-Host "  体积   : $size 字节"
Write-Host "  sha256 : $hash"
Write-Host "已更新清单: $manifestPath"