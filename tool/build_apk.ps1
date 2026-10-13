# 任务管家（V5）release APK 构建脚本
#
# 存在的理由：`flutter build apk --release` 有几个「必须记得加」的参数和
# 「必须记得做」的收尾动作，手打很容易漏：
#
#   1. --no-tree-shake-icons   本机 Smart App Control 会拦 font-subset.exe，
#                              不加这个 flag 构建直接失败（除非关掉 SAC）。
#   2. --split-per-abi         fat APK 约 62MB，分 ABI 后每个仅 21~25MB。
#                              自更新是用户流量，没必要让他们下 3 倍体积。
#   3. sha256 + sizeBytes      写 update.json 必需，手工算容易抄错。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File tool\build_apk.ps1
#   powershell -ExecutionPolicy Bypass -File tool\build_apk.ps1 -Flavor fat
#   powershell -ExecutionPolicy Bypass -File tool\build_apk.ps1 -SkipTests
#
# 产出：
#   build\app\outputs\flutter-apk\app-<abi>-release.apk     （split 模式，默认）
#   build\app\outputs\flutter-apk\app-release.apk           （fat 模式）
#   build\app\outputs\release-manifest.txt                  sha256 / 大小 / 版本清单

[CmdletBinding()]
param(
    # split = 每个 ABI 一个包（默认，推荐分发）；fat = 单包全 ABI（体积大）。
    [ValidateSet('split', 'fat')]
    [string]$Flavor = 'split',

    # 跳过 flutter test。默认会跑，因为「签名错了」这类问题只有构建才暴露，
    # 而「逻辑错了」应该在上传前拦住。
    [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$apkDir = Join-Path $repoRoot 'build\app\outputs\flutter-apk'
$manifestPath = Join-Path $repoRoot 'build\app\outputs\release-manifest.txt'

function Write-Step($text) {
    Write-Host ''
    Write-Host "=== $text ===" -ForegroundColor Cyan
}

Write-Step 'release APK build'

# ---- 前置检查 ----------------------------------------------------------------

$keyProps = Join-Path $repoRoot 'android\key.properties'
if (-not (Test-Path -LiteralPath $keyProps)) {
    Write-Host 'android/key.properties 不存在 —— 构建会回落到 DEBUG key。' -ForegroundColor Yellow
    Write-Host '那不能用于分发（签名不匹配会导致用户无法覆盖安装）。' -ForegroundColor Yellow
    Write-Host '先跑 tool\setup_android_keystore_auto.ps1 生成，或在下面确认继续。' -ForegroundColor Yellow
    $answer = Read-Host '仍要继续？(y/N)'
    if ($answer -ne 'y') { throw 'Aborted: 缺少 release 签名配置。' }
} else {
    # 校验 storeFile 的转义。java.util.Properties.load() 把反斜杠当转义符，
    # 单反斜杠会被静默读坏（'\t' 变 TAB），构建报「Keystore file ... not found」。
    # 详见 skill windows-agent-env-workarounds 坑 12。
    $storeLine = (Get-Content -LiteralPath $keyProps |
        Where-Object { $_ -match '^\s*storeFile\s*=' } | Select-Object -First 1)
    if ($storeLine) {
        $storeValue = ($storeLine -split '=', 2)[1]
        if ($storeValue -match "`t") {
            throw ("key.properties 的 storeFile 含 TAB —— 路径用了单反斜杠。" +
                   "请改成双反斜杠，例如 storeFile=D:\\Dev\\keystore\\taskmaster-release.jks")
        }
        # 把 \\ 还原成 \ 后判断文件是否存在
        $resolved = $storeValue -replace '\\\\', '\'
        if (-not (Test-Path -LiteralPath $resolved)) {
            throw "key.properties 指向的密钥库不存在：$resolved"
        }
        Write-Host "keystore : $resolved" -ForegroundColor Green
    }
}

# ---- 测试 --------------------------------------------------------------------

if (-not $SkipTests) {
    Write-Step 'flutter test'
    & flutter test
    if ($LASTEXITCODE -ne 0) { throw "测试未通过（exit $LASTEXITCODE），已中止构建。" }
} else {
    Write-Host '(已跳过测试)' -ForegroundColor Yellow
}

# ---- 构建 --------------------------------------------------------------------

Write-Step 'flutter build apk --release'

# --no-tree-shake-icons 不是「优化取舍」而是**本机的必需项**：
# font-subset.exe 被 Smart App Control 拦截，不加构建必失败。
# 代价是 APK 保留全量 MaterialIcons 字形（约 +1.5MB）。
$buildArgs = @('build', 'apk', '--release', '--no-tree-shake-icons')
if ($Flavor -eq 'split') { $buildArgs += '--split-per-abi' }

Write-Host "flutter $($buildArgs -join ' ')"
& flutter @buildArgs
if ($LASTEXITCODE -ne 0) { throw "构建失败（exit $LASTEXITCODE）。" }

# ---- 产出清单 ----------------------------------------------------------------

Write-Step 'release manifest'

if ($Flavor -eq 'split') {
    $apks = Get-ChildItem -LiteralPath $apkDir -Filter 'app-*-release.apk' |
        Sort-Object Name
} else {
    $apks = Get-ChildItem -LiteralPath $apkDir -Filter 'app-release.apk'
}

if (-not $apks -or $apks.Count -eq 0) { throw "在 $apkDir 没找到构建产物。" }

$version = (Select-String -LiteralPath (Join-Path $repoRoot 'pubspec.yaml') -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
$appVersion = ($version -split '\+')[0]        # 5.5.19+0 -> 5.5.19
$buildNumber = ($version -split '\+')[1]       # 5.5.19+0 -> 0

$usedFlags = '--no-tree-shake-icons'
if ($Flavor -eq 'split') { $usedFlags = $usedFlags + ' --split-per-abi' }

$lines = @(
    "TaskMaster release APK manifest",
    "generated   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "version     : $appVersion",
    "versionCode : $buildNumber",
    "flavor      : $Flavor",
    "flags       : $usedFlags",
    "",
    "把下面这些填进仓库根的 update.json 的 downloads.<平台> 里：",
    "  url       = <CDN 基址>/releases/<文件名>",
    "  sha256    = 下面每行的 sha256",
    "  sizeBytes = 下面每行的大小",
    "",
    ("{0,-34} {1,12}  {2}" -f 'file', 'sizeBytes', 'sha256')
)

Write-Host ''
foreach ($apk in $apks) {
    $hash = (Get-FileHash -LiteralPath $apk.FullName -Algorithm SHA256).Hash.ToLower()
    $size = $apk.Length
    $lines += ("{0,-34} {1,12}  {2}" -f $apk.Name, $size, $hash)
    Write-Host ("{0}  {1,12:N0} 字节  {2}" -f $apk.Name, $size, $hash)
    Write-Host ("   {0,-31} -> {1:N1} MB" -f '', ($size / 1MB))
}

$lines += @(
    "",
    "提醒：",
    "  - 更新包必须与已安装包**同签名**，否则用户安装报 INSTALL_FAILED_UPDATE_INCOMPATIBLE。",
    "  - 上传到 GitHub 仓库 releases/ 后，用 gcore.jsdelivr.net 取（cdn.jsdelivr.net 对 .apk 会 301）。",
    "  - fat APK（单包）约 62MB；split 后每个约 21~25MB。自更新优先给用户 arm64-v8a。"
)

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $manifestPath) | Out-Null
Set-Content -LiteralPath $manifestPath -Value $lines -Encoding UTF8

Write-Host ''
Write-Host "清单已写入: $manifestPath" -ForegroundColor Green
