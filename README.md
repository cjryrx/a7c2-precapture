# a7c2-precapture

> **高风险警告：仅供研究学习。本项目处于实验阶段，可能存在已知或未知问题。使用本仓库工具生成并更新固件，可能导致相机变砖、功能不正常、黑屏／花屏、卡死、数据丢失或其他损失。所有操作风险由使用者自行承担；在适用法律允许的最大范围内，作者及贡献者不对因使用、修改、安装或更新本项目生成的固件而导致的上述情况及任何其他损失负责。**

Sony A7C II（ILCE-7CM2）上限 **800ms** 的预拍摄研究补丁工具。作者：**[cjryrx](https://github.com/cjryrx)**；原始仓库：**https://github.com/cjryrx/a7c2-precapture**。

**任何形式的转载、搬运、镜像、重新打包或二次分发，均须注明作者 cjryrx，并附原始仓库链接，保留许可证、风险提示和免责声明。禁止商用，仅作非商业研究与学习。** 修改版须说明修改内容，不得暗示原作者认可。原创内容适用 [LICENSE](LICENSE)；第三方组件保留各自许可，见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。本项目采用附带非商业限制的源码可用许可，不是 OSI 开源许可证。

## 发布内容与当前状态

仓库、源码压缩包和 Release **均不包含任何形式的固件**：没有官方／修改固件、机身备份、固件解包文件、编译后的补丁、二进制差分或编码固件。只提供补丁源码、必要参数、校验摘要、离线工具及说明。固件须由用户自行合法取得；输入、输出、编译产物和工具依赖必须放在仓库之外。

当前源码版本：**v0.2.0-research（2026-11-12）**。

- 独立“预拍摄”菜单；开启后按住 **AF-ON** 缓存、全按快门保存。AF-ON须保持分配为对焦功能；半按快门不再启动缓存，对焦行为仍由机身的半按AF设置决定。
- 新增未压缩RAW容量压力回收、纯缓存阶段的指示灯通知过滤，以及AF-ON／快门松开顺序的提交状态清理。
- 2026-11-12，研究组合完成电子快门、Hi+、仅JPEG及仅未压缩RAW测试。覆盖保存后的下一轮取消、两种松键顺序、红灯、短黑屏及回放，使用者反馈“全部正常”。**这是这轮指定流程通过，不是长期稳定性认证。**
- 窗口配置上限固定800ms，**尚不支持自定义秒数**。未压缩RAW受可用缓冲容量限制，实际保留时间可能更短；没有完成精确时间覆盖或功耗测量。
- 官方2.01输入生成的“仅预拍摄”组合完成离线构建校验，**未在相机上安装测试**。不应将研究组合的实测结论扩展到该组合或全部机身／镜头／卡。
- 没有加入禁用眼部感应自动切换的限制。保留历史异常记录及未测试范围，见下方文档。

版本变化见 [更新记录](CHANGELOG.md)；完整边界见 [已知问题](docs/KNOWN_ISSUES.md) 和 [发布验证](docs/VALIDATION.md)。

## 支持的输入

工具依据完整SHA256识别，不能仅凭文件名、机身显示版本或“同为2.01”判断。

| 配置 | 所需输入 | 结果 |
| --- | --- | --- |
| `official-2.01` | 未修改的 ILCE-7CM2 官方2.01包，摘要见下方 | 添加本项目预拍摄补丁；不额外添加FL23、连拍或自定义声音改动 |
| `research-fl23-2.00` | 用户已持有且摘要完全匹配的历史研究基线 | 保留其已有改动，并精确复现本轮实测的研究实验包；基线不提供下载 |

官方2.01输入大小：`1139929560` 字节；SHA256：

```text
eb4943e6099754d64deaef5047942e9bfe258f232d0b7bc39fa23b3cd10e1e31
```

另一个配置及全部目标摘要可运行 `profiles` 查看，权威定义在 [recipe.json](patches/recipe.json)。未知输入会被拒绝；不要修改摘要或跳过检查强行使用。

## 快速开始：Windows x64

已验证环境：Python 3.15 x64、Zig 0.14.1。先从 [Python官网](https://www.python.org/downloads/) 安装Python。下面是PowerShell示例，假定仓库放在 `C:\CameraResearch\a7c2-precapture`，固件放在旁边的 `input` 目录，**不要把固件复制进仓库**。

```powershell
Set-Location C:\CameraResearch\a7c2-precapture

# 首次安装：目录必须不存在，且位于仓库之外。
# 下载Python依赖和固定版本Zig，不下载固件、不访问相机。
py -3.15 -B tools/setup_tools.py --directory C:\CameraResearch\tools

# 确认自备输入的身份。
& C:\CameraResearch\tools\venv\Scripts\python.exe -B patch_firmware.py check --input C:\CameraResearch\input\BODYDATA.DAT

# 阅读风险说明后生成。输出目录必须尚不存在，所在盘至少空闲6GiB。
& C:\CameraResearch\tools\venv\Scripts\python.exe -B patch_firmware.py build --input C:\CameraResearch\input\BODYDATA.DAT --out C:\CameraResearch\build-800ms --zig C:\CameraResearch\tools\zig-x86_64-windows-0.14.1\zig.exe --acknowledge-risk

# 独立检查生成包；校验工作目录同样必须尚不存在。
& C:\CameraResearch\tools\venv\Scripts\python.exe -B patch_firmware.py verify --input C:\CameraResearch\build-800ms\BODYDATA_PRECAPTURE_800MS_EXPERIMENTAL.DAT --work C:\CameraResearch\verify-800ms
```

构建会编译七段源码、核对每处原始数据摘要、更新分区校验、逐字节核查修改范围，并完整加密／解密回读。成功后输出包和 `build-report.json` 位于外部输出目录；中间文件也包含固件，**不得上传或混入发布目录**。这些校验不证明相机安装或运行安全。

详细步骤、已有Zig的用法、故障处理与目录说明见 [补丁说明](docs/PATCHING.zh-CN.md)。

## 关于安装与门控

本次公开工具包完成的是**离线打补丁与校验**，不连接相机、不切换驱动、不启动更新。输出更新标签为 **2.00**；这既不是功能版本声明，也不自动解除机身的更新／降级门控。

既有研究用门控脚本依赖具体机身、启动分区备份和单次会话记录，不能当作通用安装器分发，因此未纳入本次公开包。**如果机身拒绝版本，不代表生成失败；请停止安装，不要照搬其他机身的门控参数、备份或修改校验值。** 本仓库不承诺任意版本机身可直接安装，也不提供通用刷机步骤。

## 复核源码包

```powershell
& C:\CameraResearch\tools\venv\Scripts\python.exe -B -m unittest discover -s tests -v
py -3.15 -B tools/audit_release.py
```

测试使用安装依赖后的外部虚拟环境Python。审计器检查包括未跟踪文件在内的源码目录；发布压缩包由白名单生成并重新读取核验。不要提交固件、生成目录、设备标识、服务日志或个人凭据。

**最后再次强调：仅供非商业研究学习，转载／搬运必须注明作者及原始链接。项目可能仍有问题，离线校验通过不等于稳定或适合日常使用。任何固件修改与更新都可能造成变砖、功能异常、卡死、数据损失等后果；在适用法律允许的最大范围内，作者及贡献者不承担由此产生的任何责任。**
