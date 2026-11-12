# 离线固件补丁说明

> **高风险，仅供研究学习。项目可能存在问题；修改或更新固件可能造成变砖、功能异常、卡死及数据损失。操作由使用者自行承担风险，在适用法律允许范围内，作者及贡献者不承担因使用本项目生成或更新固件而产生的任何责任。**

## 1. 准备独立目录

使用Windows x64和Python 3.15 x64。已验证的依赖固定在 `requirements.txt`。Linux／macOS没有完成端到端验证；安装器在这些系统上要求自行准备Zig0.14.1。

推荐布局：

```text
C:\CameraResearch\
  a7c2-precapture\    仓库：只放源码和文档
  input\BODYDATA.DAT 用户合法取得的精确匹配输入，不随项目提供
  tools\              安装器新建的虚拟环境和编译器
  build-800ms\        构建时新建，含生成固件和工作文件，禁止发布
  verify-800ms\       校验时新建
```

固件文件不能在仓库内，包括未跟踪文件、子目录或符号链接指向的仓库内路径。脚本拒绝输入、输出或工作目录位于仓库内，并拒绝覆盖已有输出。至少留出6GiB空闲空间供每次构建；保留多次构建会继续占用空间。

## 2. 安装外部依赖

在仓库根目录运行：

```powershell
py -3.15 -B tools/setup_tools.py --directory C:\CameraResearch\tools
```

脚本通过pip安装NumPy和PyCryptodome；从Zig官网获取固定0.14.1 Windows x64压缩包，先核对SHA256再解压，保留上游许可。没有固件下载功能。

如果已经安装Zig0.14.1：

```powershell
py -3.15 -B tools/setup_tools.py --directory C:\CameraResearch\tools --zig C:\Tools\zig-0.14.1\zig.exe
```

安装失败时保留错误信息，修复网络或环境问题后选新的外部目录重试。无需连接相机。

## 3. 核对输入

```powershell
& C:\CameraResearch\tools\venv\Scripts\python.exe -B patch_firmware.py profiles
& C:\CameraResearch\tools\venv\Scripts\python.exe -B patch_firmware.py check --input C:\CameraResearch\input\BODYDATA.DAT
```

`check` 比较文件大小与完整SHA256，不修改文件。只接受两个固定配置，详见README。当前机身运行版本与作为补丁输入的文件身份是两回事；工具不探测机身兼容性。不要使用已打本补丁的包重复打补丁，不要将其他机型／版本的摘要填入recipe。

## 4. 构建与完整验证

```powershell
& C:\CameraResearch\tools\venv\Scripts\python.exe -B patch_firmware.py build --input C:\CameraResearch\input\BODYDATA.DAT --out C:\CameraResearch\build-800ms --zig C:\CameraResearch\tools\zig-x86_64-windows-0.14.1\zig.exe --acknowledge-risk
```

使用自备Zig时相应替换 `--zig`。构建流程：

1. 核对补丁源码摘要，使用固定Zig编译ARM／AArch64源码；核对代码地址、长度与摘要。
2. 解密自备输入，核对完整明文身份。
3. 核对每个修改位置的原始摘要，应用七段源码产物和50项小范围参数／指令修改。
4. 将研究更新标签设为2.00，更新头部和三个分区的校验；逐字节检查完整明文的差异白名单及最终摘要。
5. 重新封包，完整解密回读，核对已固定的输出摘要以及输入没有变化。
6. 全部成功后才将临时文件改为 `BODYDATA_PRECAPTURE_800MS_EXPERIMENTAL.DAT`，写出 `build-report.json`。

编译器可能提示找不到 `_start`；这里提取固定地址的补丁代码段，不运行独立程序。只有最终全部校验成功、退出码为0才算构建成功。

输出中的 `work` 含完整固件明文、编译产物与缓存，仅限本地研究。不要发布 `work`、DAT或临时文件。失败时的 `NOT_VERIFIED.partial` 不能用于安装。

## 5. 再次核验生成包

```powershell
& C:\CameraResearch\tools\venv\Scripts\python.exe -B patch_firmware.py verify --input C:\CameraResearch\build-800ms\BODYDATA_PRECAPTURE_800MS_EXPERIMENTAL.DAT --work C:\CameraResearch\verify-800ms
```

该命令核对固定输出摘要并解密核对完整明文，成功后删除本次校验创建的明文。只证明容器与内容身份一致；不证明硬件安全、稳定性、安装成功或800ms实际覆盖。

## 6. 安装边界与问题反馈

本公开版本不提供通用机身门控／刷机工具。生成包的2.00标签可能被机身版本门控拒绝，不应据此篡改工具的保护检查。具体机身的启动分区备份和门控参数不能互换。

本版菜单开启后由AF-ON的原生对焦功能触发缓存，半按不启动缓存；全按保存。保持AF-ON分配为对焦功能，按需开启机身的半按AF设置。窗口配置上限固定800ms；RAW受容量限制可能更短，自定义秒数尚未实现。已知或历史问题见 [KNOWN_ISSUES.md](KNOWN_ISSUES.md)。

反馈可提供工具版本、输入／输出SHA256、失败步骤和精简错误信息。不要上传固件、机身备份、序列号或服务原始日志。不要为了反馈反复触发卡死。

## 7. 维护者重新打包

安装依赖后运行：

```powershell
& C:\CameraResearch\tools\venv\Scripts\python.exe -B -m unittest discover -s tests -v
py -3.15 -B tools/audit_release.py
py -3.15 -B tools/package_source.py --output C:\CameraResearch\a7c2-precapture-source.zip
```

打包器只接收审计通过的文本源码，排除 `.git`，将ZIP和校验清单写到仓库之外，重新读取ZIP并比较每个文件。文件类型／编码扫描不能代替人工审查：必须确认没有固件碎片、设备数据或秘密。不要从研究工作区直接打包。

**再次提醒：该流程仅供非商业研究学习，可能存在未知问题。任何形式转载或搬运须注明作者cjryrx及原始仓库链接。固件修改与更新可能导致变砖、功能不正常、卡死、数据损失等；在适用法律允许的最大范围内，作者及贡献者不对这些后果承担责任。**
