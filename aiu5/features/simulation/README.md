# 在线领域时钟

`clock.gd.start(session)` 设置homestead/livestock/vitals的clock_driven，统一每0.5秒推进在线时间，避免各模块双跑。`flush()` 在交互、保存和全图前结算不足一个tick的部分秒数；`reset()` 在恢复存档时清空待推进时间。遵守领域set_process(false)，方便确定性检查。

时钟使用SceneTree正常暂停模式，全图暂停时不累计墙上时间。普通B/C/F菜单与室内外切换不停止在线时间；远区作物/动物由领域自己的事件期限或访问结算，生存伤害规则仍由survival拥有。主入口只创建、注入并启动；UI不计算时间。

## 西岸森林接入

统一flush额外调用forest.elapse(delta)，只推进在线刷新时钟，森林资源访问时结算；全图与暂停菜单不积累时间。
