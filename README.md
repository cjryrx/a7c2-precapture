# a7c2-precapture

> **高风险警告：仅供研究学习。本项目处于实验阶段，可能存在已知或未知问题。使用本仓库工具生成并更新固件，可能导致相机变砖、功能不正常、黑屏／花屏、卡死、数据丢失或其他损失。所有操作风险由使用者自行承担；在适用法律允许的最大范围内，作者及贡献者不对因使用、修改、安装或更新本项目生成的固件而导致的上述情况及任何其他损失负责。**

Sony A7C II（ILCE-7CM2）上限 **800ms** 的预拍摄研究补丁工具。作者：**[cjryrx](https://github.com/cjryrx)**；原始仓库：**https://github.com/cjryrx/a7c2-precapture**。

**任何形式的转载、搬运、镜像、重新打包或二次分发，均须注明作者 cjryrx，并附原始仓库链接，保留许可证、风险提示和免责声明。禁止商用，仅作非商业研究与学习。** 修改版须说明修改内容，不得暗示原作者认可。原创内容适用 [LICENSE](LICENSE)；第三方组件保留各自许可，见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。本项目采用附带非商业限制的源码可用许可，不是 OSI 开源许可证。

## 发布内容与当前状态

当前版本：**v0.3.0-research（2026-11-15）**。这是研究版本，不是 Sony 官方固件。

仓库、源码压缩包和 Release **均不包含任何形式的固件**：不提供官方／修改固件、机身备份、解包文件、编译后的补丁、二进制差分或编码固件。只提供补丁源码、必要参数、校验摘要、离线工具及说明。固件须由用户自行合法取得；输入、输出、编译产物和依赖必须放在仓库之外。

- 独立“预拍摄”菜单用于**照片模式**。开启后半按快门缓存，全按保存；仅半按后松开应取消缓存，不保存照片。AF-ON不启动预拍缓存；分配为对焦功能时用于对焦。
- 缓存配置上限 **800ms**，尚不支持自定义秒数。未压缩RAW受可用缓冲限制，实际覆盖可能短于800ms。
- 照片模式的启用边界与关闭收尾进行了调整。视频／S&Q不是预拍摄功能支持范围；保留预拍偏好ON时切入这些模式，预期仍进行普通视频操作。
- 修复历史研究基线中一处 Movie 元数据跳转破坏返回地址的问题。官方输入没有这一处旧跳转，保持原生指令；工具按输入配置处理，不能混用。
- 本版研究组合已获使用者确认：预拍OFF和ON下的照片→视频→S&Q→照片切换，以及偏好ON下视频／S&Q冷启动、短录制和回放均正常。
- 本版照片回归也获“均正常”反馈：电子快门、Hi+，仅JPEG与仅未压缩RAW的半按取消／全按保存／再次取消，红灯及回放正常；JPEG测试另检查AF-ON仅对焦。**这些是指定流程反馈，不是长期稳定性认证。**
- 官方2.01输入生成的组合**未在机身安装测试**；研究组合的通过结论不扩展到官方输入路线或其他机身／镜头／卡。

详细边界见 [发布验证](docs/VALIDATION.md)、[已知问题](docs/KNOWN_ISSUES.md) 和 [更新记录](CHANGELOG.md)。没有新增禁用眼部感应自动切换的限制。

## 支持的输入

工具按完整SHA256识别。文件名、机身显示版本和“同为2.01”均不能代替身份检查。

| 配置 | 所需输入 | 处理范围 |
| --- | --- | --- |
| `official-2.01` | 未修改的 ILCE-7CM2 官方2.01包 | 添加本项目补丁；不额外添加FL23、历史连拍或自定义声音改动；机身未测 |
| `research-fl23-2.00` | 用户已持有且摘要完全匹配的历史研究基线 | 保留既有改动，加入本版修正，包括旧Movie跳转修复；基线不提供下载 |

官方2.01输入大小：`1139929560` 字节；SHA256：

```text
eb4943e6099754d64deaef5047942e9bfe258f232d0b7bc39fa23b3cd10e1e31
```

运行 `profiles` 查看完整输入及目标摘要；权威定义在 [recipe.json](patches/recipe.json)。已经打过本补丁的输出不应再次作为输入。未知输入会被拒绝，不要改摘要或跳过检查。

## 快速开始：Windows x64

研究使用Python3.15 x64、Zig0.14.1。安装Python后，在PowerShell中执行以下示例。仓库放在 `C:\CameraResearch\a7c2-precapture`；自备固件放在外部 `input` 目录。**此阶段不需要连接相机。**

```powershell
Set-Location C:\CameraResearch\a7c2-precapture

# 新建外部工具目录，安装固定依赖与Zig；不下载固件。
py -3.15 -B tools/setup_tools.py --directory C:\CameraResearch\tools
if ($LASTEXITCODE -ne 0) { throw '依赖安装失败，请停止。' }

$Python = 'C:\CameraResearch\tools\venv\Scripts\python.exe'
& $Python -B patch_firmware.py profiles
if ($LASTEXITCODE -ne 0) { throw '读取配置失败。' }
& $Python -B patch_firmware.py check --input C:\CameraResearch\input\BODYDATA.DAT
if ($LASTEXITCODE -ne 0) { throw '输入不受支持，请勿继续。' }

# build-v030必须不存在，所在盘至少空闲6GiB。
& $Python -B patch_firmware.py build --input C:\CameraResearch\input\BODYDATA.DAT --out C:\CameraResearch\build-v030 --zig C:\CameraResearch\tools\zig-x86_64-windows-0.14.1\zig.exe --acknowledge-risk
if ($LASTEXITCODE -ne 0) { throw '构建失败，任何临时包都不能安装。' }

# verify-v030也必须是新目录。
& $Python -B patch_firmware.py verify --input C:\CameraResearch\build-v030\BODYDATA_PRECAPTURE_800MS_EXPERIMENTAL.DAT --work C:\CameraResearch\verify-v030
if ($LASTEXITCODE -ne 0) { throw '输出校验失败，请勿安装。' }
```

工具核对源码与编译结果、每处原始数据、修改白名单、完整明文及最终包摘要，并进行加密／解密完整回读。输出包和 `build-report.json` 位于外部目录。工作文件包含完整固件，**不得上传或混入源码发布目录**。校验通过不证明安装或运行安全。

备份、卡复制校验、菜单更新停止点、恢复与问题反馈，详见 [完整操作说明](docs/PATCHING.zh-CN.md)。

## 安装与门控边界

公开工具只做**离线打补丁与校验**，不连接相机、不切换驱动、不刷写启动分区、不启动更新，也没有通用门控安装程序。输出的研究更新标签为 **2.00**；它不代表内部功能版本，也不会自动解除版本／降级限制。

**没有针对自己机身验证过的安装与恢复方案，就停在离线校验完成处。** 历史研究中的门控操作绑定具体机身备份与会话，不能复制其他机身地址、参数或备份使用。本项目不提供这些私有材料。机身不识别包、拒绝版本或提示不符时，应停止，不能靠修改校验值继续。

## 复核源码包

```powershell
& C:\CameraResearch\tools\venv\Scripts\python.exe -B -m unittest discover -s tests -v
if ($LASTEXITCODE -ne 0) { throw '测试失败。' }
py -3.15 -B tools/audit_release.py
if ($LASTEXITCODE -ne 0) { throw '源码审计失败。' }
```

审计包括未跟踪文件；发布ZIP按白名单生成并重新读取核验。不要提交固件、生成目录、设备标识、服务日志或凭据。

**最后再次强调：仅供非商业研究学习，转载／搬运必须注明作者及原始链接。项目可能仍有问题，离线校验通过不等于稳定或适合日常使用。任何固件修改与更新都可能造成变砖、功能异常、卡死、数据损失等后果；在适用法律允许的最大范围内，作者及贡献者不承担由此产生的任何责任。**
