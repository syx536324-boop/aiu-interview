# VALORANT Platform

本机 VALORANT 问答和资料网站，位于 aiu/valorant_platform/。后端使用 Python 标准库，前端使用原生 HTML/CSS/JavaScript；默认只监听 127.0.0.1:8780。

## 运行

在 aiu/ 项目目录安装环境后，运行 start-valorant-platform.ps1，或执行：

```powershell
.\.venv\Scripts\python.exe -m valorant_platform
```

资料页可独立浏览；问答依赖使用者配置的本机 Dify 服务。Dify API 地址和服务端密钥文件可分别通过 DIFY_API_BASE、DIFY_API_KEY_FILE 配置。

## 功能与接口

- web/：29 位特工的资料、技能摘要、默认键位、立绘和 13 张地图导航。
- server.py：HTTP 路由与 Dify 流式聊天代理。
- lineups.py：黑梦目录和媒体访问边界。
- GET /api/health：本机服务状态。
- POST /api/chat：本机 Dify 问答。
- GET /api/fade-lineups：黑梦点位来源和章节目录。
- GET /api/fade-lineups/media/<文件名>：仅提供已登记章节对应的 GIF，限制路径范围。

黑梦地图名称按用户提交名称保留，两个亚海悬城条目独立展示。目前仅有来源和部分章节文字，没有已核对的演示 GIF。原视频和 GIF 使用本机专用目录，根目录可通过 AIU_FADE_LINEUP_ROOT 配置；GIF 文件名使用“条目ID-两位章节序号.gif”。

静态预览只包含资料和目录，不连接本机模型、Dify 或本机媒体目录。特工立绘需要联网加载，技能摘要应以游戏内和 Riot 官方资料为准。
