# 枯木采集

`harvesting.tscn` / `harvesting.gd` 提供 `start(world, inventory)` 与 `chop(resource_id, actor)`。六棵枯木按稳定 ID 布置在户外，只有当前角色在 25 像素内、位于户外且装备石斧或铁斧时才能砍伐。每次有效砍伐间隔 0.35 秒，第 2/4 次各奖励 1 个木头，第 4 次删除互动点、关闭树干碰撞并刷新村民导航。

`dead_tree.gd` 原生绘制枯枝、树干、砍痕、木屑和挥斧动画，树干用矩形静态碰撞。第四斧反馈结束后隐藏整棵树。采集模块通过 `message(text)` 将结果交给会话显示，不直接控制 HUD。

次数与奖励通过物品模块的 `commit_resource_reward()` 同次保存，容量不足或保存失败不推进树木状态。启动读取 `resource_hits`，部分砍伐继续累计，砍完的树不再出现。当前没有自动再生或斧子耐久消耗。

根 README 提供 `tests/harvesting_smoke.gd` 的实际运行命令；测试与截图使用隔离存档，不消耗玩家的枯木。


按种子生成的枯木通过add_procedural(record)接入，存于procedural索引，trees保留旧六棵固定采集点。chop/restore同时支持两者；进度继续以稳定ID存库存resource_hits。world_resources拥有生成节点的卸载与释放，卸载不清除进度。


武器与工具更新：weapon_catalog定义镐子1、木剑1、石剑3、铁剑5、石斧2、铁斧4、弓10的基础攻击及分类。单格装备支持这些武器，equip_weapon仍原子交换并持久化。木斧从物品表移除，inventory._sanitize_slots和magic.restore_state将旧木斧转换为石斧。必须装备镐子采矿、装备斧砍树；桑树空手E采叶，持斧E砍树，其他武器不能采叶。森林树木沿用每2次1木头、4次砍完，resource_hits保持稳定ID，重载不复原。J近战29单位、0.6秒间隔、视线和朝向检查；弓每次成功发射扣背包1箭，失败不扣；X拆自建房按当前斧攻击和房屋防御计算。

## 耐久事务

成功砍枯木时消耗已装备斧的1次使用，奖励、resource_hits和耐久统一通过production.commit提交。损坏、距离/冷却不符、奖励放不进背包或保存失败不扣耐久；失败恢复快照，成功后再刷新木头节点。
