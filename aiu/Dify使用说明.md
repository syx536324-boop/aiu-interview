# Dify 使用说明

## 准备环境

完整问答依赖本机 Docker Desktop、Dify 和 Ollama。请按各项目官方说明部署，创建自己的本机管理员和应用 API 密钥；仓库不提供账号、密码、API 密钥或既有部署数据。

在 Dify 安装官方 Ollama 插件，将容器中的模型地址配置为 host.docker.internal:11434，选择已安装的本机模型。模型名和端口可按实际环境调整。

## 打开与停止

在 aiu/ 项目目录打开 PowerShell。配置现有启动脚本需要的本机部署和账号文件后，可运行 start-dify.ps1；停止运行 stop-dify.ps1。启动脚本用于已有本机安装，不会自动重建完整 Dify 部署。

本机管理入口为 http://127.0.0.1/signin。智能体聊天地址由自己的 Dify 应用页面提供。

## 文件工具

file_bridge/ 提供限定 knowledge/ 目录的文件 API。支持列出、读取，以及提出新建、覆盖和删除请求。写操作需要用户在本机审批页面确认，模型不能自行批准。

独立启动命令：

```powershell
.\.venv\Scripts\python.exe -m file_bridge
```

桥接服务默认监听 127.0.0.1:8765；Dify 容器通过 host.docker.internal:8765 访问。运行 connect-dify-files.ps1 可向自己的 Dify 应用同步工具定义，需要先完成本机认证配置。

## Web 问答

运行 start-valorant-platform.ps1，打开 http://127.0.0.1:8780/。服务端通过 Dify 应用 API 转发请求；API 密钥由后端本机配置读取，不能写进网页或提交到 GitHub。

静态网页预览只提供资料浏览，不能执行本机模型对话。
