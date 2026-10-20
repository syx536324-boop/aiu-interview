# aiu面试题

AIU 系列项目按并列目录整理。已有项目独立安装依赖、独立运行；AIU5 已发布“沙盘上的生活”村落生存游戏。

项目搭建、开发、验证、同步与发布的时间线见[工程日志](工程日志.md)；日志覆盖全部五个项目，并区分本地完成与GitHub已发布状态。

| 目录 | 项目 | 主要内容 |
| --- | --- | --- |
| [aiu/](aiu/) | 本地智能体与知识工具 | Ollama、Dify 文件桥接、VALORANT 问答和资料网站 |
| [aiu2/](aiu2/) | YOLO 视觉应用 | 示例训练、摄像头实时推理、GPU/CPU 自动切换、C++ ONNX Runtime 实验 |
| [aiu3/](aiu3/) | STM32 硬件实践 | STM32F103C8T6、PC13 LED、CubeMX/CMake 固件、串口枚举 |
| [aiu4/](aiu4/) | 华小牛研究 Harness | 高质量 AI 论文检索、阅读、评阅卡和可选逐段中英翻译 |
| [aiu5/](aiu5/) | 沙盘上的生活 | Godot 村落生存游戏：制作、种植、养殖、成就栏与摄像头赐予；Windows 安装包见 aiu5 发布页 |

## 沙盘上的生活：开源代码

游戏源码位于[aiu5/](aiu5/)，原创代码采用[AGPL-3.0-only](aiu5/LICENSE)。运行、依赖与授权范围见[开源说明](aiu5/OPEN_SOURCE.md)，安装包与源码包见[0.10.3 Release](https://github.com/syx536324-boop/aiu-interview/releases/tag/v0.10.3)。许可证范围为aiu5游戏原创代码，第三方内容和其他项目按各自许可处理。

## 从哪里开始

克隆仓库后，在需要的项目目录中打开终端，按对应 README 安装环境并启动。

```text
aiu面试题/
├── aiu/
├── aiu2/
├── aiu3/
├── aiu4/
└── aiu5/
```

AIU 与 AIU4 依赖本机 Ollama；AIU 的完整问答还需要本机 Dify。AIU2 的模型权重、AIU3 的硬件连接和 ARM 工具链需要分别准备。各项目中的原有 D:/E: 盘示例对应原独立安装，克隆后应在当前项目目录运行。

AIU3 已实现 LED 常亮/闪烁模块；AI 控灯、PID 调参与板端模型仍待后续实施。黑梦点位目前只有来源和部分章节文字，尚未取得真实演示 GIF。

## 网页预览

VALORANT 静态页面在 aiu/valorant_platform/web/；华小牛原界面预览在 aiu4/preview/。完整后端功能需要本机服务。

华小牛网页已发布：[打开华小牛](https://syx536324-boop.github.io/aiu-interview/aiu4/)。可浏览原界面、五个导航页和8篇基础论文目录；模型检索、全文翻译和研究对话仍需本机版。

本仓库已启用 GitHub Pages，使用 GitHub Actions 发布。更新公开界面后，可手动运行 `Publish AIU website previews`；网页发布内容来自 `aiu4/preview/`，不包含个人论文、译文、笔记或会话。

## 提交范围

仓库包含源码、依赖声明、锁文件、公开论文目录、使用说明和必要第三方许可证。账号凭据、虚拟环境、依赖缓存、模型权重、训练数据、个人知识文档、论文全文与译文、会话和运行日志、编译产物均排除。原有独立 Git 历史与完整本机记录保留在原项目；本仓库根目录的[工程日志](工程日志.md)提供经过核对的公开工程时间线。

安卓横屏版已提供[0.10.8-android.3 APK下载](https://github.com/syx536324-boop/aiu-interview/releases/tag/v0.10.8-android.3)，Android 8.0及以上；支持触屏操作、手机相机赐予、苹果树、新手教程与工作台升级并行制作。Windows安装包仍见上述0.10.3 Release。
