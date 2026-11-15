# 离线固件补丁说明

> **高风险，仅供研究学习。项目可能存在问题；修改或更新固件可能造成变砖、功能异常、卡死及数据损失。操作由使用者自行承担风险，在适用法律允许范围内，作者及贡献者不承担因使用本项目生成或更新固件而产生的任何责任。**

## 1. 先确认工具能做什么

本版为 `v0.3.0-research`，仅离线生成并验证研究包。命令只有 `profiles`、`check`、`build`、`verify`，**没有连接相机、自动备份机身、安装门控、切驱动或执行更新的命令**。整个构建过程不需要USB连接相机。

必须先阅读[已知问题](KNOWN_ISSUES.md)。本版研究组合的指定实测通过，官方输入组合未在机身测试。若没有针对自己机身验证过的安装和恢复方案，可完成第2—6节，但应停在这里，不要直接尝试机身更新。

## 2. 准备独立目录和输入

使用Windows x64、Python3.15 x64和Zig0.14.1。依赖版本固定在 `requirements.txt`。Linux／macOS未完成端到端验证，依赖脚本在这些系统上要求自行准备Zig。

从项目取得源码并解压为下面的仓库目录；自行合法取得所支持的精确固件输入。本项目不提供固件下载。

```text
C:\CameraResearch\
  a7c2-precapture\       只放公开源码和文档
  input\BODYDATA.DAT     用户自备的受支持输入
  backup\               本地备份；禁止发布
  tools\                依赖脚本创建的虚拟环境和编译器
  build-v030\           构建创建，含完整固件及工作文件；禁止发布
  verify-v030\          校验创建
```

在PowerShell中准备输入和备份目录：

```powershell
New-Item -ItemType Directory -Path C:\CameraResearch\input -Force | Out-Null
New-Item -ItemType Directory -Path C:\CameraResearch\backup -Force | Out-Null
Set-Location C:\CameraResearch\a7c2-precapture
py -3.15 --version
if ($LASTEXITCODE -ne 0) { throw '请先安装Python3.15 x64。' }
```

将自备固件复制到外部 `input\BODYDATA.DAT`。不要复制进仓库。输入身份与机身屏幕显示的版本不是一回事，机身显示2.00／2.01不构成输入匹配证明。

所有输入、依赖、输出及工作目录都必须在仓库之外。每次构建至少预留6GiB，多个构建及备份还会继续占用空间。`tools`、`build-v030`、`verify-v030`首次使用时必须不存在；失败重试应使用新的目录名，保留原失败记录。

## 3. 安装依赖

```powershell
py -3.15 -B tools/setup_tools.py --directory C:\CameraResearch\tools
if ($LASTEXITCODE -ne 0) { throw '安装失败；保留错误信息，不继续构建。' }
$Python = 'C:\CameraResearch\tools\venv\Scripts\python.exe'
$Zig = 'C:\CameraResearch\tools\zig-x86_64-windows-0.14.1\zig.exe'
& $Python --version
& $Zig version
```

脚本通过pip安装固定依赖，从Zig官方来源下载0.14.1 Windows x64压缩包并核对摘要后解压；不下载固件。若已有Zig0.14.1，首次安装可改用：

```powershell
py -3.15 -B tools/setup_tools.py --directory C:\CameraResearch\tools --zig C:\Tools\zig-0.14.1\zig.exe
if ($LASTEXITCODE -ne 0) { throw '依赖安装失败。' }
$Python = 'C:\CameraResearch\tools\venv\Scripts\python.exe'
$Zig = 'C:\Tools\zig-0.14.1\zig.exe'
```

以上两种方式选一种执行。网络或环境失败不需要对相机做任何操作。

## 4. 识别输入并保留本地备份

```powershell
& $Python -B patch_firmware.py profiles
if ($LASTEXITCODE -ne 0) { throw '读取配置失败。' }
& $Python -B patch_firmware.py check --input C:\CameraResearch\input\BODYDATA.DAT
if ($LASTEXITCODE -ne 0) { throw '输入身份不受支持，请停止。' }
Get-FileHash -LiteralPath C:\CameraResearch\input\BODYDATA.DAT -Algorithm SHA256
```

`check`只读取大小和完整SHA256。成功输出明确的配置ID：`official-2.01`或`research-fl23-2.00`。未知输入、其他机型、其他版本、已修改但摘要不匹配的包均应停止。不要改recipe或关闭保护。

将原始输入另存为不覆盖的备份，并比较摘要：

```powershell
$InputFile = 'C:\CameraResearch\input\BODYDATA.DAT'
$BackupFile = 'C:\CameraResearch\backup\BODYDATA-input-original.DAT'
if (Test-Path -LiteralPath $BackupFile) { throw '备份已存在，请核对原备份或换新文件名。' }
Copy-Item -LiteralPath $InputFile -Destination $BackupFile
if ((Get-FileHash -LiteralPath $InputFile).Hash -ne (Get-FileHash -LiteralPath $BackupFile).Hash) {
    throw '输入备份校验不一致。'
}
```

这只是**输入包备份，不是机身启动分区备份或恢复方案**。重要照片、视频和可导出的设置应另行备份；私有机身备份不能与其他机身交换，也不能上传到仓库。

## 5. 构建

```powershell
& $Python -B patch_firmware.py build --input C:\CameraResearch\input\BODYDATA.DAT --out C:\CameraResearch\build-v030 --zig $Zig --acknowledge-risk
if ($LASTEXITCODE -ne 0) { throw '构建失败，停止，不使用临时文件。' }
```

构建会依次核对源码和编译器输出、解密输入身份、各处原始数据、允许修改范围、分区校验、完整目标明文摘要及最终加密包摘要，并做完整解密回读。研究输入中的旧Movie跳转按配置定向修正；官方输入保留该处原生代码。

只有全部成功、退出码为0才有可供后续评估的结果：

```text
build-v030\BODYDATA_PRECAPTURE_800MS_EXPERIMENTAL.DAT
build-v030\build-report.json
```

`NOT_VERIFIED.partial`、其他临时文件或仅完成部分步骤的输出均不能安装。`work`含固件明文、编译产物和缓存；不得上传。不要将编译成功、单项测试通过或文件名存在当作完整构建成功。

## 6. 独立验证生成包

```powershell
& $Python -B patch_firmware.py verify --input C:\CameraResearch\build-v030\BODYDATA_PRECAPTURE_800MS_EXPERIMENTAL.DAT --work C:\CameraResearch\verify-v030
if ($LASTEXITCODE -ne 0) { throw '输出验证失败，请停止。' }

$Package = 'C:\CameraResearch\build-v030\BODYDATA_PRECAPTURE_800MS_EXPERIMENTAL.DAT'
$Report = Get-Content -LiteralPath C:\CameraResearch\build-v030\build-report.json -Raw | ConvertFrom-Json
$PackageHash = (Get-FileHash -LiteralPath $Package -Algorithm SHA256).Hash.ToLowerInvariant()
if ($PackageHash -ne $Report.output_sha256) { throw '输出包与构建报告不符。' }
$Report | Format-List
```

`verify`只验证已固定的输出身份及完整明文；成功后删除此次校验创建的明文。仍不证明机身兼容、更新安全或硬件稳定性。保存版本、输入／输出摘要及报告用于后续核对。

## 7. 机身安装前的停止点

输出研究更新标签为2.00。版本标签不会解除机身升级／降级门控。**机身是否接受更新必须由独立、针对本机的方案确认；本仓库没有这个安装器。**

在准备卡之前，确认以下事项：

1. 已备份重要拍摄资料与原始输入，能辨认本机所用实验包，了解恢复条件。
2. 有针对本机验证过的安装和恢复方案；若依赖临时门控，该方案必须包含机身专属备份、校验与门控恢复。没有则停止，不复制他人的地址、脚本参数或启动分区。
3. 相机工作正常、电量充足，存储卡和供电满足机身更新要求。不要在机身异常、正在写卡、供电不稳定或卡内容未备份时尝试。
4. 离线 `check`、`build`、`verify`全部成功，输出包与报告摘要一致。

本项目不提供通用降级／恢复包。不能保证重新安装官方固件就能恢复任何故障，也不能保证机身在所有状态下都接受官方包。

## 8. 仅在安装方案已确认后准备存储卡

推荐用读卡器复制。相机USB若不暴露存储卡，本工具不会替你切换驱动或修复连接；不要为复制包随意安装驱动。

先在文件管理器确认卡盘符、容量和内容。以下 `E:\` **只是示例，必须替换为自己确认的存储卡根目录**；不要直接照抄盘符。脚本不格式化卡、不删除照片。

```powershell
# 人工核对列表后，再设置正确卡根目录。
Get-Volume | Format-Table DriveLetter, FileSystemLabel, FileSystem, Size, SizeRemaining
$CardRoot = 'E:\'  # 必须改为已确认的存储卡。
if (-not (Test-Path -LiteralPath $CardRoot -PathType Container)) { throw '卡根目录不存在。' }
$CardPackage = Join-Path $CardRoot 'BODYDATA.DAT'

# 已有同名包先备份，禁止覆盖现有备份。
if (Test-Path -LiteralPath $CardPackage) {
    $CardBackup = 'C:\CameraResearch\backup\BODYDATA-card-before-v030.DAT'
    if (Test-Path -LiteralPath $CardBackup) { throw '旧卡包备份已存在，请先核对或换新文件名。' }
    Copy-Item -LiteralPath $CardPackage -Destination $CardBackup
    if ((Get-FileHash -LiteralPath $CardPackage).Hash -ne (Get-FileHash -LiteralPath $CardBackup).Hash) {
        throw '旧卡包备份校验失败。'
    }
}
Copy-Item -LiteralPath $Package -Destination $CardPackage -Force
if ((Get-FileHash -LiteralPath $CardPackage -Algorithm SHA256).Hash.ToLowerInvariant() -ne $PackageHash) {
    throw '卡上包摘要不同，请勿更新。'
}
```

确认卡根目录文件名恰为 `BODYDATA.DAT`，不是双扩展名。关闭占用卡的窗口，使用系统安全弹出，等读卡器写入结束再取卡。复制和校验成功只证明文件一致，不会授权或开启机身门控。

## 9. 菜单更新与首次检查

以下仅说明安装方案中应有的检查顺序，不提供绕过版本限制的操作。

1. 按已验证的本机方案完成必要准备，将卡插回机身。进入机身版本／软件更新页面，逐项核对识别结果、当前版本、更新版本及提示。
2. 任何不识别、版本拒绝、提示不符、错误码或画面异常都应停止，不强行继续，不修改包头或校验值。
3. 只有显示与本机方案一致且本人决定承担风险时，才在机身确认更新。开始后按机身说明保持电源，不拔电池、卡或断电。
4. 等待机身明确完成更新并正常启动。若使用临时门控，必须按原方案验证并恢复；本工具不会自动完成这些工作。
5. 先关闭预拍，检查普通照片、菜单、回放和模式切换。不要只看屏幕版本号判断内容身份；版本标签2.00也不能证明补丁已正确安装。
6. 能正常工作后再做下节短流程，任何异常立即停止扩大测试。

安装完成后的设备完整性核对需要专门方案；本仓库的 `verify`仅检查电脑上的DAT，不读取机内文件或运行内存。

## 10. 当前功能与有界检查

本版只在照片模式启用预拍，建议首先按已测条件：**电子快门、连拍Hi+、仅JPEG**。

1. 预拍关闭时检查普通拍摄。开启独立“预拍摄”菜单后，AF-ON不应启动缓存；AF-ON要实际对焦，应保持对应按键分配及AF设置。
2. 半按约1秒后完全松开，等待写入／活动指示结束。这轮应取消，不应产生可回放照片。
3. 半按约1秒后全按短拍，再完全松开；等待完成后应能回放保存的照片。
4. 对准不同景物，再仅半按后松开取消。关闭预拍菜单后回放，确认没有把取消轮景物误存。
5. JPEG正常后，才考虑切换**仅未压缩RAW**重复取消／保存／再次取消。RAW保留时间可能因容量限制短于800ms；不以照片数推定精确时间。
6. 本轮已测预拍OFF／ON的照片→视频→S&Q→照片切换，以及偏好ON的视频／S&Q冷启动、短录制和回放；这些模式不提供视频预拍功能。自行验证时从短流程开始，不直接扩大到长录制或未测格式。

注意红灯是否在完成后熄灭、取消是否误存、全按是否正常保存，以及花屏、黑屏、卡死等现象。自定义电子快门声不等于已保存文件，应以回放实际照片判断。尚无自定义秒数、精确800ms测量或功耗改善结论。

## 11. 失败、恢复与反馈

- **电脑构建／校验失败：** 停止，不复制临时输出到卡。保留精简错误，检查输入身份、依赖和磁盘空间；不需操作相机。
- **更新尚未开始而机身拒绝：** 停止，保存提示文字，不反复重试，不改摘要、不套用他人门控。
- **更新正在进行：** 不使用普通拍摄卡死的处置方法，不随意断电。遵循机身提示和适用于本机的恢复方案；没有明确方案时联系官方支持或具备该机型经验的维修人员。
- **已正常开机后的拍摄异常：** 停止继续触发，若菜单可用则关闭预拍；等待写入结束，按正常流程关机。不要为了反馈重复触发卡死。若无法正常关机，不能保证强制断电不损坏资料；先判断是否仍在更新或写卡，再寻求针对当前状态的处理。
- **恢复旧版本：** 本仓库没有“一键回退”。恢复包、允许的版本、启动分区状态和门控均须由本机方案核对；不要写入其他机身备份。

反馈可提供工具版本、配置ID、输入／输出SHA256、失败阶段、相机显示提示、照片格式、快门／连拍设置、菜单状态及按键顺序。删除个人路径和设备标识；不要上传固件、备份、序列号、凭据或原始服务日志。

## 12. 维护者发布源码包

```powershell
& $Python -B -m unittest discover -s tests -v
if ($LASTEXITCODE -ne 0) { throw '测试失败，停止发布。' }
py -3.15 -B tools/audit_release.py
if ($LASTEXITCODE -ne 0) { throw '审计失败，停止发布。' }
py -3.15 -B tools/package_source.py --output C:\CameraResearch\a7c2-precapture-v0.3.0-research-source.zip
if ($LASTEXITCODE -ne 0) { throw '打包失败。' }
```

打包器只接收审计通过的文本源码，排除 `.git`，把ZIP和清单写到仓库之外并重新读取核验。上传前仍须人工确认不含固件、编译产物、设备数据或秘密；不要从完整研究工作区直接打包。

**再次提醒：该流程仅供非商业研究学习，可能存在未知问题。任何形式转载或搬运须注明作者cjryrx及原始仓库链接。固件修改与更新可能导致变砖、功能不正常、卡死、数据损失等；在适用法律允许的最大范围内，作者及贡献者不对这些后果承担责任。**
