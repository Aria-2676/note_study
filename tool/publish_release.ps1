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
    [ValidatePattern('^\d+\.\d+\.\d+$')]
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
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $AssetDir) {
    $AssetDir = Join-Path $repoRoot 'build\app\outputs\flutter-apk'
}
$updateJsonPath = Join-Path $repoRoot 'update.json'

# 文件名 → update.json 的 downloads 键 / ABI 标签。
# fat 包对应泛化 android 键（老客户端回落用），必须存在。
$assetMap = [ordered]@{
    'app-release.apk'             = 'android'
    'app-arm64-v8a-release.apk'   = 'android-arm64-v8a'
    'app-armeabi-v7a-release.apk' = 'android-armeabi-v7a'
    'app-x86_64-release.apk'      = 'android-x86_64'
}

function Log($m) {
    Write-Host ("{0} {1}" -f (Get-Date -Format 'HH:mm:ss'), $m)
}

# ---- token -------------------------------------------------------------------

$token = $env:GITHUB_TOKEN
if (-not $token) {
    throw '未提供 GITHUB_TOKEN 环境变量。先：$env:GITHUB_TOKEN = ''ghp_xxx''（需要 repo 权限）。'
}
$authHeaders = @('-H', "Authorization: token $token", '-H', 'Accept: application/vnd.github+json')
$owner, $repo = $OwnerRepo -split '/', 2
$tag = "v$Version"

# ---- 0. 资产校验 + 现算摘要 ----------------------------------------------------

Log "步骤 0：校验 $AssetDir 下的 4 个 APK"
if (-not (Test-Path -LiteralPath $AssetDir)) {
    throw "APK 目录不存在：$AssetDir（先跑 tool\build_apk.ps1 -Flavor both）"
}

$assets = @()
foreach ($name in $assetMap.Keys) {
    $path = Join-Path $AssetDir $name
    if (-not (Test-Path -LiteralPath $path)) {
        throw "缺少资产 $name —— 请用 -Flavor both 构建（fat + 3 split 缺一不可）"
    }
    $fi = Get-Item -LiteralPath $path
    $sha = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()
    if ($sha.Length -ne 64) { throw "内部错误：$name 算出的 sha256 不是 64 位：$sha" }
    $assets += [pscustomobject]@{
        Name = $name
        Key  = $assetMap[$name]
        Path = $path
        Size = [int64]$fi.Length
        Sha  = $sha
    }
    Log ("  {0,-30} {1,12} 字节  {2}" -f $name, $fi.Length, $sha)
}

# 用 aapt 确认 versionName 真的是 $Version，杜绝「拿旧包发新版」。
# build-tools 位置两址查找：LOCALAPPDATA 与 android/local.properties 的 sdk.dir
# （本机 SDK 在自定义盘 D:\Dev\SDK\AndroidSdk）。
$buildToolsRoots = @(
    (Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools')
)
$localProps = Join-Path $repoRoot 'android\local.properties'
if (Test-Path -LiteralPath $localProps) {
    $sdkDir = ((Get-Content -LiteralPath $localProps |
        Where-Object { $_ -match '^\s*sdk\.dir\s*=' } | Select-Object -First 1) -split '=', 2)[1]
    if ($sdkDir) {
        $sdkDir = $sdkDir.Trim() -replace '\\\\', '\'
        if (Test-Path -LiteralPath $sdkDir) {
            $buildToolsRoots += (Join-Path $sdkDir 'build-tools')
        }
    }
}
$aapt = $null
foreach ($root in $buildToolsRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $found = Get-ChildItem -Path $root -Filter 'aapt2.exe' -Recurse -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Directory.Name) } -Descending | Select-Object -First 1
    if ($found) { $aapt = $found; break }
}
if ($aapt) {
    $dump = & $aapt.FullName dump badging (Join-Path $AssetDir 'app-release.apk') 2>$null
    # badging 行形如 package: name='...' versionCode='23' versionName='5.5.23'，
    # versionCode 在 versionName 前面，别假设它们相邻。
    $m = $dump | Select-String -Pattern "versionName='([^']+)'" | Select-Object -First 1
    $vn = if ($m) { $m.Matches[0].Groups[1].Value } else { $null }
    if ($vn -and $vn -ne $Version) {
        throw "fat 包 versionName='$vn' 与 -Version '$Version' 不符 —— 先在 pubspec.yaml 改版本号并重新构建。"
    }
    if ($vn) { Log "  versionName 核对：$vn" }
} else {
    Log '  [警告] 未找到 aapt2，跳过 versionName 核对。'
}

# ---- 通用：带重试的网络执行 -----------------------------------------------------

# 判定是否「可以重试」的瞬时错误：curl 没退出零（连不上/超时/5xx 已体现在退出码），
# 或 HTTP 5xx / 408 / 429。4xx 其余视为业务错误，调用方自己处理。
function Test-Transient($exitCode, $httpCode) {
    if ($exitCode -ne 0) { return $true }
    if ($httpCode -match '^(5\d\d|408|429)$') { return $true }
    return $false
}

function Invoke-Retry {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Block
    )
    $attempt = 0
    while ($true) {
        $attempt++
        try {
            return & $Block
        } catch {
            $transient = $_.Exception.Message -eq '__TRANSIENT__'
            if (-not $transient) { throw }
            if ($MaxAttempts -gt 0 -and $attempt -ge $MaxAttempts) {
                throw "$Name 重试 $attempt 次仍失败：$($_.Exception.InnerException)"
            }
            $wait = [Math]::Min(60, 5 * $attempt)
            Log "  [$Name] 瞬时失败（第 $attempt 次），${wait}s 后重试：$($_.Exception.InnerException)"
            Start-Sleep -Seconds $wait
        }
    }
}

function Throw-Transient($detail) {
    throw (New-Object System.Management.Automation.RuntimeException('__TRANSIENT__', $detail))
}

# 调原生命令（curl/git）的统一入口。
#
# 两个坑：
# 1) 脚本顶部 $ErrorActionPreference='Stop' 时，原生命令写往 stderr 的
#    每一行（git push 的进度、curl 报错）都会被 PowerShell 提升成**终止性错误**，
#    直接逃出重试循环——表现为「第一次失败脚本就死，根本不重试」。
# 2) 参数不能用 ValueFromRemainingArguments：curl 的 -w 会被 PowerShell 当成
#    -WarningAction/-WarningVariable 的歧义前缀。所以参数必须作为**一个数组**传入。
# 调用方：Invoke-Native 'curl.exe' @('-sS', '--max-time', '60', $url)
function Invoke-Native {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$FilePath,
        [Parameter(Mandatory = $true, Position = 1)][AllowEmptyCollection()][string[]]$Arguments
    )
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $lines = & $FilePath @Arguments 2>&1 | ForEach-Object { $_.ToString() }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
    }
    return [pscustomobject]@{ ExitCode = $code; Text = ($lines -join "`n") }
}

# GET JSON：返回对象；404 抛业务异常（由调用方识别 __NOTFOUND__）。
function Api-Get($url) {
    $r = Invoke-Native 'curl.exe' (@('-sS', '--max-time', '60') + $authHeaders + @($url, '-w', "`n%{http_code}"))
    $raw = $r.Text
    $idx = $raw.LastIndexOf("`n")
    $body = $raw.Substring(0, $idx).Trim()
    $code = $raw.Substring($idx + 1).Trim()
    if ($code -eq '404') {
        throw (New-Object System.Management.Automation.RuntimeException('__NOTFOUND__'))
    }
    if (Test-Transient $r.ExitCode $code) { Throw-Transient "http=$code curlExit=$($r.ExitCode)" }
    if ($code -notmatch '^2\d\d$') { throw "GET $url 失败 http=$code body=$body" }
    return ($body | ConvertFrom-Json)
}

# 任意方法 + JSON body（body 为 $null 时不传）。返回响应对象。
function Api-Json($method, $url, $obj) {
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        if ($null -ne $obj) {
            [System.IO.File]::WriteAllText(
                $tmp,
                ($obj | ConvertTo-Json -Compress -Depth 6),
                (New-Object System.Text.UTF8Encoding($false))
            )
        }
        $curlArgs = @('-sS', '--max-time', '60', '-X', $method, '-w', "`n%{http_code}") + $authHeaders
        if ($null -ne $obj) { $curlArgs += @('--data-binary', "@$tmp") }
        $curlArgs += $url
        $r = Invoke-Native 'curl.exe' $curlArgs
        $raw = $r.Text
        $idx = $raw.LastIndexOf("`n")
        $body = $raw.Substring(0, $idx).Trim()
        $code = $raw.Substring($idx + 1).Trim()
        if (Test-Transient $r.ExitCode $code) { Throw-Transient "http=$code body=$body" }
        return [pscustomobject]@{ Code = $code; Body = $body; Obj = ($body | ConvertFrom-Json -ErrorAction SilentlyContinue) }
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

# ---- 1/2. tag + push（重试到成功）----------------------------------------------

function Invoke-GitRetry($argList, $name) {
    Invoke-Retry -Name $name -Block {
        $r = Invoke-Native 'git' $argList
        if ($r.ExitCode -ne 0) { Throw-Transient ($r.Text.Trim()) }
        if ($r.Text.Trim()) { Log "  git $($argList[0]): $(($r.Text.Trim().Split("`n")[0]))" }
    }
}

Set-Location $repoRoot

$tagExists = $false
& git rev-parse --quiet --verify "refs/tags/$tag" *> $null
if ($LASTEXITCODE -eq 0) {
    $tagExists = $true
    Log "步骤 1：tag $tag 本地已存在"
} else {
    Log "步骤 1：在 HEAD 创建附注 tag $tag"
    & git tag -a $tag -m "V5.$Version release"
    if ($LASTEXITCODE -ne 0) { throw "git tag 失败" }
}

Log "步骤 2：推送 $Branch 与 $tag（网络抖动会一直重试）"
Invoke-GitRetry -ArgList @('push', 'origin', $Branch) -Name 'push-branch'
Invoke-GitRetry -ArgList @('push', 'origin', $tag) -Name 'push-tag'

# ---- 3. Release（幂等）---------------------------------------------------------

Log "步骤 3：创建/获取 Release $tag"
$release = Invoke-Retry -Name 'get-release' -Block {
    try {
        return Api-Get "https://api.github.com/repos/$owner/$repo/releases/tags/$tag"
    } catch {
        if ($_.Exception.Message -eq '__NOTFOUND__') { return $null }
        if ($_.Exception.Message -eq '__TRANSIENT__') { Throw-Transient $_.Exception.InnerException }
        throw
    }
}

if (-not $release) {
    $resp = Invoke-Retry -Name 'create-release' -Block {
        $r = Api-Json 'POST' "https://api.github.com/repos/$owner/$repo/releases" ([ordered]@{
            tag_name         = $tag
            target_commitish = $Branch
            name             = "V5.$Version"
            body             = "V5.$Version 自动发布（tool/publish_release.ps1）"
            draft            = $false
            prerelease       = $false
        })
        # 400/422：并发或历史残留导致 tag 已有 release（API 对重复 tag 回 422）。
        if ($r.Code -match '^(400|422)$') { return $null }
        if ($r.Code -notmatch '^2\d\d$') { Throw-Transient "create http=$($r.Code) $($r.Body)" }
        return $r.Obj
    }
    if (-not $resp) {
        Log '  创建返回 400/422，回读已有 Release'
        $release = Invoke-Retry -Name 'get-release-after-422' -Block {
            try {
                return Api-Get "https://api.github.com/repos/$owner/$repo/releases/tags/$tag"
            } catch {
                if ($_.Exception.Message -eq '__NOTFOUND__') { Throw-Transient 'release 尚不可见' }
                if ($_.Exception.Message -eq '__TRANSIENT__') { Throw-Transient $_.Exception.InnerException }
                throw
            }
        }
    } else {
        $release = $resp
    }
}
$releaseId = $release.id
Log "  release id=$releaseId"

# ---- 4. 资产上传/核对（幂等）----------------------------------------------------

Log "步骤 4：核对/上传 4 个 APK"

foreach ($a in $assets) {
    $expectedDigest = "sha256:$($a.Sha)"

    # 整个「列举 → 清理 → 上传 → 自校验」放进同一个重试环：
    # 上传 422（同名残留）/副本延迟等问题靠下一轮的 list 自愈，
    # 不写多套互相猜状态的分支。
    Invoke-Retry -Name "asset-$($a.Name)" -Block {
        $rel = Api-Get "https://api.github.com/repos/$owner/$repo/releases/$releaseId"
        $existing = @($rel.assets | Where-Object { $_.name -eq $a.Name })

        $ok = $false
        foreach ($e in $existing) {
            if ([int64]$e.size -eq $a.Size -and ($e.digest -eq $expectedDigest)) {
                Log "  $($a.Name) 已存在且校验通过（size/digest），跳过"
                $ok = $true
            } else {
                Log "  $($a.Name) 已存在但不符（size=$($e.size)/$($a.Size) digest=$($e.digest)），删除重传"
                $del = Api-Json 'DELETE' "https://api.github.com/repos/$owner/$repo/releases/assets/$($e.id)" $null
                if ($del.Code -notmatch '^(204|200)$') {
                    Throw-Transient "delete http=$($del.Code)"
                }
            }
        }
        if ($ok) { return }

        $upUrl = "https://uploads.github.com/repos/$owner/$repo/releases/$releaseId/assets?name=$([uri]::EscapeDataString($a.Name))"
        $upArgs = @(
            '-sS', '--max-time', '600', '-X', 'POST',
            '-H', 'Content-Type: application/vnd.android.package-archive',
            '--data-binary', "@$($a.Path)",
            $upUrl, '-w', "`n%{http_code}"
        ) + $authHeaders
        $r = Invoke-Native 'curl.exe' $upArgs
        $raw = $r.Text
        $idx = $raw.LastIndexOf("`n")
        $body = $raw.Substring(0, $idx).Trim()
        $code = $raw.Substring($idx + 1).Trim()
        if (Test-Transient $r.ExitCode $code) { Throw-Transient "upload http=$code curlExit=$($r.ExitCode)" }
        if ($code -eq '422') {
            # 同名资产残留（常见于删除后副本延迟）：下一轮重新 list → 清理。
            Throw-Transient "upload 422（同名残留，下一轮清理）"
        }
        if ($code -notmatch '^2\d\d$') {
            throw "upload $($a.Name) http=$code body=$body"
        }
        $u = $body | ConvertFrom-Json
        if ([int64]$u.size -ne $a.Size -or $u.digest -ne $expectedDigest) {
            # 响应回读偶发延迟：下一轮 list 会拿到权威状态并自愈。
            Throw-Transient "upload 回读不符 size=$($u.size)/$($a.Size) digest=$($u.digest)"
        }
        Log "  $($a.Name) 上传成功 http=$code size=$($u.size)"
    }
}

# 最终回读：四个名字 + size + digest 全部到位才算完。
Invoke-Retry -Name 'readback' -Block {
    $rel = Api-Get "https://api.github.com/repos/$owner/$repo/releases/$releaseId"
    foreach ($a in $assets) {
        $e = @($rel.assets | Where-Object { $_.name -eq $a.Name })
        if ($e.Count -ne 1) { Throw-Transient "$($a.Name) 数量=$($e.Count)" }
        if ([int64]$e[0].size -ne $a.Size -or $e[0].digest -ne "sha256:$($a.Sha)") {
            Throw-Transient "$($a.Name) 回读不符"
        }
    }
}
Log '  全部资产回读校验通过'

# ---- 5/6. update.json ----------------------------------------------------------

if ($SkipManifestCommit) {
    Log '步骤 5/6：按 -SkipManifestCommit 跳过清单更新'
} else {
    Log "步骤 5：更新 update.json → $Version"
    if (-not (Test-Path -LiteralPath $updateJsonPath)) {
        throw "update.json 不存在：$updateJsonPath"
    }
    $manifest = Get-Content -LiteralPath $updateJsonPath -Raw | ConvertFrom-Json

    $downloads = [ordered]@{}
    foreach ($a in $assets) {
        $downloadUrl = "https://github.com/$owner/$repo/releases/download/$tag/$($a.Name)"
        $mirrorUrls = @($MirrorPrefixes | ForEach-Object { "$_/$downloadUrl" })
        $downloads[$a.Key] = [ordered]@{
            url       = $downloadUrl
            mirrors   = $mirrorUrls
            sha256    = $a.Sha
            sizeBytes = $a.Size
        }
    }

    $existingNotes = @()
    if ($manifest.latest -and $manifest.latest.notes) {
        $existingNotes = @($manifest.latest.notes | Where-Object { $_ -ne $null })
    }
    $finalNotes = if ($Notes -and $Notes.Count -gt 0) {
        @($Notes)
    } else {
        $existingNotes
    }

    $latest = [ordered]@{
        version   = $Version
        notes     = $finalNotes
        downloads = $downloads
    }

    $manifest.latest = [pscustomobject]$latest
    if (-not $manifest.schemaVersion) { $manifest.schemaVersion = 1 }
    $manifest.updatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    # PowerShell 5.1 的 ConvertTo-Json 会把中文转成 \uXXXX，这里还原成可读中文。
    $json = ConvertTo-Json -InputObject $manifest -Depth 12
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        [char][int]('0x' + $m.Groups[1].Value)
    }
    $json = [regex]::Replace($json, '\\u([0-9a-fA-F]{4})', $evaluator)
    # 统一末尾换行，UTF-8 无 BOM。
    [System.IO.File]::WriteAllText($updateJsonPath, ($json.TrimEnd() + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    Log "  已写入 $updateJsonPath"

    Log '步骤 6：提交并推送 update.json'
    & git add -- update.json
    if ($LASTEXITCODE -ne 0) { throw 'git add update.json 失败' }
    $staged = & git diff --cached --name-only
    if (($staged -join "`n").Trim() -ne 'update.json') {
        throw "暂存区异常（应只有 update.json）：$($staged -join ', ')"
    }
    & git diff --cached --quiet -- update.json
    if ($LASTEXITCODE -eq 0) {
        Log '  update.json 无实际变化，跳过提交'
    } else {
        $msgFile = [System.IO.Path]::GetTempFileName()
        try {
            [System.IO.File]::WriteAllText(
                $msgFile,
                "V5.${Version}: 更新发布清单（version/url/sha256/sizeBytes/mirrors）`n",
                (New-Object System.Text.UTF8Encoding($false))
            )
            & git commit -F $msgFile
            if ($LASTEXITCODE -ne 0) { throw 'git commit update.json 失败' }
        } finally {
            Remove-Item -LiteralPath $msgFile -Force -ErrorAction SilentlyContinue
        }
        Invoke-GitRetry @('push', 'origin', $Branch) 'push-manifest'
    }
}

# ---- 7. CDN 刷新 ---------------------------------------------------------------

if (-not $SkipPurge) {
    Log '步骤 7：purge.jsdelivr.net 刷新 update.json'
    Invoke-Retry -Name 'purge-jsdelivr' -Block {
        $purgeUrl = "https://purge.jsdelivr.net/gh/$owner/$repo@$Branch/update.json"
        $r = Invoke-Native 'curl.exe' @('-sS', '--max-time', '60', $purgeUrl, '-w', "`n%{http_code}")
        $raw = $r.Text
        $idx = $raw.LastIndexOf("`n")
        $code = $raw.Substring($idx + 1).Trim()
        if (Test-Transient $r.ExitCode $code) {
            Throw-Transient "purge http=$code"
        }
        if ($code -notmatch '^2\d\d$') {
            # CDN 刷新失败不致命：Contents API 兜底 + 缓存最长 12h 会自然收敛。
            Log "  [警告] purge 返回 http=$code，客户端仍可靠 Contents API 及时发现"
        } else {
            Log '  purge 已受理'
        }
    }
}

Log '完成。人工抽查建议：'
Log "  清单：https://gcore.jsdelivr.net/gh/$owner/$repo@$Branch/update.json"
Log "       https://api.github.com/repos/$owner/$repo/contents/update.json"
foreach ($a in $assets) {
    $u = "https://github.com/$owner/$repo/releases/download/$tag/$($a.Name)"
    Log "  $($a.Name)：$u"
    Log "             https://ghfast.top/$u"
}
