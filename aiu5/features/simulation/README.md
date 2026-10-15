# 在线领域时钟

`clock.gd.start(session)` 设置homestead/livestock/vitals的clock_driven，统一每0.5秒推进在线时间，避免各模块双跑。`flush()` 在交互、保存和全图前结算不足一个tick的部分秒数；`reset()` 在恢复存档时清空待推进时间。遵守领域set_process(false)，方便确定性检查。

时钟使用SceneTree正常暂停模式，全图暂停时不累计墙上时间。普通B/C/F菜单与室内外切换不停止在线时间；远区作物/动物由领域自己的事件期限或访问结算，生存伤害规则仍由survival拥有。主入口只创建、注入并启动；UI不计算时间。

## 西岸森林接入

统一flush额外调用forest.elapse(delta)，只推进在线刷新时钟，森林资源访问时结算；全图与暂停菜单不积累时间。

## 魔法分支接入（0.8.0）

统一tick依次推进生存、主干技能、分支技能、施工和火把。分支设施／草丛／状态／冷却与施工仅推进在线时间，恢复存档reset清除待结算时间。

## 0.9.1在线计时修复

Production及Foraging由统一Simulation时钟驱动；start显式启用领域的process标志。这两个节点无需自己的_process回调，避免重复计算时间。tests/crafting_clock_probe.tscn以真实帧检查菜单中的进度、冶炼、资源补充、暂停及读档，不直接调用elapse。


0.10.2：0.5秒在线领域计时不变。部落决策只发布移动意图，由actor物理帧执行连续碰撞位移与动画，不在物理循环重跑领域计时，避免重复扣血、恢复、生产或推进婚恋。
