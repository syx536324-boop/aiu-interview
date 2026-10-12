# 原始村民取名

`name_profile.gd` 提供 `validation_error(male, female)`、`save_names(male, female)`、`load_names()`，校验去除首尾空白后的姓名为 1–12 个字符且不含换行或制表符。只在校验和文件保存均成功后，会话才更新游戏内姓名。

默认用 Godot ConfigFile 保存在 `user://founder_names.cfg`，下次启动由会话读取。UI 只发出姓名信号，不直接操作文件；角色稳定 ID 保留为 `ali` / `heya`，不随玩家取名变化。

自动验证可用 `AIU5_PROFILE_PATH` 环境变量指定隔离文件；`tests/interior_smoke.gd` 使用被 Git 忽略的 `.runtime` 文件，避免改动真实玩家姓名。本模块不保存地图、位置或互动状态。
