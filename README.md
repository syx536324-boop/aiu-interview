# aiu面试题

AIU 系列项目按并列目录整理。已有项目独立安装依赖、独立运行；AIU5 已建立项目骨架，等待后续功能开发。

| 目录 | 项目 | 主要内容 |
| --- | --- | --- |
| [aiu/](aiu/) | 本地智能体与知识工具 | Ollama、Dify 文件桥接、VALORANT 问答和资料网站 |
| [aiu2/](aiu2/) | YOLO 视觉应用 | 示例训练、摄像头实时推理、GPU/CPU 自动切换、C++ ONNX Runtime 实验 |
| [aiu3/](aiu3/) | STM32 硬件实践 | STM32F103C8T6、PC13 LED、CubeMX/CMake 固件、串口枚举 |
| [aiu4/](aiu4/) | 华小牛研究 Harness | 高质量 AI 论文检索、阅读、评阅卡和可选逐段中英翻译 |
| [aiu5/](aiu5/) | AIU5 新项目 | 项目说明、Git 忽略规则与版本管理；具体功能待开发 |

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

仓库提供手动 GitHub Pages 工作流。需要发布时，先在 Settings → Pages 选择 GitHub Actions，再手动运行 Publish AIU website previews。现有网站入口仍见原项目仓库。

## 提交范围

仓库包含源码、依赖声明、锁文件、公开论文目录、使用说明和必要第三方许可证。账号凭据、虚拟环境、依赖缓存、模型权重、训练数据、个人知识文档、论文全文与译文、会话和运行日志、编译产物均排除。原有 Git 历史与完整本机工程日志保留在原项目，不复制到新仓库。
