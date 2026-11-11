# 第三方组件

项目原创内容适用根目录的研究用途、禁止商用许可证。第三方组件各自许可证保留，不能以本项目声明取消第三方原许可证赋予的权利。

- `src/vendor/sony_dat_container.py`：复制自本地 `a7c2-dat-tools/a7c2dat/container.py`，原作者署名 `a7c2-dat-tools contributors`，MIT。完整许可证在 `src/vendor/LICENSE.a7c2-dat-tools`。只包含容器算法实现，没有固件文件。发布时的源码摘要见发布清单。
- NumPy、PyCryptodome：由用户在外部虚拟环境安装，仓库不打包其二进制。保留安装包自带许可证。
- Zig 0.14.1：从 [Zig 官方下载索引](https://ziglang.org/download/index.json)获取；安装器固定 Windows x64 压缩包 SHA256，保留解压目录内原许可证。仓库不包含 Zig 可执行文件。

没有打包 Sony 固件、相机备份、设备序列号、服务会话日志、认证信息或工作区历史。Sony 等名称仅用于标明研究对象，不表示官方授权或支持。
