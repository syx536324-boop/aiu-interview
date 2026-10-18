# 华小牛 UI 静态发布

此目录直接沿用华小牛应用的 HTML、浅色绿色 CSS、五页导航、文献卡片、阅读弹窗和翻译控件，不另行设计主题。

`app.js` 与 `translation.js` 通过 `preview-api.js` 读取静态公开目录；个人文献、下载、全文译文、笔记、会话、任务、账号和模型配置均不包含在发布包中。

GitHub Pages 只展示界面。检索、收集、全文翻译与对话按钮提示使用本机版。`catalog.json` 仅包含基础论文的公开出处元数据，不能代表当前用户文献库。

发布入口为 GitHub Pages 工作流生成的 `aiu4/` 子路径，所有界面资源使用相对路径。

## 已发布地址

[华小牛网页版](https://syx536324-boop.github.io/aiu-interview/aiu4/)

2026-10-18：已启用本仓库GitHub Pages，发布工作流成功。实际浏览器验证五个导航页、8篇基础论文目录与YOLO筛选，控制台无报错；7个前端运行资源HTTP 200且与发布源码逐字节一致。

发布记录：[GitHub Actions #39138977797](https://github.com/syx536324-boop/aiu-interview/actions/runs/39138977797)。完整本机研究功能仍由本机服务提供。
