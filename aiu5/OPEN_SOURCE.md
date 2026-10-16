# 开源说明

源码：[syx536324-boop/aiu-interview 的 aiu5 目录](https://github.com/syx536324-boop/aiu-interview/tree/main/aiu5)。

## 许可证与范围

Copyright (C) 2026 syx536324-boop and contributors.

除文件中另有说明的第三方内容外，`aiu5/`目录内本项目原创代码采用 **GNU Affero General Public License version 3 only**，SPDX：`AGPL-3.0-only`。完整条款见[LICENSE](LICENSE)。这是本游戏的代码授权，不改变同仓库其他项目或第三方内容的许可证。

该许可证允许使用、研究、修改、再分发和商用。分发程序或衍生版本时，需要遵守保留版权及许可声明、按许可证提供对应源码、以相同许可证授权衍生作品等要求。如果用户通过计算机网络与修改后的程序交互，也需按许可证向这些用户提供对应源码。以上是便于阅读的摘要，完整法律条款以LICENSE为准。

本项目使用的Ninja Adventure素材为CC0；Godot、Python、Ultralytics、Torch及其他依赖继续采用各自许可证。详见[第三方声明](THIRD_PARTY_NOTICES.md)。此声明不重新授权第三方组件，也不改变模型及训练数据各自的来源许可。

## 从源码启动

准备Git及Godot 4.7.2标准版。进入准备存放源码的位置：

```powershell
git clone https://github.com/syx536324-boop/aiu-interview.git
cd aiu-interview\aiu5
& 'C:\tools\Godot_v4.7.2-stable_win64_console.exe' --editor --path .
```

把Godot程序路径换成自己的安装位置。也可直接在Godot项目管理器中导入本目录的`project.godot`，等待资源导入后按F5运行项目。

只运行基础游戏不需要Python摄像头环境。首次打开摄像头赐予时才加载对应服务、模型和依赖；缺少这些文件会在赐予界面显示错误提示。

## 完整摄像头赐予与Windows打包

源码包含摄像头服务、训练流程说明和固定依赖版本；Git不提交模型权重、嵌入式Python运行环境、原始训练图片及Godot导出模板。已发布[0.10.3安装包](https://github.com/syx536324-boop/aiu-interview/releases/tag/v0.10.3)包含运行所需的模型与CPU环境。

如已安装该游戏，可从安装目录复制`models/`和`runtime/`到本源码根目录。默认安装目录为`%LOCALAPPDATA%\Programs\AIU5`。完整源码与运行环境可以分开准备；也可按[Windows构建说明](packaging/windows/README.md)及[依赖版本表](packaging/windows/runtime-requirements.txt)自行配置。模型哈希见[models/README.md](models/README.md)，训练来源和限制见[training/gifts/README.md](training/gifts/README.md)。

打包还需要Inno Setup 7和与Godot 4.7.2相匹配的Windows x64导出模板。按构建说明放置模板后，在本目录执行：

```powershell
pwsh -File packaging/windows/build.ps1 -Godot 'C:\tools\Godot.exe' -ISCC 'C:\tools\Inno Setup\ISCC.exe'
```

输出到`exports/`。依赖或模型另行分发时，仍需保留并遵守对应许可证。

## 开发与反馈

功能模块位于`features/`，入口`scenes/main.gd`只负责装配，`tests/`包含现有验证场景。逐模块接口见各目录README。提交问题或改动前请阅读[贡献说明](CONTRIBUTING.md)。
