# 任务管家（V5）整包发布工具：一条命令完成「推送 → Release → 资产 → 清单 → CDN 刷新」
#
# 存在的理由（全是真踩过的坑）：
#   1. PowerShell 5.1 用 curl.exe 内联 -d 传 JSON 会被剥掉双引号，GitHub
#      直接回 400 —— 本工具所有 JSON 一律写临时文件 --data-binary "@file"。
#   2. 手写 sha256 进脚本/清单会丢字符（63 位 vs 64 位肉眼根本分不出），
#      导致正确的上传被循环删除 —— 摘要一律运行时从 APK 现算。
#   3. 本机到 GitHub 间歇性不可达 —— 所有网络操作按错误类型重试到成功
#      （4xx 业务错误不重试，立刻进入幂等处理）。
#   4. Release 资产必须 size + digest 双核对，避免半截包被当成发布完成。
#
# 用法（先手工完成代码提交，再跑本工具）：
#   $env:GITHUB_TOKEN = 'ghp_xxx'   # 经典 token，需 repo 权限；不落盘、不进命令行历史
#   powershell -ExecutionPolicy Bypass -File tool\publish_release.ps1 -Version 5.5.23
#
# 默认流程（全部幂等，可重复执行）：
#   0. 校验 4 个 APK 在位，现算 sha256/size
#   1. 本地缺 tag 时在 HEAD 建附注 tag
#   2. git push 分支 + tag（网络抖动无限重试）
#   3. 创建 GitHub Release（已存在则复用）
#   4. 上传/核对 4 个 APK（同名资产 size/digest 不符则删后重传）
#   5. 重写 update.json（version/updatedAt/url/sha/size/mirrors，notes 保留）
#   6. update.json 单独提交（UTF-8 文件 -F，遵守 rule-7）并推送
#   7. 通知 purge.jsdelivr.net 刷新清单缓存
#
# 可选项：
#   -Notes @('本次更新内容1','2')   更新 update.json 的 notes（不传则保留原文）
#   -Branch main                    跟踪分支名
#   -AssetDir <path>                APK 目录（默认 build\app\outputs\flutter-apk）
#   -SkipPurge / -SkipManifestCommit
#   -MaxAttempts 50                 网络重试上限（0 = 无限，默认）

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$OwnerRepo = 'Aria-2676/note_study',

    [string]$Branch = 'main',

    [string]$AssetDir,

    [string[]]$Notes,

    # 清单 mirrors 字段热下发的镜像前缀，顺序即客户端尝试顺序，
    # 与 lib/core/config/download_mirrors.dart 的内置列表保持一致；
    # 老客户端不识别该字段会直接忽略，无兼容问题。
    [string[]]$MirrorPrefixes = @('https://ghfast.top', 'https://gh-proxy.com'),

    [switch]$SkipPurge,
    [switch]$SkipManifestCommit,

    [int]$MaxAttempts = 0
)

$ErrorActionPreference = 'Stop'

# 版本号清洗：自动剥离常见前后缀，兼容 pubspec.yaml 里的 "5.5.23+0" 和 "v5.5.23"
$Version = $Version.Trim() -replace '^[vV]', '' -replace '\+.*$', ''
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "版本号格式错误：'$Version'。请使用纯数字三段式，如 5.5.23（自动清洗后仍不符合）。"
}

# GitHub Token 检查
if (-not $env:GITHUB_TOKEN) {
    throw "缺少 GITHUB_TOKEN 环境变量。请先执行：`n`n  `$env:GITHUB_TOKEN = 'ghp_你的token'`n`n然后重新运行本工具。"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $AssetDir) {
    $AssetDir = Join-Path $repoRoot 'build\app\outputs\flutter-apk'
}

$apkFiles = @(
    'app-release.apk',
    'app-arm64-v8a-release.apk',
    'app-armeabi-v7a-release.apk',
    'app-x86_64-release.apk'
)

function Log($msg) {
    $ts = Get-Date -Format 'HH:mm:ss'
    Write-Host "[$ts] $msg"
}

function Invoke-Retry {
    param(
        [scriptblock]$Action,
        [string]$Desc,
        [int]$MaxAttempts = 0
    )
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            & $Action
            return
        } catch {
            $msg = $_.Exception.Message
            if ($msg -match '__NOTFOUND__') { throw }
            if ($msg -match '__TRANSIENT__') {
                if ($MaxAttempts -gt 0 -and $attempt -ge $MaxAttempts) {
                    throw "已达最大重试次数（$MaxAttempts）：$Desc"
                }
                Log "  [重试 $attempt] $Desc"
                Start-Sleep -Seconds ([Math]::Min(5 * $attempt, 60))
                continue
            }
            throw
        }
    }
}

function Api-Get($url) {
    $headers = @{
        'Authorization' = "token $env:GITHUB_TOKEN"
        'Accept'        = 'application/vnd.github.v3+json'
        'User-Agent'    = 'v5-publish-tool'
    }
    $tmp = Join-Path $env:TEMP "v5_api_$(Get-Random).json"
    try {
        curl.exe -s -o $tmp -w '%{http_code}' -H "Authorization: token $env:GITHUB_TOKEN" -H 'Accept: application/vnd.github.v3+json' -H 'User-Agent: v5-publish-tool' $url | Out-Null
        $code = $LASTEXITCODE
        if ($code -ne 0) { throw "__TRANSIENT__ curl exit $code" }
        $httpCode = Get-Content $tmp -Raw | Select-String -Pattern '^\d{3}$' | ForEach-Object { $_.Matches.Value }
        if (-not $httpCode) { $httpCode = '000' }
        $body = Get-Content $tmp -Raw -ErrorAction SilentlyContinue
        if ($httpCode -eq '404') { throw "__NOTFOUND__ $url" }
        if ($httpCode -ge '400') { throw "HTTP $httpCode : $body" }
        return $body | ConvertFrom-Json
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Api-Json($method, $url, $bodyObj) {
    $tmpBody = Join-Path $env:TEMP "v5_api_body_$(Get-Random).json"
    $tmpResp = Join-Path $env:TEMP "v5_api_resp_$(Get-Random).json"
    try {
        $json = $bodyObj | ConvertTo-Json -Depth 10 -Compress
        [System.IO.File]::WriteAllText($tmpBody, $json, [System.Text.UTF8Encoding]::new($false))
        curl.exe -s -o $tmpResp -w '%{http_code}' -X $method `
            -H "Authorization: token $env:GITHUB_TOKEN" `
            -H 'Accept: application/vnd.github.v3+json' `
            -H 'User-Agent: v5-publish-tool' `
            -H 'Content-Type: application/json' `
            --data-binary "@$tmpBody" `
            $url | Out-Null
        $code = $LASTEXITCODE
        if ($code -ne 0) { throw "__TRANSIENT__ curl exit $code" }
        $httpCode = Get-Content $tmpResp -Raw | Select-String -Pattern '^\d{3}$' | ForEach-Object { $_.Matches.Value }
        if (-not $httpCode) { $httpCode = '000' }
        $body = Get-Content $tmpResp -Raw -ErrorAction SilentlyContinue
        if ($httpCode -eq '404') { throw "__NOTFOUND__ $url" }
        if ($httpCode -ge '400') { throw "HTTP $httpCode : $body" }
        return $body | ConvertFrom-Json
    } finally {
        Remove-Item $tmpBody, $tmpResp -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-GitRetry {
    param([string[]]$Args, [string]$Desc)
    Invoke-Retry -Desc $Desc -MaxAttempts $MaxAttempts -Action {
        & git @Args
        if ($LASTEXITCODE -ne 0) { throw "__TRANSIENT__ git exit $LASTEXITCODE" }
    }
}

Log "=== V5 发布工具 v$Version ==="

# 步骤 0：校验 APK
Log '步骤 0：校验 APK 文件'
$apkInfo = @{}
foreach ($name in $apkFiles) {
    $path = Join-Path $AssetDir $name
    if (-not (Test-Path $path)) { throw "APK 缺失：$path" }
    $hash = (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
    $size = (Get-Item $path).Length
    $apkInfo[$name] = @{ path = $path; sha256 = $hash; size = $size }
    Log "  $name : $([Math]::Round($size/1MB,2)) MB, sha256=$($hash.Substring(0,16))..."
}

# 用 aapt 确认 versionName 真的是 $Version，杜绝「拿旧包发新版」。
Log '  核对 fat 包 versionName...'
$aapt2 = $null
foreach ($bt in @(
    "$env:LOCALAPPDATA\Android\Sdk\build-tools",
    'D:\Dev\SDK\AndroidSdk\build-tools'
)) {
    if (Test-Path $bt) {
        $aapt2 = Get-ChildItem $bt -Directory | Sort-Object Name -Descending | Select-Object -First 1 | ForEach-Object { Join-Path $_.FullName 'aapt2.exe' }
        if ($aapt2 -and (Test-Path $aapt2)) { break }
    }
}
if ($aapt2 -and (Test-Path $aapt2)) {
    $dump = & $aapt2 dump badging $apkInfo['app-release.apk'].path 2>$null
    $m = $dump | Select-String -Pattern "versionName='([^']+)'" | Select-Object -First 1
    $vn = $m.Matches.Groups[1].Value
    if ($vn -and $vn -ne $Version) {
        throw "fat 包 versionName='$vn' 与 -Version '$Version' 不符 —— 先在 pubspec.yaml 改版本号并重新构建。"
    }
    if ($vn) { Log "  versionName 核对：$vn" }
} else {
    Log '  [警告] 未找到 aapt2，跳过 versionName 核对。'
}

# 步骤 1：tag
$tag = "v$Version"
Log "步骤 1：tag $tag"
& git rev-parse -q --verify "refs/tags/$tag" | Out-Null
if ($LASTEXITCODE -ne 0) {
    & git tag -a $tag -m "V5.$Version release"
    if ($LASTEXITCODE -ne 0) { throw "git tag 失败" }
    Log "  已创建 tag $tag"
} else {
    Log "  tag $tag 已存在"
}

# 步骤 2：push
Log '步骤 2：推送分支与 tag'
Invoke-GitRetry -Args @('push', 'origin', $Branch) -Desc '推送分支'
Invoke-GitRetry -Args @('push', 'origin', $tag) -Desc '推送 tag'

# 步骤 3：Release
Log '步骤 3：创建/获取 Release'
$release = $null
try {
    $release = Api-Get "https://api.github.com/repos/$OwnerRepo/releases/tags/$tag"
    Log "  Release 已存在（id=$($release.id)）"
} catch {
    if ($_.Exception.Message -match '__NOTFOUND__') {
        Log '  Release 不存在，创建中...'
        $release = Api-Json 'POST' "https://api.github.com/repos/$OwnerRepo/releases" @{
            tag_name         = $tag
            target_commitish = $Branch
            name             = "V5.$Version"
            body             = "V5.$Version 自动发布（tool/publish_release.ps1）"
            draft            = $false
            prerelease       = $false
        }
        Log "  已创建 Release（id=$($release.id)）"
    } else { throw }
}
$releaseId = $release.id

# 步骤 4：上传/核对资产
Log '步骤 4：上传/核对 APK 资产'
foreach ($name in $apkFiles) {
    $info = $apkInfo[$name]
    $uploadUrl = "https://uploads.github.com/repos/$OwnerRepo/releases/$releaseId/assets?name=$name"
    $needUpload = $true
    $existing = $release.assets | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if ($existing) {
        $remoteSize = $existing.size
        $remoteDigest = $existing.digest -replace '^sha256:', ''
        if ($remoteSize -eq $info.size -and $remoteDigest -eq $info.sha256) {
            Log "  $name 已存在且校验通过，跳过"
            $needUpload = $false
        } else {
            Log "  $name 已存在但不符（size: $remoteSize vs $($info.size), digest: $remoteDigest vs $($info.sha256)），删除后重传"
            try {
                Api-Json 'DELETE' "https://api.github.com/repos/$OwnerRepo/releases/assets/$($existing.id)" @{}
            } catch { Log "  [警告] 删除旧资产失败：$_" }
        }
    }
    if ($needUpload) {
        Log "  上传 $name ..."
        Invoke-Retry -Desc "上传 $name" -MaxAttempts $MaxAttempts -Action {
            $tmp = Join-Path $env:TEMP "v5_upload_$(Get-Random).json"
            try {
                curl.exe -s -o $tmp -w '%{http_code}' -X POST `
                    -H "Authorization: token $env:GITHUB_TOKEN" `
                    -H 'Accept: application/vnd.github.v3+json' `
                    -H 'User-Agent: v5-publish-tool' `
                    -H 'Content-Type: application/vnd.android.package-archive' `
                    --data-binary "@$($info.path)" `
                    $uploadUrl | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "__TRANSIENT__ curl exit $LASTEXITCODE" }
                $httpCode = Get-Content $tmp -Raw | Select-String -Pattern '^\d{3}$' | ForEach-Object { $_.Matches.Value }
                if (-not $httpCode) { $httpCode = '000' }
                $body = Get-Content $tmp -Raw -ErrorAction SilentlyContinue
                if ($httpCode -ge '400') { throw "HTTP $httpCode : $body" }
            } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        }
        Log "  $name 上传完成"
    }
}

# 最终回读核对
Log '  最终回读核对...'
$release = Api-Get "https://api.github.com/repos/$OwnerRepo/releases/$releaseId"
$allOk = $true
foreach ($name in $apkFiles) {
    $info = $apkInfo[$name]
    $asset = $release.assets | Where-Object { $_.name -eq $name } | Select-Object -First 1
    if (-not $asset) { Log "  [错误] $name 缺失"; $allOk = $false; continue }
    $remoteSize = $asset.size
    $remoteDigest = $asset.digest -replace '^sha256:', ''
    if ($remoteSize -ne $info.size -or $remoteDigest -ne $info.sha256) {
        Log "  [错误] $name 校验失败：size $remoteSize vs $($info.size), digest $remoteDigest vs $($info.sha256)"
        $allOk = $false
    }
}
if (-not $allOk) { throw '资产校验未通过，请检查日志后重试。' }
Log '  全部资产校验通过'

# 步骤 5：更新 update.json
Log '步骤 5：更新 update.json'
$updateJsonPath = Join-Path $repoRoot 'update.json'
$manifest = @{}
if (Test-Path $updateJsonPath) {
    $manifest = Get-Content $updateJsonPath -Raw | ConvertFrom-Json
}
$manifest.version = $Version
$manifest.updatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$manifest.url = "https://github.com/$OwnerRepo/releases/download/$tag/app-release.apk"
$manifest.sha256 = $apkInfo['app-release.apk'].sha256
$manifest.sizeBytes = $apkInfo['app-release.apk'].size
$manifest.mirrors = $MirrorPrefixes
if ($Notes) { $manifest.notes = $Notes }
if (-not $manifest.schemaVersion) { $manifest.schemaVersion = 1 }

# 中文转 \uXXXX 再还原，避免 UTF-8 BOM 问题
$jsonText = $manifest | ConvertTo-Json -Depth 10
$jsonText = [System.Text.RegularExpressions.Regex]::Replace($jsonText, '\\u([0-9a-fA-F]{4})', { param($m) [char][int]"0x$($m.Groups[1].Value)" })
[System.IO.File]::WriteAllText($updateJsonPath, $jsonText, [System.Text.UTF8Encoding]::new($false))
Log "  update.json 已重写"

# 步骤 6：提交并推送 update.json
if (-not $SkipManifestCommit) {
    Log '步骤 6：提交并推送 update.json'
    & git add -- update.json
    if ($LASTEXITCODE -ne 0) { throw "git add 失败" }
    $commitMsg = "V5.${Version}: 更新发布清单（version/url/sha256/sizeBytes/mirrors）`n"
    $msgFile = Join-Path $env:TEMP "v5_commit_$(Get-Random).txt"
    [System.IO.File]::WriteAllText($msgFile, $commitMsg, [System.Text.UTF8Encoding]::new($false))
    & git commit -F $msgFile
    Remove-Item $msgFile -Force -ErrorAction SilentlyContinue
    if ($LASTEXITCODE -ne 0) { throw "git commit 失败" }
    Invoke-GitRetry -Args @('push', 'origin', $Branch) -Desc '推送 update.json'
} else {
    Log '  跳过 update.json 提交（-SkipManifestCommit）'
}

# 步骤 7：CDN 刷新
if (-not $SkipPurge) {
    Log '步骤 7：刷新 jsDelivr 缓存'
    $purgeUrl = "https://purge.jsdelivr.net/gh/$OwnerRepo@$Branch/update.json"
    try {
        Invoke-Retry -Desc 'purge jsDelivr' -MaxAttempts 3 -Action {
            $resp = Invoke-WebRequest -Uri $purgeUrl -UseBasicParsing -TimeoutSec 30
            if ($resp.StatusCode -ne 200) { throw "__TRANSIENT__ HTTP $($resp.StatusCode)" }
        }
        Log "  已通知 purge.jsdelivr.net"
    } catch { Log "  [警告] CDN 刷新失败：$_" }
} else {
    Log '  跳过 CDN 刷新（-SkipPurge）'
}

Log '=== 发布完成 ==='
Log "Release: https://github.com/$OwnerRepo/releases/tag/$tag"
Log "update.json: https://gcore.jsdelivr.net/gh/$OwnerRepo@$Branch/update.json"
