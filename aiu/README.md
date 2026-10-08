# AIU · 本地智能体与 VALORANT 资料站

本项目位于统一仓库的 aiu/ 目录，包含 Ollama CLI 智能体、Dify 文件工具桥接和 VALORANT 网页。AIU2、AIU3、AIU4 是仓库根目录下的独立并列项目。

## 环境和启动

在 aiu/ 目录打开 PowerShell，准备 Python 3.12、uv 和本机 Ollama：

```powershell
uv sync
.\.venv\Scripts\python.exe -m agent
```

默认模型为 qwen3.5:4b，Ollama 地址为 http://127.0.0.1:11434。完整 Dify 问答需要自行准备 Docker Desktop、Dify 及对应模型配置；本机部署数据与账号配置不包含在仓库中。

已配置本机环境后，可运行 start-aiu-chat.ps1 启动问答网页；仅启动资料网站运行 start-valorant-platform.ps1。网页地址为 http://127.0.0.1:8780/。

## 模块

- agent/：调用 Ollama 的 CLI 智能体、计算器和本机知识工具。
- file_bridge/：Dify 文件 API 与独立人工审批页面，限定可访问文件范围。
- valorant_platform/：本机聊天代理、特工资料、地图导航与黑梦点位来源。
- flows/ 和 run-langflow.ps1：前期 Langflow 流程备份。
- Dify使用说明.md：Dify 使用和本机配置说明。

知识文档与账号配置由使用者在本机准备。密钥只由后端读取；修改、覆盖或删除知识文件需要本机审批。

## 静态预览

valorant_platform/web/ 可作为静态页面发布。公开页面可浏览资料，完整问答需要本机 Dify/Ollama 后端。点位来源记录保留 13 张地图和两个亚海悬城条目；实际演示 GIF 尚未制作完成。
