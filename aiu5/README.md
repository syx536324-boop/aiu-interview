# AIU5

AIU5 是 aiu-interview 仓库中的第五个项目。目前已建立项目目录、说明文档和 Git 忽略规则，具体功能将在后续需求明确后开发。

## 目录

```text
aiu5/
├── .gitignore
└── README.md
```

## 开发与版本管理

当前没有运行依赖或启动命令。后续添加代码时，请同步补充依赖安装、配置和启动说明。

AIU5 的独立开发目录已初始化 Git。在该目录保存本地改动：

```powershell
git add .
git commit -m "Update AIU5"
```

GitHub 发布使用统一仓库 `syx536324-boop/aiu-interview` 的 `main` 分支，源码放在 `aiu5/` 子目录，与 aiu、aiu2、aiu3、aiu4 并列。

发布更新时，将独立开发目录中的源码同步到统一仓库的 `aiu5/`，排除 `.git`、本地依赖及忽略的文件，再在统一仓库根目录提交和推送：

```powershell
git add aiu5/
git commit -m "Update AIU5"
git push origin main
```

环境文件、密钥、本地依赖、缓存、日志和构建产物由 `.gitignore` 排除。
