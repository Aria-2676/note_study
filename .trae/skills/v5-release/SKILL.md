---
name: v5-release
description: 任务管家 V5 项目的发版与代码推送流程。当用户要求发布新版本、运行 release.ps1 或 publish_release.ps1、推送代码到 GitHub、处理发版失败或上传超时时使用。涵盖企业网 REST API 推送通道、中文 PowerShell 脚本 BOM 校验、Release 资产与清单三方核对。
---

# V5 发版与推送

本项目在企业网（深信服）环境开发，网络存在硬性限制，所有发版与推送动作必须遵守本流程。

## 不可违背的环境事实

- `github.com` 的 git 智能 HTTP 通道被双向限速到 <1KB/s，`git push` 和 `git fetch` **必然挂死**（报 `Operation too slow. Less than 1000 bytes/sec`）。禁止用它们推送，也不要靠 `git fetch` 对齐远端。
- `api.github.com` 稳定快速（750ms 往返，137MB 资产约 1 分钟传完）。一切推送走 REST API。
- 唯一推送入口是 [tool/push_via_api.ps1](file:///d:/Dev/V5/tool/push_via_api.ps1)：blob → tree → commit → 移动 ref，推送后自动在本地重建同 sha 提交对齐分支，不需要 fetch。
- 认证读 `tool/github_token.txt`（已 gitignore，禁止提交、禁止在对话中回显 token 内容）。

## 日常推送

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool\push_via_api.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tool\push_via_api.ps1 -Tag v5.5.26
```

约束与排障：

- 该脚本只支持**单提交快进**（远端 sha 必须等于本地 HEAD 的父提交）。本地若积压多个未推送提交，先合并再推：
  `git reset --soft <远端main的sha>` 后重新 commit 成一个提交。不要用 `-Force`，除非确认远端提交是自己之前推的等价物。
- 推送成功后必须回读确认本地 `git rev-parse HEAD` 与远端 `git/ref/heads/main` 的 sha 完全相同。
- 分支已同步但需要补 tag 时，脚本会单独处理 `-Tag`；不要因为它输出"分支无需推送"就以为 tag 没推，看日志确认。

## 改任何含中文的 .ps1 之后（铁律）

Edit/Write 工具会剥掉文件的 UTF-8 BOM。PowerShell 5.1 对无 BOM 的中文脚本按 GBK 解析，直接语法崩溃（表现为乱码 `Unexpected token`）。每次改完 `tool/*.ps1` 必须：

1. 检查前 3 字节是否为 `EF BB BF`，不是则补回 BOM。
2. 用 `[System.Management.Automation.Language.Parser]::ParseFile($p,[ref]$null,[ref]$errs)` 验证 `parse_errors=0`。

参考命令：

```powershell
$p='d:\Dev\V5\tool\xxx.ps1'; $b=[IO.File]::ReadAllBytes($p)
if(-not($b[0]-eq239 -and $b[1]-eq187 -and $b[2]-eq191)){
  $bom=[byte[]](239,187,191); $out=New-Object byte[] ($b.Length+3)
  [Array]::Copy($bom,0,$out,0,3); [Array]::Copy($b,0,$out,3,$b.Length)
  [IO.File]::WriteAllBytes($p,$out)
}
```

## 发版流程

1. 发版前检查：`tool/github_token.txt` 非空、工作区干净、无同名残留本地 tag（`git tag -l vX.Y.Z`）。
2. 一条命令：`tool\release.ps1 -Version 5.5.26`。脚本顺序：改 pubspec 版本号 → 构建 split+fat 四个 APK → commit → 调 publish_release.ps1。
   - 构建参数已固化在脚本里，不要手敲替代：`--split-per-abi`（包体 62MB → 21~25MB）。图标树摇自 v5.5.26 起已恢复默认启用（Smart App Control 早前的 font-subset.exe 拦截已解除，省约 1.5MB）；若某台机构建报 font-subset 失败，再加回 `--no-tree-shake-icons`。
3. 耗时长（构建约 4 分钟 + 上传），**后台运行并轮询 output.log**，不要前台阻塞。
4. 构建已完成、仅发布步骤失败时，**不要重新构建**，直接续跑幂等的 `tool\publish_release.ps1 -Version 5.5.26`：已存在且校验通过的资产会跳过，失败资产会删后重传。
5. publish_release.ps1 内部的所有 git push 已改调 push_via_api.ps1，若发现又出现直接 `git push`，先修掉再发版。

## 发版后三方核对（缺一不可）

对 4 个 APK（app-release / arm64-v8a / armeabi-v7a / x86_64）逐个比对：

1. **本地包**：build 输出目录的 size + SHA256。
2. **远端 Release 资产**：GitHub API `releases/tags/vX.Y.Z` 的 assets `size` 与 `digest`（去掉 `sha256:` 前缀）。
3. **远端 update.json**：Contents API 取 `main` 分支文件，`latest.downloads.*` 的 sizeBytes + sha256（含泛化 `android` 键与三个 ABI 键）。

另外确认：

- aapt 核对 fat 包 versionName 等于发布版本（脚本步骤 0 自动做）。
- 远端 tag 指向预期 commit；本地 main sha 与远端 main sha 一致；工作区干净。
- purge jsDelivr 后受覆盖的节点（testingcf/cdn）约 3 分钟收敛；**gcore 不受 purge 覆盖、可能陈旧最长 12 小时**（见下节）。CDN 未立即收敛不算发布失败。

## 镜像与下载链路事实

- 企业网实测 18 个 GitHub 加速镜像，仅 `https://ghfast.top`、`https://gh-proxy.com` 可用。清单 mirrors 顺序固定为 ghfast → gh-proxy → GitHub 直连，不要擅自加入未探活的镜像。
- update.json 的 mirrors 热下发字段必须与 lib/core/config/download_mirrors.dart 内置顺序一致。
- **gcore 清单缓存无法 purge**：purge.jsdelivr.net 只覆盖 `CF`/`FY` 两个 provider（响应里可见）。而 `lib/core/config/cdn_bases.dart` 把 `gcore.jsdelivr.net` 设为清单**首要**源，testingcf/cdn/raw 只是回退。gcore 对 `@main` 的 `Cache-Control: s-maxage=43200`（12 小时）且不被 purge 清理，因此发布后 **gcore 可能陈旧最长 12 小时**。
- 配套隐患：`AppUpdateService.fetchManifest` 按候选顺序取**首个成功**响应就返回——gcore 返回「陈旧但 HTTP 200」时会短路后面的 testingcf/raw/Contents API 近实时源，导致客户端短时间内报「已是最新」。发布后若怀疑客户端没看到新版，先分别探各端点：`curl -s -I <端点>/gh/Aria-2676/note_study@main/update.json` 看 `Age` 与内容；`testingcf`/`raw`/`api.github.com` 通常是新的，`gcore` 可能仍旧。这不是发布失败，勿据此重新发版。
- 建议修法（待排期）：把 `CdnBases.manifest` 首要源从 gcore 换成 testingcf（受 purge 覆盖）；或在 `fetchManifest` 里当 CDN 结论「无更新」时再查一次 Contents API，取版本号更高者。

## 边界

- 发版提交只包含版本号、清单、发版脚本自身的修复；不要在发版 commit 里夹带功能改动。
- 失败时优先读日志定位再动手，不要重复跑同一条必挂命令（如 git push）。
- v5.5.23 及更早老客户端的下载器无断点续传且只拉 fat 包，无法远程修复，不为它投入开发。
