# 开始与暂停界面

默认入口 `scenes/start.tscn` 组合 `controller.gd`。控制器调用save_slots服务，设定选中存档路径后实例化游戏；返回菜单前保存并卸载当前游戏，保证不同村落不共享运行状态。

`view.gd` 只负责开始、存档列表、创建和暂停界面的显示，通过continue/new/create/load/back/resume/return/quit信号表达操作；不读写存档或推进游戏规则。`backdrop.gd` 绘制轻量沙漠背景。菜单节点ALWAYS处理，游戏根节点明确PAUSABLE，Esc暂停与M全图停止全部在线时钟。保存失败留在原游戏重试。

测试入口为 `tests/start_menu_smoke.gd` 和双进程 `tests/slot_quit_save_smoke.gd`，运行命令见根README。
