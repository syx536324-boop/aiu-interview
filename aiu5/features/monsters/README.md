# 哥布林领域

`catalog.gd`集中维护等级生命、逐级继承的技能和刷新数值。`goblin.gd`逐物理帧执行移动、前摇、攻击、收招与绘制；`monsters.gd`管理刷新槽、存档、飞行命中、平民避险和矿洞护卫。`flight.gd`仅画飞行木刺。

main只实例化并调用`start(session)`。在线时钟调用`advance(delta)`推进刷新，tribes在工作／战争决策前调用`respond(delta)`，物理帧处理活动个体及扫掠飞行物。`handles`／`blocks_work`／`is_protected`防止工作和旧守卫覆盖本轮安全决策；`order_guard`保存护矿与召回命令。

个体注册到combat.enemies，复用玩家武器、附魔、魔法与25点击杀奖励。它们的生命周期和持久化仅由monsters管理：streaming跳过带有streaming_exempt的节点，combat旧快照跳过goblin。室内创建时重新挂接，释放前安全停放；不能因矿洞空房卸载而遗留已释放引用。持久化通过export_state/restore保存等级、HP、位置、独立冷却、前摇、在线补刷钟及护卫命令，恢复时不升级已有个体。

活动及停用矿洞使用同一局部坐标；可见空间用真实碰撞射线，停用空间用导航遮挡和扫掠线段检测。伤害调用combat.apply_npc_damage或tribes.war.damage_target，木属性与现有减伤规则共用；不把怪物受伤计为对部落犯罪。局部寻路带重试间隔，避免不可达目标触发逐帧全图搜索。

规则见docs/GOBLINS_0.10.7.md。隔离回归tests/goblins_probe.tscn验证继承、攻击前摇／躲避／遮挡、箭支、护矿／逃跑、真实物理帧移动、唯一奖励、安全补刷、保存重载及房间释放。

刷新前同时检查身体半径覆盖的导航格与实际碰撞形状，避免树木或矿石边缘将新刷身体挤开。
