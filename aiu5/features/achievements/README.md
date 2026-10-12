# 成就

`achievements.gd.start(session)` 接入角色进度与完整存档。`snapshot(actor_id)` 返回只读的成就栏数据；`complete(actor_id, achievement_id)` 对已定义成就每角色只奖励一次100魔法点，并与完成记录原子保存。失败回滚记录和点数，禁止重复领取。

具体成就名称和条件待用户确定，`catalog.gd.ENTRIES` 保持为空；界面不提供虚构成就或任意领取按钮。`export_state/restore` 接入自动存档和祭台存档；旧档默认空成就列表。

入口：C→角色属性→成就。UI只展示后端快照。验证：`tests/rules_update_smoke.gd`。
